# Copilot contributor instructions

Follow [AGENTS.md](../AGENTS.md) for the canonical optional AI guidance and
[CONTRIBUTING.md](../CONTRIBUTING.md) for the human contribution workflow.
Read [IMPLEMENTATION.md](../docs/IMPLEMENTATION.md) before design changes.
All eight phases are complete; this is customer evaluation-demo maintenance,
not a production service or permission to start new phases.

- Never install, upgrade or remove RHDP AAP 2.7/OpenShift. Portal is an add-on
  on that existing cluster.
- Preserve Terraform lifecycle, AAP operational and restricted Portal ownership.
- Verify installed Ansible/Portal interfaces. Use declarative AAP dispatch and
  supported APIs, not invented schemas or parallel imperative implementations.
- Preserve ownership, quarantine, marker and TLS/SSH trust guards.
- Require explicit approval before live mutations; never expose credentials.
- Reuse existing code, update relevant docs and run focused validation.
  Report exact results and gaps; do not claim fixture tests prove live readiness.
