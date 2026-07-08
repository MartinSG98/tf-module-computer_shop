# ADR-0002: Cognito authentication for the admin area

- Status: Accepted
- Date: 2026-06-14

## Context

The storefront is public and anonymous. We needed an admin-only area (the sales
dashboard) over the same HTTP API without gating the public catalog, and without
standing up costly auth infrastructure.

## Decision

- A Cognito user pool (Lite tier) with self-signup disabled. Terraform creates
  two demo accounts; `user-admin` is in an `admins` group, and group membership
  is the admin flag.
- The HTTP API native JWT authorizer is attached to a dedicated
  `ANY /admin/{proxy+}` route only; `$default` stays open so the store stays
  anonymous.
- The frontend sends the Cognito **ID token** as the bearer, because only the ID
  token carries the `aud` claim the authorizer validates and the `cognito:groups`
  claim the backend reads.
- The authorizer only proves authentication; the backend checks `cognito:groups`
  for the `admins` group and returns 403 otherwise.
- A separate **unauthenticated** `OPTIONS /admin/{proxy+}` route lets the CORS
  preflight through. Preflights carry no token, so routing them through the JWT
  authorizer would 401 them and break every admin call from the browser.
- Demo credentials are bundled in the frontend. They are not real secrets; the
  accounts are powerless (read-only dashboard) throwaways.

## Consequences

- The public catalog stays anonymous; only `/admin/*` requires a token.
- Auth cost is ~$0 (Lite tier, no threat protection).
- Anyone can read the bundled demo credentials. Acceptable only because the
  accounts can do nothing of value. Real users would need per-user sign-up, no
  bundled secrets, and role-by-group rather than a shared password.

## Alternatives considered

- REST API Cognito user-pool authorizer (we use HTTP API; its JWT authorizer is
  cheaper and simpler).
- A Lambda authorizer (more moving parts and cost for no gain here).
- Sending the access token (it lacks `aud`; Cognito access tokens use
  `client_id`).
- API Gateway-managed CORS (would duplicate the FastAPI CORS headers).

See the module README "Admin auth (Cognito)".
