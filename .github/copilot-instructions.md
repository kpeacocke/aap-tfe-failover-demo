# Project instructions

Read `docs/IMPLEMENTATION.md` before making architectural or implementation changes.

The implementation document is the source of truth for scope, architecture, acceptance criteria and implementation order.

Rules:

- Implement one phase at a time.
- Do not broaden scope without updating `docs/IMPLEMENTATION.md`.
- Do not invent Ansible collection module parameters or APIs. Verify interfaces before using them.
- Prefer supported Red Hat and HashiCorp APIs and collections.
- Keep Terraform responsible for infrastructure lifecycle.
- Keep AAP responsible for operational failover and recovery.
- Keep the Self-Service Automation Portal as the restricted-user front door.
- Preserve idempotency and portability.
- Use FQCNs in Ansible.
- All Terraform must pass `terraform fmt` and `terraform validate`.
- All Ansible must pass `ansible-lint`.
- Do not commit secrets.
- Do not implement later phases until the current phase is working and validated.
