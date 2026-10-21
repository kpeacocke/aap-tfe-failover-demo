# Validation and customer acceptance

[Home](../README.md) | [Setup](setup.md) | [Operations](operations.md)

## What the evidence proves

| Layer | Coverage | Does not prove |
| --- | --- | --- |
| Static | Terraform formatting/validation, ShellCheck, Ansible/YAML lint | Live account permissions or platform compatibility |
| Local application | Python tests and real Chromium-rendered pages | Portal authentication or AWS networking |
| API/runtime fixtures | Real collections, TLS API fixtures, HAProxy/application processes, workflow stages and lifecycle guards | Actual HCP/AWS/AAP service availability |
| Read-only live | Actual Portal OAuth/catalog/RBAC and readiness | A traffic-changing operation succeeds |
| Explicit live operations | Portal workflows, real quarantine, failover and standby recovery | Production RTO/RPO, data replication or recreated-lab acceptance |
| Teardown | Historical AWS/content removal and workspace safe-delete | Fresh recreation after teardown |

Historical results and failed attempts remain in the
[implementation record](IMPLEMENTATION.md). The supplied original lab is
offline. Do not substitute historical workflow IDs for customer acceptance.

## Credential-free checks

The two jobs in [ci.yml](../.github/workflows/ci.yml) are the canonical complete
validation recipe. Normal PR/push CI does not provision AWS, configure RHDP or
use the private environment file. Do not add cloud secrets to ordinary CI.

For local application/browser checks, use a compatible Python virtual
environment and the existing pinned manifests:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r tests/requirements.txt
python -m pytest tests/test_application.py -v
npm --prefix tests/portal-browser ci
(cd tests/portal-browser && npx playwright install chromium)
npm --prefix tests/portal-browser run test:contracts
npm --prefix tests/portal-browser run test:local
```

Terraform checks do not apply infrastructure:

```bash
terraform fmt -check -recursive terraform
for root in terraform/shared terraform/dc1 terraform/dc2; do
  terraform -chdir="$root" init -backend=false -input=false
  terraform -chdir="$root" validate
