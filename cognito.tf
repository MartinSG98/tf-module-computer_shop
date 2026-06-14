# Cognito user pool backing the admin area.
#
# Self-signup is disabled: the only accounts are the two demo users created
# below (user-normal, user-admin). The pool fronts the /admin/* API routes via
# the HTTP API JWT authorizer (added in apigateway.tf), and the "admins" group
# is what separates an admin from a normal signed-in user. The authorizer only
# proves the token is valid; the backend checks the cognito:groups claim to gate
# admin actions.
#
# Note on tokens: the HTTP API JWT authorizer validates the `aud` claim against
# the app client id, and only the ID token carries `aud` (Cognito access tokens
# use `client_id` instead). So the frontend must send the ID token in the
# Authorization header. The ID token also carries cognito:groups, which the
# backend reads for the admin check.

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-users"

  # Admin-create-only: no public sign-up. Terraform creates the demo users.
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_uppercase = true
    require_symbols   = false
  }
}

# SPA public client (no secret). USER_PASSWORD_AUTH lets the frontend log a demo
# user in programmatically when the user switches accounts, without the SRP
# handshake; SRP is also allowed for amazon-cognito-identity-js defaults, and
# refresh keeps the session alive.
resource "aws_cognito_user_pool_client" "app" {
  name         = "${var.project}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# Membership of this group is the admin flag. It surfaces in the ID token's
# cognito:groups claim, which the backend checks on /admin/* routes.
resource "aws_cognito_user_group" "admins" {
  name         = "admins"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Members may access the admin API and dashboard."
}

# --- Demo accounts ------------------------------------------------------------
#
# These are throwaway demo credentials, intentionally not real secrets: the
# frontend bundles them so the "switch user" action can log in silently. The
# accounts have no power beyond this demo's admin dashboard.

resource "aws_cognito_user" "normal" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "user-normal"
  password     = var.demo_normal_password

  # Permanent password + suppressed invite: the account is immediately usable,
  # with no FORCE_CHANGE_PASSWORD step and no invite email.
  message_action = "SUPPRESS"
}

resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = "user-admin"
  password     = var.demo_admin_password

  message_action = "SUPPRESS"
}

resource "aws_cognito_user_in_group" "admin" {
  user_pool_id = aws_cognito_user_pool.main.id
  group_name   = aws_cognito_user_group.admins.name
  username     = aws_cognito_user.admin.username
}
