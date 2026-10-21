## Purpose

Describe the customer/operator problem and the focused change. Link a related
issue if applicable.

## Behavior and scope

- What changes? What is intentionally unchanged?
- Does this affect ownership, quarantine, marker recovery, credentials,
  Portal permissions or teardown?
- Are there compatibility or migration steps?

## Validation

List exact commands, exit codes, pass/fail/skip counts and any unverified scope.
Distinguish local fixtures from real live acceptance. Do not attach private logs.

## Checklist

- [ ] I inspected the diff for credentials, state, private keys and customer data.
- [ ] Existing RHDP AAP/OpenShift are not installed, upgraded or removed.
- [ ] Terraform lifecycle and AAP operational ownership remain separate.
- [ ] Relevant tests and customer documentation are updated.
- [ ] Ansible interfaces were verified if module/collection fields changed.
- [ ] No live operation was run without explicit scope/impact approval.
- [ ] Remaining risks or skipped checks are stated honestly.
