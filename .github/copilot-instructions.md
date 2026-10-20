# Project instructions

Read `docs/IMPLEMENTATION.md` before making architectural or implementation changes.

The implementation document is the source of truth for scope, architecture, acceptance criteria and implementation order.

Rules:

- AAP 2.7 and OpenShift are pre-installed by RHDP. Never install or upgrade AAP or OpenShift.
- Self-Service Automation Portal is an add-on managed by this project: detect it, deploy it onto the existing RHDP OpenShift cluster if missing, and reconcile/reuse it if already present.
- Target HCP Terraform Free at `app.terraform.io` and AWS `ap-southeast-2`.
- In the RHDP path, deploy Portal on the existing OpenShift cluster; do not deploy a separate RHEL Portal appliance.
- Verify the current supported AAP 2.7 Portal OpenShift installation method before implementing; do not invent CRDs, Helm values, OAuth settings, Routes, or Secrets.
- For AAP configuration-as-code, follow the Red Hat `ansible/product-demos` pattern:
  - authenticate to the existing AAP instance with environment variables;
  - query `/api/gateway/v1/ping/` and require AAP 2.7;
  - load declarative variable files;
  - use `infra.aap_configuration.dispatch` to reconcile AAP objects;
  - prefer supported `controller_*`, `aap_*`, and `gateway_*` variable structures over imperative API task sequences.
- Verify `infra.aap_configuration` schemas against the installed collection before using fields. Do not guess.
- Separate common bootstrap configuration from failover-demo-specific setup, modelled on APD's `install-apd.yml`, `common/bootstrap-vars.yml`, and `setup_demo.yml`.
- All project-created AAP and AWS resources must be clearly prefixed/tagged as demo-managed.
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
