# Presenter runbook: controlled datacentre failover

Prerequisite: complete [setup](setup.md) and acceptance on your own lab. The
original demonstration environment was torn down; old IPs, job IDs and routes
are not live customer endpoints.

## What the audience should learn

> Terraform owns infrastructure lifecycle. AAP owns controlled failover and
> recovery. The Self-Service Automation Portal is the restricted operator's
> front door. The source site's real Terraform workspace is quarantined until
> the original incident is safely recovered.

DC1 and DC2 are logical sites in separate availability zones of **one AWS
region**, not two physical datacentres or a multi-region DR solution. RHDP
supplies AAP 2.7 and OpenShift. This project manages only demo content and the
Portal add-on on that existing cluster.

## Prepare privately, before screen sharing

Allow at least 25 minutes for a one-way failover and standby recovery. The
complete real failure smoke took 20.1 minutes; timings vary with AAP execution
capacity. Allow additional time for login, narration and interruptions.

1. Reserve the environment: no other presenter, Portal user or infrastructure
   administrator may change it concurrently. A status check is not a lock.
2. Confirm the lab will remain available for the whole session.
3. Use the existing private `.env` and verified SSH key/known_hosts. Set
   `DEMO_PORTAL_URL` to the actual HTTPS Portal base URL without a trailing
   slash. Do not print `.env`, credentials or private keys.
4. Run:

   ```bash
   bash scripts/demo-status.sh
   ```

   Docker and the existing verified SSH trust are required. The wrapper uses
   the same execution image and collection interfaces as the existing
   bootstrap. It can build that local image, but makes no remote changes.

   Require exit 0 and **READY**. It verifies current HCP outputs/locks, AAP 2.7
   authentication, no active AAP jobs, Portal HTTPS and anonymous catalog
   denial, the exact HAProxy backend, both sites' health/identity/version,
   standby isolation, public traffic through both active nodes, the public
   HTML page and absence of the operation marker. It never installs a remote
   platform, launches a job, switches traffic, unlocks or removes markers.

   A failed prerequisite may stop before the full report is available.
   Read the reported private diagnostics path, or use:

   ```bash
   bash scripts/demo-status.sh --details
   ```

   Do not show detailed logs to the audience by default. Reports are private,
   ignored local files under `.local/status/`. They contain infrastructure
   identities/URLs, not credential values.

