# Support agent: a chat agent (Strands) hosted on Bedrock AgentCore
# Runtime using direct code deployment (zip in S3, no container). Terraform owns
# the infrastructure; the agent repo's CI uploads the real code zip and refreshes
# the runtime. Same placeholder pattern as the API/eval Lambdas.

# --- Code artifacts (versioned, so every deploy is tracked) ---
resource "aws_s3_bucket" "agent_artifacts" {
  bucket = "${var.project}-agent-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "agent_artifacts" {
  bucket = aws_s3_bucket.agent_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "agent_artifacts" {
  bucket                  = aws_s3_bucket.agent_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Placeholder package so the runtime can be created before the agent repo's CI
# has ever run. Invocations fail until the real zip lands on the same key.
data "archive_file" "agent_placeholder" {
  type        = "zip"
  output_path = "${path.module}/build/agent_placeholder.zip"
  source {
    content  = "raise RuntimeError('Support agent not deployed yet - run the agent repo CI')\n"
    filename = "agent.py"
  }
}

resource "aws_s3_object" "agent_code" {
  bucket = aws_s3_bucket.agent_artifacts.bucket
  key    = local.agent_code_key
  source = data.archive_file.agent_placeholder.output_path

  lifecycle {
    # Terraform owns the object's existence; CI owns its content. CI's
    # `aws s3 cp` replaces the object (and drops tags), so content-adjacent
    # attributes and tags are all CI's business, not drift.
    ignore_changes = [source, etag, source_hash, tags, tags_all]
  }
}

# --- Execution role: what the agent may do while it runs ---
data "aws_iam_policy_document" "agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }

    # Confused-deputy guard: only runtimes in this account/region may assume it.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_iam_role" "agent_exec" {
  name               = "${var.project}-agent-exec"
  assume_role_policy = data.aws_iam_policy_document.agent_assume.json
}

# Invoke the chat model (scoped to that one model). Strands streams responses,
# so the streaming action is needed alongside plain InvokeModel.
data "aws_iam_policy_document" "agent_bedrock" {
  statement {
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.agent_model_id}"]
  }
}

resource "aws_iam_role_policy" "agent_bedrock" {
  name   = "${var.project}-agent-bedrock"
  role   = aws_iam_role.agent_exec.id
  policy = data.aws_iam_policy_document.agent_bedrock.json
}

# Read-only catalog access: the agent's tools only ever Scan the two tables.
data "aws_iam_policy_document" "agent_dynamodb" {
  statement {
    effect  = "Allow"
    actions = ["dynamodb:Scan"]
    resources = [
      aws_dynamodb_table.products.arn,
      aws_dynamodb_table.categories.arn,
    ]
  }
}

resource "aws_iam_role_policy" "agent_dynamodb" {
  name   = "${var.project}-agent-dynamodb-read"
  role   = aws_iam_role.agent_exec.id
  policy = data.aws_iam_policy_document.agent_dynamodb.json
}

# Runtime plumbing: read its own code artifact, write logs/metrics/traces, and
# fetch its workload identity token (AgentCore requires this at startup).
data "aws_iam_policy_document" "agent_runtime_basics" {
  statement {
    sid       = "ReadCodeArtifact"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.agent_artifacts.arn}/*"]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"]
  }

  statement {
    sid       = "DescribeLogGroups"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:*"]
  }

  statement {
    sid       = "Metrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["bedrock-agentcore"]
    }
  }

  statement {
    sid    = "Tracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "WorkloadIdentity"
    effect  = "Allow"
    actions = ["bedrock-agentcore:GetWorkloadAccessToken"]
    resources = [
      "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default",
      "arn:aws:bedrock-agentcore:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:workload-identity-directory/default/workload-identity/*",
    ]
  }
}

resource "aws_iam_role_policy" "agent_runtime_basics" {
  name   = "${var.project}-agent-runtime-basics"
  role   = aws_iam_role.agent_exec.id
  policy = data.aws_iam_policy_document.agent_runtime_basics.json
}

# --- The runtime itself ---
resource "aws_bedrockagentcore_agent_runtime" "support_agent" {
  # Runtime names allow letters/digits/underscores only (no hyphens).
  agent_runtime_name = local.agent_runtime_name
  description        = "Computer Shop customer support agent (Strands, catalog-grounded)."
  role_arn           = aws_iam_role.agent_exec.arn

  agent_runtime_artifact {
    code_configuration {
      entry_point = ["agent.py"]
      runtime     = "PYTHON_3_12"
      code {
        s3 {
          bucket = aws_s3_bucket.agent_artifacts.bucket
          prefix = aws_s3_object.agent_code.key
        }
      }
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  environment_variables = {
    PRODUCTS_TABLE   = aws_dynamodb_table.products.name
    CATEGORIES_TABLE = aws_dynamodb_table.categories.name
  }
}
