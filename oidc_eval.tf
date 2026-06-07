# Keyless deploy role for the build-evaluator repo's GitHub Actions. Dedicated
# (not the backend role) so its permissions stay scoped to the eval Lambda and
# the models bucket only.

data "aws_iam_policy_document" "github_eval_assume" {
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
      values   = local.github_eval_subs
    }
  }
}

resource "aws_iam_role" "github_eval_deploy" {
  name               = "${var.project}-github-eval-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_eval_assume.json
}

# Least privilege: push the eval Lambda code and upload the model.
data "aws_iam_policy_document" "github_eval_deploy" {
  statement {
    sid       = "DeployEvalLambdaCode"
    effect    = "Allow"
    actions   = ["lambda:UpdateFunctionCode", "lambda:GetFunction"]
    resources = [aws_lambda_function.eval.arn]
  }
  # Upload the model and the (S3-deployed) code zip; GetObject is needed because
  # update-function-code --s3-bucket reads the package back.
  statement {
    sid       = "ModelAndCodeArtifacts"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.models.arn}/*"]
  }
}

resource "aws_iam_role_policy" "github_eval_deploy" {
  name   = "deploy-eval"
  role   = aws_iam_role.github_eval_deploy.id
  policy = data.aws_iam_policy_document.github_eval_deploy.json
}
