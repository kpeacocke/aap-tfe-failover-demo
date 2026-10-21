# Contributing

Contributions should improve a safe, understandable **RHDP evaluation demo**,
not imply production readiness. Read [architecture](docs/architecture.md),
[the current scope](docs/IMPLEMENTATION.md) and
[validation](docs/validation.md) before changing behavior.

## Workflow

1. Open a sanitized issue for a significant design or scope change. Agree the
   objective before adding infrastructure, services or abstraction layers.
2. Create a focused branch from `main`. Inspect/reuse existing roles and
   entrypoints rather than adding a parallel implementation.
3. Keep Terraform responsible for infrastructure and AAP responsible for
   operations. Never install, upgrade or remove RHDP AAP/OpenShift.
4. Verify installed collection/module schemas before changing Ansible fields.
   Use declarative `infra.aap_configuration.dispatch` for AAP configuration.
5. Add focused regression tests and update affected customer guides.
6. Open a PR with the behavior change, exact commands/results and remaining
   limitations. Use the [PR template](.github/pull_request_template.md).

All eight original phases are complete. New work is maintenance unless an
explicitly approved scope change updates the implementation document.
Repository AI guidance is optional; no AI subscription is a prerequisite.

## Local checks and CI

Use [the validation guide](docs/validation.md) and the exact recipe in
[ci.yml](.github/workflows/ci.yml). Run the smallest tests covering the change;
full PR CI must pass before merge. Documentation changes should check relative
links, commands against actual wrappers and all referenced prerequisites.

Normal PR validation must remain credential-free and must not create resources,
run live workflows, stop instances or read a maintainer's environment file.
Live tests need separate explicit approval, isolated lab credentials and the
protected `demo-live` environment; they must never become a PR default.

Do not disable ownership, lock, marker, host-trust or TLS guards to make a test
pass. A failed operation must remain visibly failed even if rollback succeeds.
Record exit codes and do not describe skipped/mocked tests as live acceptance.

## Secrets and customer information

- Do not commit `.env`, local keys/passwords, Terraform state/plans, cluster
  Secret payloads, browser authentication state or live environment reports.
- Use documentation placeholders, not customer account IDs, IPs or lab routes.
- Inspect the actual staged diff before committing. Do not stage ignored files
  or a whole working directory without review.
- For a suspected vulnerability or leaked credential, follow
  [SECURITY.md](SECURITY.md), not a public issue.

## Dependency and source changes

The execution image, Python packages, collections, Portal chart and browser
tooling have deliberately checked interfaces. Dependency PRs are proposals,
not authorization to upgrade a live platform. Inspect compatibility, rebuild
the EE, run contracts/lint, and repeat approved live acceptance where behavior
changes. Do not auto-merge solely because package installation succeeds.

Fork/mirror support needs aligned AAP, OpenShift build, Portal catalog, cleanup
allowlists and tests. See [source configuration](docs/setup.md#source-repository-and-revisions).
Preserve ownership guards rather than broadening deletion by name.

## License and conduct

By submitting a contribution, you agree it is available under the repository's
[MIT license](LICENSE), and that you have the right to contribute it.
Respect third-party licenses and do not copy proprietary customer content.
Follow the [code of conduct](CODE_OF_CONDUCT.md).
