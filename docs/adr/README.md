# Architecture Decision Records

Short records of the significant, non-obvious decisions behind this module.
Format is lightweight MADR (Context / Decision / Consequences / Alternatives).
These are point-in-time records; they are not updated when superseded, a new
ADR supersedes an old one.

This module owns the system-wide infrastructure decisions, so the cross-cutting
ADRs (cost, auth, versioning) live here and the app repos link to them.

| ADR | Title |
| --- | --- |
| [0001](0001-cost-first-free-tier-posture.md) | Cost-first, free-tier posture |
| [0002](0002-cognito-admin-authentication.md) | Cognito authentication for the admin area |
| [0003](0003-module-consumed-by-pinned-tag.md) | Module consumed by pinned git tag |
