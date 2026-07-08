# ADR-0001: Cost-first, free-tier posture

- Status: Accepted
- Date: 2026-06-14

## Context

The Computer Shop is a portfolio/demo, not a production system. There is no
budget for idle or per-unit cloud cost, so "stay in the AWS free tier / ~$0" is
a hard constraint on every infrastructure decision, not an afterthought.

## Decision

Pick the cheapest option that still demonstrates the architecture:

- DynamoDB tables `PROVISIONED` at 5/5, kept within the always-free 25 RCU + 25
  WCU per region (products + categories + orders = 15/15).
- Cognito on the **Lite** tier; advanced security / threat protection off.
- No WAF; abuse is bounded with API Gateway throttling instead.
- Terraform state is local.
- Admin metrics are computed in-app from a single table scan; no secondary index.
- One shared API Lambda rather than new always-on resources.

## Consequences

- Recurring cost is effectively zero.
- Production features (threat protection, WAF, point-in-time recovery, remote
  state, indexed queries) are deliberately deferred.
- The module README "Cost posture" section documents each trade-off and its
  "with budget" upgrade path, so the deferral is explicit, not accidental.

## Alternatives considered

- On-demand DynamoDB, Cognito Plus + MFA + threat protection, WAF on the public
  surface, S3 + lock-table remote state, a date GSI / precomputed rollups. All
  rejected for cost; each is the documented upgrade once there is real traffic
  or a budget.
