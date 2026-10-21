# Changelog

Changes are recorded for the evaluation reference, not a production support
contract. No versioned customer release has been declared yet.

## Unreleased

### Customer handover

- Reorganized the README around value, prerequisites, deployment, safety and
  navigation rather than implementation phases.
- Added customer setup, operations, validation and handover-review guides.
- Added MIT licensing, contribution/support/security/conduct policies, issue
  forms, a PR template and monthly dependency update proposals.
- Retained concise optional AI contributor guidance; no AI runtime dependency.
- Removed the old lab account from the example configuration and corrected
  stale teardown-status documentation.
- Excluded private environment variants and saved Terraform plan files from
  normal Git staging.

### Validated implementation baseline

- Three-workspace AWS infrastructure, staged AAP failover/recovery and
  restricted Portal templates are implemented.
- Historical live Portal operations, real failure/recovery, readiness and
  guarded teardown/workspace safe-delete passed.
- Teardown fixes for verified credential types, execution-image declarations
  and the HCP JSON:API content type were published in
  [8e76803](https://github.com/kpeacocke/aap-tfe-failover-demo/commit/8e76803d03ead5c987cb2d784d7006ea84797a7f).
- Recreation after teardown and dispatch through a protected customer GitHub
  live environment remain unverified. See [handover review](docs/handover-review.md).
