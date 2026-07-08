# ADR-0003: Module consumed by a pinned git tag

- Status: Accepted
- Date: 2026-06-14

## Context

This is a polyrepo: the deployment stack (tf-stack-computer_shop) consumes this
module. Deploys need to be reproducible, and the version in use needs to be
deliberate rather than "whatever `main` happens to be right now".

## Decision

- The stack references this module by a pinned git tag
  (`source = "...?ref=vX.Y.Z"`), switching to a local path only during
  development.
- A `VERSION` file drives releases: a GitHub Actions workflow tags `vX.Y.Z` when
  `VERSION` changes on `main` (idempotent, semver-validated).

## Consequences

- Deploys are reproducible and pinned; upgrading the module is an explicit stack
  change.
- Releasing requires bumping `VERSION` in the PR; a merge that forgets it does
  not tag, so there are no accidental releases.
- After a module release the stack must be re-pinned to the new tag before it
  picks up the change.

## Alternatives considered

- Consuming the module by branch / `main` (rejected: non-reproducible, silent
  drift).
- A private Terraform registry (overkill for a solo polyrepo).
- Auto-incrementing the patch version on every merge (cannot express minor/major
  intent).

See the module README "Releasing".
