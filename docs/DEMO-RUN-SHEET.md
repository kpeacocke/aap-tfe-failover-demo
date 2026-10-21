# Presenter run sheet: controlled datacentre failover

## Status and scope

Prepared for the current RHDP lab on 21 October 2026.
Read-only checks before writing this sheet confirmed:

- Application healthy on **DC1**.
- `ww-demo-shared`, `ww-demo-dc1` and `ww-demo-dc2` all **unlocked**.
- AAP workflow templates: **156 failover**, **155 recovery**.

This sheet does not launch jobs or change the environment. Implementation is
paused. Lab URLs and identifiers are environment-specific.

## Open these tabs before presenting

| Tab | Link | Purpose |
| --- | --- | --- |
| Application | [Datacentre Failover Demo](http://3.151.226.116/) | Visible active site, hostname and health |
| Portal | [Restricted catalog](https://ww-demo-portal.apps.cluster-55cft.dyn.redhatworkshops.io/self-service/catalog) | Operator front door |
| Failover form | [Datacentre Failover](https://ww-demo-portal.apps.cluster-55cft.dyn.redhatworkshops.io/self-service/create/templates/default/ww-demo-failover-custom) | Initiate DC1 → DC2 |
| Recovery form | [Recover Datacentre](https://ww-demo-portal.apps.cluster-55cft.dyn.redhatworkshops.io/self-service/create/templates/default/ww-demo-recovery-custom) | Release recovered standby |
| AAP | [Automation Platform console](https://aap-aap.apps.cluster-55cft.dyn.redhatworkshops.io/) | Presenter shows real workflow graph/jobs |
| Terraform DC1 | [ww-demo-dc1](https://app.terraform.io/app/kpeacocke/workspaces/ww-demo-dc1) | Show source quarantine, then release |
| Terraform DC2 | [ww-demo-dc2](https://app.terraform.io/app/kpeacocke/workspaces/ww-demo-dc2) | Target infrastructure/workspace |
| Terraform shared | [ww-demo-shared](https://app.terraform.io/app/kpeacocke/workspaces/ww-demo-shared) | Shared infrastructure ownership |
| Source | [Public repository](https://github.com/kpeacocke/aap-tfe-failover-demo) | Code, declarative configuration and guardrails |
| CI | [Validated Phase 6 build](https://github.com/kpeacocke/aap-tfe-failover-demo/actions/runs/39507668527) | Existing automated validation passed |

Use the fresh Portal link above, **not an old OAuth authorization URL**.

### Login separation

- Portal user: **`ww-demo-operator`**.
- Its password is in the private local file
  [`.local/aap-operator-password`](../.local/aap-operator-password).
  Read it privately before screen sharing. Do not show the file or paste it
  into presentation notes.
- Use your existing presenter/admin credentials for AAP inspection and HCP.
- Use a **separate browser profile or private window** for the restricted Portal
  user. Otherwise AAP OAuth may reuse the presenter's administrator session.
- Log in before the audience arrives. If prompted, authorize the demo OAuth
  application. Confirm the operator sees exactly the two demo templates.

## Opening message: 60–90 seconds

> “Terraform owns the infrastructure lifecycle. Ansible Automation Platform
> owns the operational change. The Self-Service Automation Portal gives a
> restricted user a safe front door—without AWS, Terraform or SSH credentials.”
>
> “A failed or withdrawn site is also quarantined in Terraform, so
> infrastructure changes cannot accidentally proceed while it is under
> operational recovery.”

Be precise: the demo uses two logical datacentre sites/subnets in AWS, **not
two physical datacentres or two AWS regions**. AAP 2.7 and OpenShift are supplied
by RHDP; this project deploys the Portal add-on onto that existing cluster.

## Main live sequence: allow about 18–20 minutes

The last complete four-operation acceptance took about 29 minutes.
For a short presentation, show **one failover plus one recovery**.
Each workflow can take roughly 6–9 minutes; do not promise an instant switch.

### 1. Establish the starting state — 1 minute

1. Open the application: **HEALTHY**, **DC1**.
2. Refresh a few times: the hostname may alternate between `dc1-app-01` and
   `dc1-app-02`.
3. Show DC1's HCP workspace is currently unlocked.

Say:

> “Both sites are provisioned already. DC1 is serving traffic, and DC2 is the
> healthy standby. This is an operational change—not a Terraform redeployment.”

### 2. Submit a restricted failover — 1 minute

Open the **Datacentre Failover** form as `ww-demo-operator`.

| Field | Value |
| --- | --- |
| Target datacentre | `dc2` |
| Reason | `Planned maintenance` |
| Incident/change reference | `present-20261021-01` |
| Confirm traffic move | `CONFIRM` |

Use that reference only if it is new; otherwise increment the suffix.
Write down the actual reference, because recovery must match it exactly.
Click **Next**, review, then **Create once**.
Keep the resulting Portal task page open.

Say:

> “The operator selects the approved target and supplies a change reference.
> They cannot supply credentials, topology, playbooks or arbitrary variables.”

### 3. Follow the real AAP graph — about 6–9 minutes

In the presenter AAP console, open **Automation Execution → Jobs** and find the
new **Demo - Datacentre Failover** workflow. Follow the newly created workflow,
not an old successful run. The templates are:

- **Demo - Datacentre Failover**, template ID **156**.
- **Demo - Datacentre Recovery**, template ID **155**.

Explain the visible progression:

1. Validate request.
2. Determine actual current state.
3. Validate target DC.
4. Quarantine the source workspace.
5. Drain source traffic.
6. Activate the target.
7. Validate the service.
8. Record evidence.

Say:

> “These are separate AAP jobs in a staged workflow, not one opaque script.
> Each stage validates its preconditions and passes durable state to the next.”

While it runs:

- Refresh **DC1's Terraform workspace** after the quarantine stage.
- Show that it becomes locked with a demo-managed incident reason containing
  your reference and `dc1`.
- Do **not** press Unlock or queue a Terraform run.
- Refresh the application after activation. Expect **HEALTHY**, **DC2** and
  `dc2-app-01` / `dc2-app-02`.
- Wait for both the AAP workflow and Portal task to report success before
  submitting recovery.

Say:

> “Infrastructure still exists and remains managed by Terraform. The workspace
> lock is a real operational quarantine, not a decorative status label.”

### 4. Recover DC1 as standby — about 6–9 minutes

Open **Recover Datacentre** in Portal.

| Field | Value |
| --- | --- |
| Recovered datacentre | `dc1` |
| Original incident/change reference | `present-20261021-01` — your exact failover reference |
| Confirm recovered standby release | `CONFIRM` |

Click **Next**, review, then **Create once**.
Follow the new **Demo - Datacentre Recovery** workflow in AAP.

Explain:

> “Recovery validates infrastructure, application and networking, checks
> Terraform API health, then releases only the original incident's quarantine.
> It returns the site to standby—it does not silently move customer traffic.”

At completion:

- Portal and AAP report success.
- DC1's Terraform workspace is unlocked.
- The application is still **HEALTHY on DC2**.

### 5. Close — 30 seconds

> “The user needed only an approved form. AAP performed the controlled
> operation and retained evidence. Terraform stayed the infrastructure source
> of truth, including a real quarantine-and-recovery handshake.”

**The main presentation finishes on DC2, with DC1 recovered as standby.**
That is intentional and healthy, not an incomplete recovery.

## If the presentation slot is shorter than 15 minutes

Do not attempt the full round trip. Show the baseline, submit failover, explain
the graph and quarantine, and show the new active site if it completes in time.
Leave any running workflow alone. Complete original-reference standby recovery
after it finishes, offstage.

Alternatively use the retained successful evidence below, explicitly described
as a prior validated run rather than as the current live execution.

## Optional offstage switchback/reset

Only after the main recovery has succeeded:

1. Submit **Failover**, target `dc1`, reason `Planned maintenance`,
   reference **`present-20261021-01-back`**, confirmation `CONFIRM`.
2. Wait for complete success; application should become healthy DC1 and DC2
   should be quarantined.
3. Submit **Recovery**, recovered DC `dc2`, original reference
   **`present-20261021-01-back`**, confirmation `CONFIRM`.
4. Wait for complete success; DC1 remains active and both workspaces are
   unlocked.

Allow another roughly 12–18 minutes. Never submit all operations at once.
Do not use bootstrap or teardown as a presentation reset.

## Safe fallback and known-good evidence

The last full acceptance passed all four browser tests, including the complete
traffic-changing round trip. These are **historical** successful executions:

| Operation | Workflow | Authenticated evidence link |
| --- | ---: | --- |
| Failover to DC2 | 167 | [AAP workflow metadata](https://aap-aap.apps.cluster-55cft.dyn.redhatworkshops.io/api/controller/v2/workflow_jobs/167/) |
| Recover DC1 standby | 181 | [AAP workflow metadata](https://aap-aap.apps.cluster-55cft.dyn.redhatworkshops.io/api/controller/v2/workflow_jobs/181/) |
| Switch back to DC1 | 196 | [AAP workflow metadata](https://aap-aap.apps.cluster-55cft.dyn.redhatworkshops.io/api/controller/v2/workflow_jobs/196/) |
| Recover DC2 standby | 211 | [AAP workflow metadata](https://aap-aap.apps.cluster-55cft.dyn.redhatworkshops.io/api/controller/v2/workflow_jobs/211/) |

These links are API JSON, not graphical console deep links. In the AAP console,
find the corresponding workflow job ID to show its graph.

If a workflow fails or stalls:

1. Do not submit a duplicate request or a different incident reference.
2. Do not cancel a running job just to fit the presentation slot.
3. Do not manually clear a marker, unlock a workspace or force switch traffic.
4. Show the actual application state and retained job evidence.
5. Say: “The operation has stopped rather than bypassing its guardrails.
   We retain the quarantine for administrator investigation.”
6. Continue with the historical successful graph/CI evidence if useful.

A prior RHDP execution-worker interruption was safely recovered with explicit
administrator approval before a fresh complete acceptance passed. Avoid
claiming that every platform failure automatically rolls back: rollback is
health-gated, and some failures intentionally retain guards for inspection.

## Claims to keep accurate

- This demonstration performs a **controlled traffic move**; selecting “Site
  failure” is not proof of physically killing a datacentre.
- Restricted users do not need AWS/Terraform/SSH credentials; presenter/admin
  visibility is separate.
- Portal uses the signed-in user's OAuth identity to launch fixed jobs. A
  dedicated execute-only service identity bridges those jobs to the staged AAP
  workflows. No administrator credential is attached to consumer jobs.
- No claim of zero dropped connections or measured zero downtime has been
  established. Show actual health and stage evidence instead.
- Bootstrap/reconciliation and teardown preflight passed. Actual destructive
  teardown/recreation was deliberately not executed.
- Never open `.env`, private keys, credential inputs, Secrets or the password
  file while sharing your screen.
