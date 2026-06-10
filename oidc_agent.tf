# Keyless deploy role for the support-agent repo's GitHub Actions. Dedicated
# (not the eval/backend roles) so its permissions stay scoped to the agent
# artifacts bucket and the AgentCore runtime only.

data "aws_iam_policy_document" "github_agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_agent_subs
    }
  }
}

resource "aws_iam_role" "github_agent_deploy" {
  name               = "${var.project}-github-agent-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_agent_assume.json
}

# Least privilege: upload the code zip and refresh the runtime to pick it up.
data "aws_iam_policy_document" "github_agent_deploy" {
  statement {
    sid       = "UploadAgentCode"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.agent_artifacts.arn}/*"]
  }

  # The runtime caches the zip it was created/updated with, so CI must call
  # UpdateAgentRuntime after uploading for the new code to take effect.
  statement {
    sid    = "RefreshRuntime"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:UpdateAgentRuntime",
      "bedrock-agentcore:GetAgentRuntime",
    ]
    resources = ["${aws_bedrockagentcore_agent_runtime.support_agent.agent_runtime_arn}*"]
  }

  # UpdateAgentRuntime re-submits the execution role, which requires PassRole.
  statement {
    sid       = "PassExecutionRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.agent_exec.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_agent_deploy" {
  name   = "deploy-agent"
  role   = aws_iam_role.github_agent_deploy.id
  policy = data.aws_iam_policy_document.github_agent_deploy.json
}