done
```

Use a clean clone for backend-free validation; do not repurpose an initialized
live working directory's backend settings. Provider initialization needs network
access but no lab credentials.

The complete fixture/lint sequence and dependencies are kept in CI rather than
duplicated as a second divergent build system. Important test entrypoints:

| Entrypoint | Coverage / prerequisites |
| --- | --- |
| `tests/test-terraform-env.sh`, `test-ssh-key.sh`, `test-workspace.sh`, `test-runtime-env.sh` | Wrapper configuration and refusal paths; disposable fixtures |
| `tests/test-aap-config.sh` then `tests/test-portal-config.sh` | Build local EE and verify declarative configuration/templates; Docker |
| `tests/test-lifecycle.sh` | Saved-plan/ownership/quarantine and platform-removal contracts; Ansible dependencies |
| `tests/test-demo-simulation.sh`, `tests/test-demo-status.sh` | Real production helper/status logic against local fixtures; built EE |
| `tests/test-terraform-api.sh` | Pinned collection/SDK with local TLS Terraform API fixture; Docker |
| `tests/test-runtime.sh` | Real HAProxy, app processes and isolated AAP-stage/lock/failure behavior; Docker |

Run shell entrypoints with `bash`. Follow CI's certified collection extraction
and `ANSIBLE_COLLECTIONS_PATH` before linting; host-global Ansible versions are
not an equivalent certified schema. No new test runner is required.

## Customer acceptance

The receiving customer should record commit, lab owner/expiry, tool versions,
account/region, platform versions and pass/fail outcomes **privately**.
Sanitize any report before committing it. Do not include tokens, full state,
private keys, Secret payloads or authentication URLs.

| Gate | Required evidence |
| --- | --- |
| Source and prerequisites | Published revision available to AAP/image/catalog; supported existing platforms and entitlements; dedicated workspace organization |
| Deployment | Guarded bootstrap successful; exact owned infrastructure/content; verified HAProxy SSH trust and AAP execution `/32` |
| Readiness | `bash scripts/demo-status.sh` exits 0 / READY; record actual active direction |
| Restricted access | Separate operator browser profile; OAuth succeeds; exactly two templates; anonymous/invalid/admin paths denied |
| Planned failover | New reference; all AAP stages pass; both target nodes serve; exact source quarantine and available shared/target |
| Recovery | Same reference; healthy isolated old source; normal owned unlock; traffic remains on the new active site |
| Interruption procedure | Owners understand marker/quarantine retention, side-effect ambiguity and no blind retry/force-unlock |
| Cleanup | Separately approved preflight and teardown; verify removed resources and explicitly retained identities/storage |

Planned failover/recovery can take tens of minutes; reserve sufficient lab
lifetime. Optional outage testing needs additional approval. Never deliberately
interrupt a customer operation just to complete an acceptance table.

Acceptance is incomplete if any required command exits nonzero, despite
partial pass counts. Record failed runs honestly; repeat only after inspecting
actual state and resolving the owning incident safely.

## Live validation is a separate approval

The browser tests use actual Portal/AAP, not mocks:

```bash
# Existing configured lab; read-only OAuth/catalog/RBAC.
bash tests/test-portal-browser.sh access.spec.mjs catalog.spec.mjs
```

Two independent opt-in scenarios exist. **Do not enable/run them together.**

| Opt-in | Real effect |
| --- | --- |
| `DEMO_PORTAL_LIVE_OPERATIONS=true bash tests/test-portal-browser.sh` | Four-operation planned switch/recover/switchback/recover suite; requires clean DC1 baseline; ends on DC1 |
| `DEMO_LIVE_FAILURE_SMOKE=true bash tests/test-portal-browser.sh failure-smoke.spec.mjs` | Stops the exact two DC1 instances, verifies 503, fails over through Portal, starts DC1, recovers standby; ends on DC2 |

The administrator helpers `simulate-dc1` and `restore-dc1` under
`scripts/aap-configure.sh` require `DEMO_LIVE_FAILURE_SMOKE=true`. They never
create/terminate instances. Restore does not release quarantine or switch traffic.
On failure or cancellation, inspect all real state; automatic compensation is
deliberately not provided.

### Manual GitHub Actions

[live.yml](../.github/workflows/live.yml) is manual-only on `main`, serializes
its own runs and uses the `demo-live` environment. **Before adding secrets**,
configure required reviewers and a `main` deployment branch restriction.
Workflow YAML alone does not configure those protections. GitHub concurrency
does not serialize outside administrators or Portal users.

Environment variables:

| Variable | Scope |
| --- | --- |
| `DEMO_PORTAL_URL`, `AAP_HOSTNAME` | Both scopes; verified HTTPS base URLs |
| `HAPROXY_PUBLIC_IP`, `HCP_TERRAFORM_ORGANIZATION` | Failure smoke |
| `AWS_ACCOUNT_ID`, `AWS_REGION` | Failure smoke; explicit expected identity |

Environment secrets:

- Both scopes: restricted `DEMO_OPERATOR_PASSWORD`.
- Failure smoke: read-capable administrative `AAP_TOKEN`, output-read
  `TFE_TOKEN`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and
  `AWS_SESSION_TOKEN` if temporary credentials require it.
- AWS permissions include inspection and start/stop of only the existing DC1
  demo instances; no create/terminate permission is needed for the smoke.
  Quarantine uses the AAP workflow's existing credential, not the test token.

Default scope is read-only. Failure smoke requires exact `STOP DC1` confirmation
and a clean DC1-active baseline. No authentication state, browser traces or
live screenshots are uploaded as artifacts. Local test results still require
private handling.

The historical full live acceptance ran locally. Dispatch through a
customer-configured GitHub live environment remains a separate acceptance step.