5. Open the **current links printed by status**, rather than copying a previous
   lab's IPs, routes, workflow IDs or OAuth authorization URL:

   | Tab | Presenter purpose |
   | --- | --- |
   | Application | Active site, serving node and health |
   | Portal catalog / failover form | Restricted user's approved operation |
   | Portal recovery form | Original-reference standby recovery |
   | AAP base console | Find the new workflow under Automation Execution / Jobs |
   | HCP shared, DC1, DC2 | Show independent infrastructure ownership and source quarantine |
   | [Source](https://github.com/kpeacocke/aap-tfe-failover-demo) / [CI](https://github.com/kpeacocke/aap-tfe-failover-demo/actions/workflows/ci.yml) | Declarative automation and credential-free checks |

6. Use a **separate browser profile/private window** for Portal user
   `ww-demo-operator`. Its password is privately stored in
   `.local/aap-operator-password`, unless explicitly supplied during setup.
   Keep the presenter's AAP/HCP administrator session separate so OAuth does
   not silently reuse administrator privileges.
7. Log into the fresh Portal catalog URL. Authorize if prompted; confirm
   exactly **Datacentre Failover** and **Recover Datacentre** are visible.
   The CLI's HTTP readiness checks do **not** prove OAuth login or SPA rendering.
   Optional real read-only browser validation:

   ```bash
   npm --prefix tests/portal-browser ci
   (cd tests/portal-browser && npx playwright install chromium)
   bash tests/test-portal-browser.sh access.spec.mjs catalog.spec.mjs
   ```

8. Choose a new incident reference, for example `present-20261021-02`. Record
   it privately. Never reuse a reference merely because it appears here.

### Choose the direction from actual state

Either clean baseline is healthy. Do not reset just to match an old run sheet.

| Active service before demo | Planned target | Recover afterward | Final active service |
| --- | --- | --- | --- |
| DC1 | `dc2` | `dc1` | DC2 |
| DC2 | `dc1` | `dc2` | DC1 |

The last Phase 7 acceptance ended on **DC2 active, DC1 healthy standby**.
That is a historical snapshot, not a substitute for the status check.

## Recommended live presentation: planned maintenance

This works in either direction and avoids intentionally taking the application
offline. Use the separate outage section only for an explicitly approved
failure scenario.

### 1. Establish the baseline (one minute)

- Show **READY**, current active site, healthy isolated standby and unlocked
  workspaces.
- Refresh the application a few times to show the two serving node names.
- Explain that both sites already exist: this is not an infrastructure apply.

### 2. Submit once as the restricted user (one minute)

In **Datacentre Failover**:

| Field | Input |
| --- | --- |
| Target datacentre | The standby site from the direction table |
| Reason | `Planned maintenance` |
| Incident/change reference | Your new recorded reference |
| Confirm traffic move | `CONFIRM` |

Click **Next**, review, then **Create once**. Keep the resulting task page.
Do not submit again because a stage is slow.

> The operator cannot supply topology, credentials, inventory, playbooks,
> Terraform workspaces or arbitrary variables.

### 3. Follow the current workflow (allow roughly 8-12 minutes)

In the presenter AAP console, find the **new** `Demo - Datacentre Failover`
workflow. Use its start time/reference, not a hardcoded historical job ID.

Explain the stages:

1. Validate request.
2. Determine actual state.
3. Validate the target.
4. Quarantine the source.
5. Drain the source.
6. Activate the target.
7. Validate service.
8. Record evidence.

After quarantine, refresh the **source** HCP workspace. Show its real lock reason
contains the exact reference and source site. The shared/target workspaces
remain available. Do not press Unlock, force-unlock, apply, destroy or queue a
run just to demonstrate the lock; existing automated tests cover rejection.

After activation, refresh the application and show the target site and both
target node names. Wait for both the AAP workflow and Portal task to finish
successfully.

### 4. Recover the old source as standby (allow roughly 8-12 minutes)

In **Recover Datacentre**:

| Field | Input |
| --- | --- |
| Recovered datacentre | The old source site |
| Original incident/change reference | Exactly the same failover reference |
| Confirm recovered standby release | `CONFIRM` |

Submit once. Follow the new `Demo - Datacentre Recovery` graph:
request, infrastructure, application, network, Terraform API health, owned
unlock, standby return, final validation and evidence.

> Recovery verifies the site is healthy and isolated, then releases only the
> original quarantine. It does not silently move customer traffic back.

### 5. Close and hand over (one minute)

Run `bash scripts/demo-status.sh` after the workflows finish. Show that the new
site is still active, the recovered site is standby, workspaces are unlocked
and no operation marker remains. This is a complete demonstration.

For a short slot, use prior evidence below rather than promising the live
sequence will finish instantly. Never interrupt an active workflow to fit time.

## Optional real site-failure demonstration: administrator only

This intentionally causes a public outage before failover. Agree the impact
and exclusive maintenance window in advance. The helper stops **DC1 only**;
it refuses absent approval, foreign resources/account or unexpected locks.
It is not available to the restricted Portal user.

1. Require a clean **DC1-active** READY baseline. If DC2 is active, first
   perform planned failover to DC1 plus DC2 recovery using a new reset reference.
   Wait for success and recheck readiness.
2. Administrator:

   ```bash
   DEMO_LIVE_FAILURE_SMOKE=true bash scripts/aap-configure.sh simulate-dc1
   ```

3. Show HTTP 503 from the application. Do not expect the status command to say
   READY while the source is intentionally down.
4. Restricted user submits Failover to `dc2`, reason **Site failure**, new
   incident reference and `CONFIRM`.
5. Wait for success; show DC2 healthy through both nodes and exact DC1
   quarantine. Failure mode skips graceful draining of an unreachable source;
   it does not skip target validation or quarantine.
6. Administrator:

   ```bash
   DEMO_LIVE_FAILURE_SMOKE=true bash scripts/aap-configure.sh restore-dc1
   ```

7. Restricted user submits **Recover Datacentre**, `dc1`, the exact original
   reference and `CONFIRM`. Wait for complete success.
8. Run status: DC2 active, DC1 healthy standby, no locks/marker/jobs.

The repeatable equivalent is the committed opt-in browser smoke:

```bash
DEMO_LIVE_FAILURE_SMOKE=true bash tests/test-portal-browser.sh failure-smoke.spec.mjs
```

Do not run it concurrently with manual presentation steps or the independent
four-operation browser suite. It ends on DC2 and does not auto-clean failed
guards. EC2 stop/start may change ephemeral application public IPs; private
addresses and instance IDs stay stable. Inspect a refresh-only Terraform plan
before reconciling output-only changes, never apply unexpected resource actions.

## Offstage reset

Reset is optional, not part of recovery. To finish on a preferred site:

1. Submit planned Failover to the desired standby site with a **new** reference.
2. Wait for complete success.
3. Recover the old source with that same reference.
4. Verify READY; do not run Terraform apply or restart HAProxy as a shortcut.

HAProxy restart/replacement currently resets runtime state to DC1. Avoid it
during the demo; this project does not promise durable multi-region routing.

## Safe fallbacks and troubleshooting

| Symptom | Presenter action / administrator boundary |
| --- | --- |
| Status NOT READY or errors before report | Open its private diagnostics offscreen. Fix credentials/expiry/network/trust or inspect real guards. Never bypass a failure to present green status. |
| Portal reuses wrong identity | Use a separate browser profile and the fresh catalog URL, not an old OAuth authorization link. |
| Portal fails but an AAP job may exist | Inspect the current task and AAP graph before resubmitting. A client failure is not proof nothing ran. |
| Workflow running slowly | Keep the graph visible; do not cancel or launch duplicates. If needed, narrate prior verified evidence explicitly as historical. |
| Workflow failed / marker remains | Preserve reference, job IDs and state. Check every owning child is terminal, real traffic/node health, actual HCP locks and marker metadata. Do not automatically remove a marker or force-unlock. |
| Worker stream abort | AAP may have completed a side effect before losing events. Compare actual HCP lock state with the marker; do not assume the last recorded stage is authoritative about external side effects. |
| Stale marker after terminal failure | Archive exact inspected metadata and obtain explicit approval before removing only that marker. Then retry only original-reference recovery when its current preconditions hold, not the entire failure sequence blindly. |
| Source remains stopped | Administrator inspects exact instance identity/state and restores it using the fixed helper; the restricted user then runs original-reference recovery. No automatic compensation is promised. |
| SSH trust or access fails | Verify presenter `/32`, matching key and independently verified host fingerprint. Never use blind host-key acceptance or broad SSH access. |

The user-visible Portal/task and AAP evidence remain the source of truth for
an operation. Read-only status is a point-in-time baseline, not a distributed
lock or proof the next operation will succeed.

## Honest evidence and completion boundaries

- [Phase 7 CI](https://github.com/kpeacocke/aap-tfe-failover-demo/actions/runs/39537432664)
  passed.
- On the supplied lab, full new Site failure workflow **371** and original
  recovery **385** passed all stages. The complete browser smoke exited 0,
  **1 passed in 20.1 minutes**, reference `smoke-1792551077541`.
- An earlier smoke failed after an execution-worker stream abort in recovery
  **309**. It remains a failed run. Explicitly approved stale-marker
  reconciliation and original-reference recovery **322** resolved it before a
  fresh complete smoke passed. The underlying RHDP failure cause is unconfirmed.
- Show these job IDs only as **prior evidence**, never label them current.
  Follow new workflow IDs in the current lab.
- Authorized destructive teardown and safe deletion of all three emptied HCP
  workspaces subsequently passed. Recreation after that teardown remains
  **unverified**; never claim a fresh destructive round trip was tested.
- GitHub manual live dispatch requires environment secrets/reviewer setup; the
  real acceptance above executed the committed test locally.

For lifecycle instructions see [operations](operations.md); for scope and
acceptance see [IMPLEMENTATION](IMPLEMENTATION.md).
