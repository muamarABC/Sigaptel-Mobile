# Contributing Guide

## Branching Strategy

- `main` is production-ready.
- `develop` is the integration branch for daily development.
- Use feature branches from `develop` with format `feature/<short-name>`.
- Use fix branches with format `fix/<short-name>`.

## Commit Convention

Use concise and descriptive commit messages.

Examples:

- `feat: add map filter by district`
- `fix: handle empty photo path`
- `docs: update setup steps`

## Pull Request Rules

- Open PRs to `develop` for normal development work.
- Keep PR scope focused (single feature or fix).
- Ensure CI workflow is green before merge.
- Include test notes and screenshots when UI changes.

## Release Flow

- Merge `develop` into `main` through a PR.
- Tag release from `main` after verification.
