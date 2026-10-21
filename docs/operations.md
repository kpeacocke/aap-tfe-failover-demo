# Operations and teardown

[Home](../README.md) | [Setup](setup.md) | [Presenter runbook](demo-runbook.md)

## Operator boundaries

| Role | Approved activity |
|---|---|
| Restricted Portal user | Two fixed failover/recovery templates; no supplied infrastructure credentials or arbitrary job parameters |
| Lab administrator | Bootstrap, read-only inspection, credential maintenance, explicit failure simulation, interruption review and teardown |
| Terraform administrator | Reviewed infrastructure lifecycle and state maintenance; never concurrent with active demo operations |

Use the Portal for the customer-facing demonstration. AAP administrative CLI
entrypoints use the same staged workflows; lower-level CLI helpers are
diagnostic building blocks, not an alternative unrestricted customer front door.

## Readiness and current links

```bash
bash scripts/demo-status.sh
# Private diagnostics, not intended for screen sharing:
bash scripts/demo-status.sh --details
```

The status tool reads actual HCP outputs, not a saved application IP. It
requires existing deployment, credentials, Docker, the matching local SSH key,
verified SSH trust and `DEMO_PORTAL_URL`. It writes private local reports under
ignored `.local/status/`; it makes no remote changes.

READY accepts either active direction and requires both active nodes healthy,
healthy isolated standby, expected HTML/traffic, unlocked workspaces, no marker,
no active AAP jobs, AAP 2.7 and Portal HTTPS/anonymous denial. It does not prove
browser login or reserve the environment. A partial failure may stop before a
complete report is written.

## Failover and same-reference recovery

Follow [the presenter runbook](demo-runbook.md) for Portal inputs and narration.
Choose a unique reference and submit only once:

1. Validate healthy target and actual active state.
2. Quarantine the source workspace with the incident reference.
3. Drain source sessions for planned maintenance; failure mode requires a real
   unavailable source.
4. Activate target and validate both nodes/public service.
5. Recover the old source **as standby**, using the same reference.

Administrative equivalents, assuming DC1 is currently active:

```bash
bash scripts/aap-configure.sh failover dc2 CHG-EXAMPLE-001
bash scripts/aap-configure.sh recovery dc1 CHG-EXAMPLE-001
```

Use your own new reference. Recovery does not switch traffic back, repair AWS
infrastructure or run an unlocked Terraform plan. Optional switchback is a
new planned failover followed by same-reference recovery of its old source.

