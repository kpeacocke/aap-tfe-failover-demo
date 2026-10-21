# Security policy

## Scope

This is an evaluation demonstration, not a production-hardened or certified
service. The maintained code line is `main`; no backport or security-response
SLA is promised. Third-party products/images retain their own support policies.

The public application uses HTTP and has no customer authentication or data
replication. A single HAProxy fronts logical sites in one AWS region.
Use disposable lab data and scoped credentials only. See
[architecture](docs/architecture.md) and [operations](docs/operations.md).

## Report privately

**Do not open a public issue or PR containing a suspected vulnerability,
exploit details, credentials or customer information.**

If this repository's **Security -> Advisories -> Report a vulnerability**
option is available, use GitHub private vulnerability reporting. Otherwise,
contact the repository owner through your existing agreed private handover
channel and arrange a secure report before sharing details. No public inbox
or unverified email address is offered here.

Repository owners should enable private vulnerability reporting before
customer distribution. The policy file does not enable that GitHub setting.
See the [owner checklist](docs/handover-review.md#github-owner-settings).

Include a sanitized affected revision, component, impact, prerequisites and
minimal reproduction. Never include real tokens, private keys, full state,
cluster Secrets or access to a customer lab. Agree disclosure timing privately.

## Exposed credentials

Revoke/rotate the credential through its owning provider immediately, notify
the lab/security owner privately, and preserve evidence using the customer's
incident process. Removing a value from the latest Git commit does not remove
it from history, forks, logs or caches.

Coordinate changes to AAP credentials, OAuth/service identities and retained
Portal Secrets; routine reconciliation deliberately does not rotate existing
secrets. Do not delete retained identity Secrets while assuming their one-time
credentials can be recovered.

## Repository safeguards

Keep `.env`, `.local/`, state, plans and authentication results private.
Keep TLS and SSH host verification enabled. Never bypass quarantine with
force-unlock/`-lock=false`, automatically remove markers, or attach admin
credentials to restricted-user jobs.

Credential-free CI and dependency update proposals are useful checks, **not**
a vulnerability audit or a clean bill of health. No SAST, CVE scan, SBOM or
penetration-test result is claimed by this policy.
