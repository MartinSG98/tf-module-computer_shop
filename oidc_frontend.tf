# Frontend deploy role: a SEPARATE role from the backend one (different repo,
# different permissions). Reuses the shared GitHub OIDC provider.

data "aws_iam_policy_document" "github_frontend_assume" {
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
      values   = local.github_frontend_subs
    }
  }
}

resource "aws_iam_role" "github_frontend_deploy" {
  name               = "${var.project}-github-frontend-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_frontend_assume.json
}

# Least privilege: sync the frontend bucket and invalidate its distribution only.
data "aws_iam_policy_document" "github_frontend_deploy" {
  statement {
    sid       = "ListFrontendBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.frontend.arn]
  }

  statement {
    sid       = "WriteFrontendObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
  }

  statement {
    sid       = "InvalidateFrontendCDN"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.frontend.arn]
  }
}

resource "aws_iam_role_policy" "github_frontend_deploy" {
  name   = "deploy-frontend"
  role   = aws_iam_role.github_frontend_deploy.id
  policy = data.aws_iam_policy_document.github_frontend_deploy.json
}