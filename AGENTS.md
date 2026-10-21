# Optional AI contributor guidance

This file guides coding assistants; it is not a runtime dependency or an
operator runbook. No agent service or AI extension is required by this demo.
Human contributors use [CONTRIBUTING.md](CONTRIBUTING.md).

Before changes, read [the current scope](docs/IMPLEMENTATION.md) and relevant
customer guides. All eight original phases are complete; current work is
evaluation-demo maintenance. Do not invent a next phase or broaden scope
without explicit approval and a scope update.

## Boundaries

- RHDP supplies AAP 2.7 and OpenShift. Never install, upgrade or remove them.
- Portal is a project-managed add-on on that existing cluster, not a separate
  RHEL appliance. Verify supported interfaces before changing its deployment.
- Terraform owns infrastructure; AAP owns operations; Portal is the restricted
  user front door. Preserve that separation.
- Use HCP Terraform Free at `app.terraform.io` and an explicitly verified AWS
  account/region. Do not reuse historical lab values.
- Reconcile AAP through the `ansible/product-demos` pattern and
  `infra.aap_configuration.dispatch` with declarative variables. Verify the
  installed collection/module schemas; never invent parameters or APIs.
- Preserve exact ownership/tag checks, idempotency, TLS/SSH trust, quarantine
  and marker safeguards. Never silently force-unlock or remove guards.

## Working practice

Inspect existing code and reuse helpers before editing. Keep changes focused,
use Ansible FQCNs, add regression coverage and update task-oriented docs.
Follow [validation](docs/validation.md), including Terraform fmt/validate and
Ansible lint where relevant.

Do not run live provisioning, traffic changes, fault injection, credential
rotation or destruction without explicit approval for that action and scope.
Never read/print/commit secrets unnecessarily, including `.env`, private keys,
state, cluster Secrets or private reports. Preserve unrelated worktree changes.

Report changed files, exact commands/results, failed/skipped checks and remaining
assumptions. Do not equate fixture success with live acceptance or describe this
evaluation as production-ready.
