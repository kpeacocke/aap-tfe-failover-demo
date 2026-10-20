# Agent guidance

Before modifying this repository:

1. Read `docs/IMPLEMENTATION.md`.
2. Determine which implementation phase is currently active.
3. Do not implement future phases.
4. Inspect existing code before creating replacement implementations.
5. Prefer modifying existing code over duplicating functionality.
6. Run the relevant validation tools before claiming completion.
7. Clearly report:
   - files changed
   - commands run
   - tests passed/failed
   - unresolved assumptions
   - next recommended phase

8. For AAP configuration, follow the current `ansible/product-demos` bootstrap pattern and use `infra.aap_configuration.dispatch` with declarative variable files instead of inventing imperative AAP API automation.
9. Assume AAP 2.7 and OpenShift are already installed by RHDP. Do not install or upgrade either.
10. Self-Service Automation Portal must be deployed/reconciled onto the existing RHDP OpenShift cluster by this project when missing; do not use a separate RHEL Portal appliance for the RHDP path.

Never expose or commit credentials.