`planned` mode is default. For an explicitly approved real source outage,
the failover wrapper accepts a final `failure` argument. Do not use it to bypass
draining of a healthy source. Fault-injection helpers are administrator-only;
see [live validation](validation.md#live-validation-is-a-separate-approval).

### Evidence and interrupted operations

Keep the Portal task, AAP workflow ID, child-job outcomes and original reference.
Final Controller artifacts include `demo_workflow_result` and verified lock/
validation evidence. Stage details are for administrators, not an additional
restricted-user permission.

If a command times out, a worker stream fails or a workflow is cancelled:

- Stop further submissions and preserve evidence.
- Confirm the owning workflow and **all children** are terminal.
- Inspect actual instance/health/traffic state, HCP lock owner/reason and
  `/run/ww-demo-failover.lock/request.json` on HAProxy.
- External side effects may have completed before event-stream loss. Recheck
  current state; neither the client error nor the last marker stage proves
  that a lock/unlock or traffic change did not happen.
- A failed transition retains quarantine, even after validated traffic rollback.
  Do not force-unlock, use `-lock=false`, steal a marker or cancel unrelated jobs.
- Only after explicit administrator approval and verified safe preconditions
  may an exact stale marker be archived and removed. Retry only the appropriate
  original-reference recovery, not the whole outage sequence blindly.

No automatic repair, marker stealing or all-or-nothing rollback is promised.
HAProxy runtime state resets to DC1 on restart/replacement; do not restart it
to reset the presentation.

## Administrative tools

| Entrypoint | Purpose / caution |
|---|---|
| `aap-configure.sh check` | Verify existing AAP version/authentication |
| `aap-configure.sh inspect` / `inspect-openshift` | Inspect platform metadata privately |
| `aap-configure.sh build-ee` | Reconcile/build demo image from a published local commit |
| `aap-configure.sh install` / `setup` | Mutating common/demo AAP reconciliation |
| `aap-configure.sh portal-check` | Inspect existing Portal/platform compatibility |
| `aap-configure.sh portal-install` / `portal-verify` | Mutating Portal reconciliation / read-only verification |
| `terraform-workspace.sh discover` | Read API-derived workspace/topology metadata |
| `runtime-failover.sh <dc> <reference> [planned\|failure]` | Lower-level integrated runtime failover; changes traffic and quarantine |
| `terraform-workspace.sh lock\|unlock <dc> <reference>` | Administrative incident-owned quarantine/release, with normal unlock only |

All commands above are invoked with `bash scripts/` followed by the entrypoint.
Only DC1/DC2 can be quarantined; the shared workspace is never locked by demo
runtime automation. Release requires the original incident, healthy recovered
nodes in maintenance and validated service at the other site.

The legacy [manual helper](../scripts/manual-failover.sh) bypasses quarantine.
It is retained for the original infrastructure-only demonstration, **not**
recommended for customer self-service. Never mix it with integrated operations.

Operational API helpers also accept a separate HTTPS Terraform Enterprise
endpoint/token and optional CA bundle; Enterprise compatibility is fixture-tested
only. Provisioning/lifecycle remain HCP-only. This is not a supported Enterprise
deployment guide.

## Credentials and retained material

| Material | Owner action |
|---|---|
| Private `.env` | Protect with mode 0600, restrict machine access, rotate/revoke expired lab credentials |
| `.local/ssh/ww-demo` | Unencrypted dedicated private key; protect and securely back up if reusing |
| `.local/aap-operator-password` | Hand to the authorized operator through an approved private channel only |
| AAP credentials | Routine reconciliation uses `update_secrets: false`; rotate deliberately in the correct scoped objects |
| OpenShift Portal Secrets | Preserve with retained OAuth/service identities; one-time credentials are not recoverable by simply rerunning setup |
| Portal PVCs | May retain catalog/task data; agree retention, access and later disposal |
| Terraform state/backends and private reports | Never publish, attach to issues or put into a customer ZIP without review |

Changing `.env` alone does **not** rotate existing AAP secrets. Credentials named
"AWS Health Read" still have the underlying supplied IAM permissions. Local
profile/SSO use does not populate the AAP credential.

After EC2 stop/start, ephemeral application public-IP outputs may change.
Inspect a saved refresh-only plan before state-only reconciliation; never apply
unexpected resource changes merely to finish a smoke test. AMI discovery uses
the latest matching image, so later normal plans can legitimately propose
replacement and need explicit review.

## Teardown

**This removes the demo, not RHDP. Reserve a maintenance window and inspect
actual guards first.**

```bash
# Non-destructive: real destroy plans and conservative ownership/activity checks.
bash scripts/teardown.sh profiles/demo.yml

# DESTRUCTIVE: authorize AWS destruction and bounded demo AAP/Portal cleanup.
bash scripts/teardown.sh profiles/demo.yml --confirm-destroy
```

The confirmed command:

1. Requires expected AWS account/region, exact local-execution workspaces,
   no active AAP jobs, no quarantine and no retained operational marker.
2. Verifies object ownership and reserves the standard HAProxy operation marker.
3. Applies exact saved normal-locking destroy plans in **DC1 -> DC2 -> shared**
   order, with address/tag allowlists.
4. Rechecks and removes only demo AAP content through declarative dispatch,
   the supported exact Portal Helm release and labelled execution-image objects.
5. Optionally safe-deletes emptied HCP workspaces.

Default `terraform.retain_history: true` keeps workspace history. To delete the
three empty workspaces, explicitly set it to `false` in a non-secret profile
copy and pass that copy to both preflight and confirmed commands. HCP's
safe-delete action is used, never unconditional workspace deletion.

Retained intentionally: AAP organization/user/team shells, global credential
type, namespace shells, Portal PVCs/OAuth/credential Secrets, local keys/password,
and the HCP project. Retained storage can still consume capacity/cost.
Removing it later is a separate approved disposal task, not implied by teardown.

If interrupted, inspect actual state before resuming. Some AWS/content may
already be removed. A surviving marker needs explicit ownership/terminal-state
review; it is never silently cleared. Never delete an entire namespace,
shared platform, identity collection or credential directory as a workaround.

### Verify completion

Require successful command exit, then independently check:

- No active demo EC2 resources, demo VPC, EIP or managed EC2 key registration.
- Empty Terraform resources, or workspace 404s if safe-delete was selected.
- Demo AAP automation removed; unrelated objects/retained identities unchanged.
- Demo Portal release/workload and exact execution-image objects absent.
- Existing AAP/OpenShift available; retained PVCs/Secrets/namespaces still present.

Historical teardown passed these checks. A fresh recreation afterward has not
been live-tested. Bootstrap is the intended recreation path, but requires fresh
lab credentials, trust validation and complete customer acceptance again.
