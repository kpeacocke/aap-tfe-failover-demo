# Project: AAP Self-Service Datacentre Failover Demo

## 1. Objective

Build a complete, portable demonstration showing a restricted user initiating a controlled datacentre failover from the **Red Hat Ansible Automation Platform Self-Service Automation Portal**.

The demo must prove four things:

1. A low-privilege user can initiate a complex operational process through a simple self-service interface.
2. Ansible Automation Platform executes the failover as a proper multi-stage workflow with validation, draining, switching, rollback/error handling and evidence.
3. HCP Terraform provisions the target environment and remains the infrastructure source of truth.
4. AAP feeds operational failure state back into Terraform by locking the failed site's workspace, preventing future Terraform activity against the failed site until recovery.

This is a customer-facing demonstration.

It must be deterministic, understandable, repeatable and easy to reset.

Do not build unnecessary production complexity.

Use customer-neutral branding: the application title is "Datacentre Failover
Demo" and AWS demo tags use "Datacentre-Failover". Retain the existing
`ww-demo-*` workspace/resource identifiers and internal paths for compatibility
with the deployed Phase 1 state; they are not customer-facing branding.

---

## Platform assumptions

This project is designed primarily for the Red Hat Demo Platform (RHDP) Ansible Product Demos environment.

Assume RHDP already provides and configures:

- Red Hat Ansible Automation Platform **2.7**
- an OpenShift cluster suitable for demo add-on workloads
- AAP/OpenShift access and credentials from the RHDP catalog item
- AWS access/credentials suitable for the demo environment

Deploy the demo AWS resources in the account and region used by the supplied
RHDP lab. Verify the lab AWS demo workloads' region before provisioning;
do not infer it from the account sign-in URL or a presenter's local AWS profile.
Phase 1 accepts the verified region through `TF_VAR_aws_region` in `.env`, with
no hardcoded regional fallback. All three workspaces must use the same region.

Phase 1 may generate a dedicated SSH private key locally for HAProxy access.
Terraform registers only its public key as a demo-managed EC2 key pair in the
selected region and removes that registration on destroy. Never generate or
store private keys in Terraform state. Reuse an existing EC2 key pair only when
the presenter already holds its matching private key.

Assume the presenter provides:

- an HCP Terraform Free account and organisation

The project must **not** install or upgrade AAP or the RHDP OpenShift cluster.

The project **must deploy and configure Self-Service Automation Portal onto the existing RHDP OpenShift cluster when Portal is not already present**.

The Portal deployment must:

- use the supported AAP 2.7 OpenShift deployment mechanism;
- be idempotent;
- detect an existing Portal deployment and reconcile/reuse it where safe;
- connect Portal to the existing AAP 2.7 instance;
- avoid modifying unrelated OpenShift workloads;
- create only demo-specific Portal resources/templates required by this project.

The project bootstrap may create only demo-specific AAP content and configuration required for this demo, including:

- organisation or organisation references;
- project;
- inventory and inventory sources;
- credentials and credential references;
- execution environment reference;
- job templates;
- workflow job templates;
- RBAC/team/user mappings required by the demo;
- Self-Service Automation Portal templates/catalog resources.

Existing global AAP configuration must not be changed unless explicitly required by this document.

Reuse an existing execution environment where practical. Create a dedicated demo execution environment only if required collections are unavailable.

---


# 2. Core architectural principle

The responsibilities must remain separate.

## Terraform

Terraform owns the infrastructure topology.

Terraform must:

- create the demo environment;
- create the shared infrastructure;
- create DC1;
- create DC2;
- expose useful outputs to AAP;
- manage infrastructure lifecycle.

Terraform must **not** perform operational failover.

## Ansible Automation Platform

AAP owns runtime operations.

AAP must:

- determine current service state;
- validate failover readiness;
- drain traffic;
- activate the standby datacentre;
- validate the resulting service;
- perform rollback when safe and possible;
- quarantine the failed Terraform workspace;
- create execution evidence;
- later perform recovery.

## Self-Service Automation Portal

The portal is the restricted user's front door.

The portal user must not require:

- AWS credentials;
- Terraform credentials;
- AAP administrator access;
- direct access to Automation Controller;
- direct access to HAProxy;
- SSH access to application nodes.

The user must see only the allowed operational service and limited inputs.

---

# 3. MVP scope

Implement exactly:

- AWS
- one AAP 2.7 environment
- one HCP Terraform organisation
- three Terraform workspaces
- one shared HAProxy instance
- two application nodes in DC1
- two application nodes in DC2
- one simple demo application
- one failover workflow
- one recovery workflow
- one custom portal template
- one bootstrap mechanism
- one teardown mechanism

Do not implement Azure, GCP, VMware, Kubernetes, ServiceNow, Event-Driven Ansible, Vault, BGP, Cisco virtual routers or multiple cloud providers in v0.1.

Design cleanly enough that these can be added later.

---

# 4. User-visible scenario

The user browses to one URL representing the application.

Example:

`https://demo.example.test`

Before failover it must clearly show:

```text
Datacentre Failover Demo
ACTIVE DATACENTRE: DC1
HOST: dc1-app-01
STATUS: HEALTHY
```

Repeated requests may alternate between the two active DC1 application nodes.

After failover it must clearly show:

```text
Datacentre Failover Demo
ACTIVE DATACENTRE: DC2
HOST: dc2-app-02
STATUS: HEALTHY
```

The transition must be visually obvious.

---

# 5. AWS topology

Use a small, inexpensive environment.

Suggested architecture:

```text
Internet
   |
   v
HAProxy / Front Door
   |
   +-------------------+
   |                   |
   v                   v
DC1                   DC2
 |                     |
 +-- dc1-app-01         +-- dc2-app-01
 +-- dc1-app-02         +-- dc2-app-02
```

Use EC2 instances unless a clearly simpler AWS implementation exists.

The application should require minimal dependencies.

A simple Python HTTP service, nginx-generated page or equivalent is sufficient.

Each application node must respond with:

- datacentre;
- hostname;
- application version;
- health status.

Expose a health endpoint:

`/health`

Expected result:

```json
{
  "status": "healthy",
  "datacentre": "dc1",
  "hostname": "dc1-app-01"
}
```

---

# 6. Terraform workspace design

Use three workspaces.

## `ww-demo-shared`

Owns shared resources:

- VPC;
- internet gateway if required;
- shared security groups where appropriate;
- HAProxy/front-door host;
- common DNS resources if implemented.

## `ww-demo-dc1`

Owns:

- DC1 subnet;
- DC1 application nodes;
- DC1-specific security resources;
- outputs required by AAP.

## `ww-demo-dc2`

Owns:

- DC2 subnet;
- DC2 application nodes;
- DC2-specific security resources;
- outputs required by AAP.

Do not place both datacentres in one Terraform workspace.

The design must allow `ww-demo-dc1` to be locked while `ww-demo-dc2` remains usable.

---

# 7. Terraform outputs

Expose machine-readable outputs.

Minimum:

```hcl
output "datacentre_name" {}
output "application_private_ips" {}
output "application_instance_ids" {}
output "health_urls" {}
```

Shared workspace should expose:

```hcl
output "frontdoor_public_ip" {}
output "frontdoor_url" {}
output "haproxy_private_ip" {}
```

AAP must consume outputs rather than duplicating infrastructure values in playbooks.

---

# 8. Terraform integration

Use the supported API-based AAP/Terraform integration.

Prefer the Red Hat supported:

`hashicorp.terraform`

collection.

Do not require the Terraform CLI inside the AAP execution environment unless unavoidable.

AAP 2.7 supports API integration with Terraform Enterprise and HCP Terraform through this collection.

The runtime design must support both:

- Terraform Enterprise
- HCP Terraform

through configuration rather than code changes.

---

# 9. Terraform operational-state integration

When a datacentre is declared failed, AAP must lock that datacentre's Terraform workspace.

Example:

```text
DC1 fails
    |
    v
AAP failover workflow
    |
    +--> perform runtime failover
    |
    +--> lock ww-demo-dc1
```

Use the Terraform workspace API equivalent of:

```http
POST /api/v2/workspaces/{workspace_id}/actions/lock
```

Supply a meaningful reason.

Example:

```text
Datacentre unavailable - INC0012345 - locked by AAP failover workflow
```

Do not use a Terraform variable such as:

```text
dc1_failed=true
```

as the enforcement mechanism.

A variable may optionally record informational state, but locking is the guardrail.

The failed workspace must reject infrastructure-changing activity until recovery.

The healthy site's workspace must remain usable.

---

# 10. Portal user experience

Create a custom Self-Service Automation Portal template.

Name:

# Datacentre Failover

Description:

> Perform a controlled failover of the demo service between available datacentres.

Inputs:

```text
Service:
  Customer Orders Demo

Target datacentre:
  DC1
  DC2

Reason:
  Site failure
  Planned maintenance
  Network degradation
  Disaster recovery test

Reference:
  INC/CHG number

Confirmation:
  I understand this action will move production traffic.
```

Do not expose arbitrary inventory, host, playbook, Terraform workspace or credential selection to the portal user.

The portal must launch the AAP workflow template.

Use the current AAP portal custom-template mechanism using `rhaap:*` actions and the injected AAP token secret rather than exposing credentials in the form.

---

# 11. Access model

Create a restricted demonstration user or role.

The restricted user may:

- log into the portal;
- see the Failover service;
- launch the approved failover workflow;
- supply the approved fields;
- view the resulting status if supported.

The restricted user may not:

- edit workflow templates;
- launch arbitrary jobs;
- manage credentials;
- access AWS credentials;
- access TFE credentials;
- change inventory;
- alter Terraform workspace configuration;
- administer AAP.

Document the RBAC required.

---

# 12. AAP workflow architecture

Build job templates as reusable stages.

Do not create one monolithic playbook.

Create a workflow job template named:

`Demo - Datacentre Failover`

Conceptual graph:

```text
Validate Request
       |
       v
Determine Current State
       |
       v
Validate Target DC
       |
       +------ failure ------> Abort / Evidence
       |
       v
Quarantine Source
       |
       v
Drain Source
       |
       v
Activate Target
       |
       v
Validate Service
       |
       +------ failure ------> Recovery Decision
       |                           |
       |                    +------+------+
       |                    |             |
       |                  rollback     escalate
       |
       v
Record Final State
       |
       v
Evidence
```

---

# 13. Job template: Validate Request

Playbook:

`playbooks/failover/01_validate_request.yml`

Validate:

- service is known;
- target datacentre is valid;
- incident/change reference is supplied;
- target differs from current active DC;
- no failover marker indicates an existing operation is in progress;
- required APIs are reachable;
- required credentials work.

Do not modify infrastructure.

Return structured facts for subsequent workflow stages.

---

# 14. Job template: Determine Current State

Playbook:

`playbooks/failover/02_determine_state.yml`

Discover state from the actual environment.

Determine:

- current active HAProxy backend;
- current source DC;
- requested target DC;
- source health;
- target health;
- current connection counts if available;
- Terraform workspace IDs;
- Terraform lock status.

Do not rely solely on portal input.

Create a structured runtime object.

Example:

```yaml
failover_state:
  source_dc: dc1
  target_dc: dc2
  source_reachable: true
  target_reachable: true
  source_connections: 17
  source_workspace_locked: false
  target_workspace_locked: false
```

---

# 15. Job template: Validate Target

Playbook:

`playbooks/failover/03_validate_target.yml`

Before altering source traffic, validate target.

Checks:

- all target application nodes reachable;
- `/health` returns successful response;
- application version matches expected version;
- HAProxy can reach target nodes;
- sufficient number of healthy target nodes;
- target Terraform workspace is not locked;
- target AWS instances are running.

Output clear result.

Example:

```text
TARGET DC2 READY

Application nodes: 2/2 healthy
Application version: 1.0.0
HAProxy connectivity: PASS
AWS state: RUNNING
Terraform workspace: AVAILABLE
Synthetic transaction: PASS
```

If validation fails, the workflow must stop before modifying source traffic.

---

# 16. Job template: Quarantine Source

Playbook:

`playbooks/failover/04_quarantine_source.yml`

Lock the source Terraform workspace.

Record:

- workspace ID;
- reason;
- incident/change reference;
- timestamp.

This should happen before runtime failover once target readiness has been established.

Idempotency requirement:

If workspace is already locked by this incident/workflow, succeed without error.

If workspace is locked for an unrelated reason, fail safely and report the condition.

---

# 17. Job template: Drain Source

Playbook:

`playbooks/failover/05_drain_source.yml`

Support two modes.

## Planned mode

If source is reachable:

1. put source backend servers into HAProxy drain mode;
2. stop new sessions;
3. poll active sessions;
4. wait until zero or configurable threshold;
5. enforce configurable timeout;
6. disable source backend.

Do not terminate active connections immediately unless timeout policy permits.

## Failure mode

If source is unreachable or demonstrably failed:

- skip graceful drain;
- immediately mark source backend unavailable/disabled;
- continue to activation.

Output drain statistics.

Example:

```text
Drain started: 14:02:03
Initial connections: 23
Connections after 10 sec: 8
Connections after 20 sec: 1
Connections after 27 sec: 0
Drain complete
```

---

# 18. Job template: Activate Target

Playbook:

`playbooks/failover/06_activate_target.yml`

Enable target backend.

Ensure:

- target backend enabled;
- healthy target nodes participate;
- source backend receives no new traffic;
- HAProxy config/state remains valid.

Avoid unnecessary HAProxy process restart if runtime API/socket operations can perform the transition safely.

---

# 19. Job template: Validate Service

Playbook:

`playbooks/failover/07_validate_service.yml`

Perform post-failover checks.

Minimum:

- external/front-door endpoint responds;
- HTTP status is 200;
- response identifies expected target datacentre;
- repeated requests all land in target DC;
- both target nodes are healthy;
- source receives no new requests;
- application health endpoint succeeds;
- synthetic transaction succeeds.

Generate structured validation results.

Example:

```yaml
validation:
  external_endpoint: pass
  expected_dc: dc2
  observed_dc: dc2
  target_nodes:
    healthy: 2
    total: 2
  source_new_requests: 0
  synthetic_transaction: pass
  result: pass
```

---

# 20. Rollback behaviour

Rollback must distinguish between a planned failover and an actual failed source.

## Planned failover

If target activation fails and source remains healthy:

- re-enable source;
- remove drain;
- disable target;
- validate source;
- record rollback.

## Real source failure

If source is unavailable and target activation fails:

do not attempt an impossible rollback.

Return:

```text
FAILOVER UNSUCCESSFUL

Source DC: unavailable
Target DC: validation failed
Automatic rollback: impossible
Human escalation required
```

Keep the failed source Terraform workspace locked.

---

# 21. Evidence stage

Playbook:

`playbooks/failover/08_evidence.yml`

Produce a concise operational summary.

Example:

```text
DATACENTRE FAILOVER COMPLETE

Service:
Customer Orders Demo

Reference:
INC0012345

Requested target:
DC2

Previous active site:
DC1

New active site:
DC2

Source Terraform workspace:
LOCKED

Target Terraform workspace:
AVAILABLE

Drain:
Completed

Validation:
8/8 checks passed

Elapsed time:
00:01:34

Result:
SUCCESS
```

Also write a machine-readable JSON evidence document.

Suggested location in execution artefacts:

```text
artifacts/failover-result.json
```

Do not store secrets.

---

# 22. Recovery workflow

Create a second workflow:

`Demo - Datacentre Recovery`

Portal template:

# Recover Datacentre

Inputs:

- datacentre;
- incident/change reference;
- confirmation.

Workflow:

```text
Validate Recovery Request
        |
        v
Validate Infrastructure
        |
        v
Validate Application
        |
        v
Validate Network
        |
        v
Terraform Plan / Health Check
        |
        v
Unlock Workspace
        |
        v
Return DC to Standby
        |
        v
Final Validation
        |
        v
Evidence
```

The workspace must not be unlocked until recovery checks pass.

Recovery does not automatically make the recovered DC active.

It should return it to standby/available status.

---

# 23. Failure simulation

The demo must provide a safe way for an administrator to simulate DC1 failure.

Implement a helper command/playbook.

Examples:

- stop application services on DC1;
- stop DC1 EC2 instances;
- firewall/block HAProxy connectivity to DC1.

Prefer application/service-level failure for faster repeatability.

Create:

`playbooks/demo/simulate_dc_failure.yml`

and:

`playbooks/demo/restore_dc.yml`

These must not be visible to the restricted portal user.

---

# Self-Service Automation Portal deployment on RHDP OpenShift

The RHDP Ansible Product Demos environment provides the base AAP and OpenShift environment. This repository treats Self-Service Automation Portal as an add-on workload deployed into that existing OpenShift cluster when required.

Desired flow:

```text
RHDP catalog item
    |
    +--> AAP 2.7
    |
    +--> OpenShift
           |
           +--> Self-Service Automation Portal
                    |
                    +--> connected to existing AAP 2.7
                    |
                    +--> Demo failover/recovery templates
```

## Portal bootstrap behaviour

Before deployment:

1. verify the OpenShift API is reachable;
2. verify the supplied OpenShift credential is valid;
3. determine whether Self-Service Automation Portal is already installed;
4. if installed and healthy, reuse/reconcile it;
5. if absent, deploy it using the supported AAP 2.7 OpenShift installation path;
6. wait for Portal workloads and Route to become healthy;
7. configure Portal against the existing AAP 2.7 instance;
8. publish the demo failover and recovery templates;
9. verify a restricted test user can see only the permitted demo actions.

Do not create a separate OpenShift cluster.

Do not deploy a separate RHEL Portal appliance in the RHDP path.

## Portal deployment resources

Prefer a dedicated namespace/project for demo-owned Portal resources when supported, for example:

```text
ww-demo-portal
```

All created OpenShift objects must carry clear ownership labels or annotations where possible, for example:

```text
app.kubernetes.io/managed-by=aap-tfc-failover-demo
demo.redhat.com/project=ww-demo-failover
```

Do not alter unrelated cluster-scoped objects unless the supported Red Hat Portal installer requires them.

## Portal deployment automation

Add:

```text
bootstrap/portal/
```

with:

```text
bootstrap/portal/check.yml
bootstrap/portal/deploy.yml
bootstrap/portal/configure.yml
bootstrap/portal/verify.yml
```

Use the current supported AAP 2.7 OpenShift Portal installation method available in the RHDP environment.

Before implementation, verify the exact installation mechanism and schema against current Red Hat documentation and the actual supplied RHDP cluster.

Do not invent:

- CRDs;
- Helm values;
- OAuth configuration fields;
- Routes;
- Secrets;
- Operator APIs.

## Portal/AAP connection

Portal must connect to the existing AAP 2.7 instance.

Reuse RHDP-provided AAP endpoint and credentials where possible.

Do not expose AAP administrator credentials to Portal consumers.

The restricted customer-facing Portal user must only see the approved demo services:

- `Datacentre Failover`
- `Recover Datacentre`

## Portal verification

Bootstrap must fail clearly if Portal cannot be made healthy.

Minimum verification:

- Portal workload healthy;
- Portal Route reachable;
- Portal-to-AAP connection healthy;
- failover template visible;
- recovery template visible;
- restricted user cannot access arbitrary AAP functions through the Portal.

---

# AAP configuration-as-code pattern

Follow the configuration-as-code pattern used by the Red Hat `ansible/product-demos` repository:

`https://github.com/ansible/product-demos`

Use the `infra.aap_configuration` collection and its `dispatch` role as the primary mechanism for creating and reconciling demo-specific AAP objects.

The bootstrap pattern should be:

```yaml
- name: Install failover demo content
  hosts: localhost
  gather_facts: false

  vars:
    aap_hostname: '{{ lookup("env", "AAP_HOSTNAME") | default(omit, true) }}'
    aap_username: '{{ lookup("env", "AAP_USERNAME") | default(omit, true) }}'
    aap_password: '{{ lookup("env", "AAP_PASSWORD") | default(omit, true) }}'
    aap_token: '{{ lookup("env", "AAP_TOKEN") | default("", true) }}'
    aap_validate_certs: '{{ lookup("env", "AAP_VALIDATE_CERTS") | default(false, true) }}'

  tasks:
    - name: Validate AAP authentication inputs
      ansible.builtin.assert:
        that:
          - aap_hostname is defined
          - aap_token != "" or (aap_username is defined and aap_password is defined)

    - name: Query AAP version
      ansible.builtin.uri:
        url: "{{ aap_hostname | regex_replace('/$', '') }}/api/gateway/v1/ping/"
        method: GET
        validate_certs: "{{ aap_validate_certs }}"
        url_username: "{{ aap_username | default(omit) }}"
        url_password: "{{ aap_password | default(omit) }}"
        headers: "{{ {'Authorization': 'Bearer ' + aap_token} if aap_token else {} }}"
      register: _gateway_ping

    - name: Require AAP 2.7
      ansible.builtin.assert:
        that:
          - _gateway_ping.json.version is version("2.7", "==")

    - name: Load bootstrap variables
      ansible.builtin.include_vars:
        file: bootstrap/aap-bootstrap-vars.yml

    - name: Reconcile AAP resources
      ansible.builtin.include_role:
        name: infra.aap_configuration.dispatch
```

Support APD-style authentication through:

```text
AAP_HOSTNAME
AAP_TOKEN
```

or:

```text
AAP_HOSTNAME
AAP_USERNAME
AAP_PASSWORD
```

Optionally:

```text
AAP_VALIDATE_CERTS
```

Do not hardcode AAP credentials.

Define AAP objects declaratively in variable files and let `infra.aap_configuration.dispatch` reconcile them.

Use the established variable families where applicable:

```yaml
aap_organizations:
aap_user_accounts:
gateway_role_user_assignments:
controller_execution_environments:
controller_projects:
controller_inventories:
controller_inventory_sources:
controller_credentials:
controller_templates:
controller_workflows:
```

Verify exact names and schemas against the installed `infra.aap_configuration` version before implementation. Do not invent fields.

Mirror APD's two-stage model:

1. create/reconcile common bootstrap resources;
2. configure failover-demo-specific resources.

Suggested files:

```text
bootstrap/install-demo.yml
bootstrap/aap-bootstrap-vars.yml
bootstrap/setup-demo.yml
bootstrap/aap-demo-vars.yml
```

`install-demo.yml` establishes common resources needed to run the project.

`setup-demo.yml` loads failover-specific variables and invokes:

```yaml
- name: Reconcile failover demo resources
  ansible.builtin.include_role:
    name: infra.aap_configuration.dispatch
  vars:
    controller_dependency_check: false
```

Only disable dependency checks when an actual ordering issue requires it.

All created resources must use a unique demo prefix, for example:

```text
Demo |
```

or:

```text
ww-demo-
```

Use ownership labels/tags/descriptions where supported.

The bootstrap must be idempotent. Re-running it must reconcile resources rather than create duplicates.

For credentials that presenters may populate manually, prefer `update_secrets: false` where supported so reconciliation does not overwrite entered secrets.

After the initial external bootstrap, create an in-platform setup/reconcile job template similar in concept to APD's `Single demo setup` job.

Suggested name:

```text
Demo | Setup
```

That job should use this repository, the AAP 2.7-compatible demo execution environment, and `bootstrap/setup-demo.yml`.

The project assumes AAP 2.7 and OpenShift are already installed by RHDP. Do not install or upgrade AAP or OpenShift. Deploy/configure Self-Service Automation Portal onto the existing RHDP OpenShift cluster when it is not already present.

---

# 24. Bootstrap

The repository must be portable.

A bootstrap machine only needs:

- Python 3;
- network access to AAP;
- network access to HCP Terraform;
- network access to Git;
- required AWS/TFE/AAP credentials.

Bootstrap invocation:

```bash
./scripts/bootstrap.sh profiles/demo.yml
```

The shell script should only:

1. create a Python virtual environment;
2. install Ansible;
3. install collection requirements;
4. launch the Ansible bootstrap playbook.

Do not implement platform configuration in Bash.

---

# 25. Bootstrap responsibilities

The bootstrap must idempotently configure demo-specific content in the existing AAP 2.7 instance.

It must not install or upgrade AAP or OpenShift. It may deploy/configure Self-Service Automation Portal on the existing OpenShift cluster.

## AAP

- organisation;
- project;
- inventory;
- execution environment reference;
- credential types if needed;
- credentials;
- job templates;
- workflow templates;
- workflow graph;
- RBAC;
- restricted demo user/team configuration;
- portal-related resources where API/configuration allows.

## HCP Terraform

- identify organisation;
- create or identify project;
- create/update the three workspaces;
- set required variables;
- configure VCS relationship if appropriate;
- obtain workspace IDs;
- perform initial runs;
- expose outputs.

## AWS

Terraform performs AWS provisioning.

The bootstrap should not manually create AWS resources.

---

# 26. Bootstrap profile

Example:

```yaml
demo:
  prefix: ww-demo

aap:
  url: https://aap.example.com
  organisation: Datacentre Failover Demo
  project: Datacentre Failover Demo
  execution_environment: Default execution environment

terraform:
  url: https://app.terraform.io
  organisation: example
  project: datacentre-failover

aws:
  region: "<verified RHDP lab AWS region>"

openshift:
  api_url: https://api.example.openshiftapps.com:6443
  namespace: ww-demo-portal

portal:
  enabled: true
  deploy_if_missing: true

application:
  name: Customer Orders Demo
  version: 1.0.0

failover:
  drain_timeout_seconds: 60
  health_retries: 10
  health_delay_seconds: 3
```

Secrets must come from environment variables or secure credential mechanisms.

Do not commit tokens.

Expected environment variables may include:

```text
AAP_TOKEN
OPENSHIFT_API_URL
OPENSHIFT_TOKEN
TFE_TOKEN
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Support AWS temporary credentials when supplied.

---

# 27. Repository structure

Create:

```text
.
├── README.md
├── LICENSE
├── .gitignore
├── .editorconfig
├── .gitattributes
├── ansible.cfg
│
├── bootstrap/
│   ├── install-demo.yml
│   ├── setup-demo.yml
│   ├── teardown.yml
│   ├── aap-bootstrap-vars.yml
│   ├── aap-demo-vars.yml
│   ├── requirements.yml
│   ├── portal/
│   │   ├── check.yml
│   │   ├── deploy.yml
│   │   ├── configure.yml
│   │   └── verify.yml
│   └── roles/
│       ├── validate/
│       ├── terraform/
│       └── portal/
│
├── playbooks/
│   ├── failover/
│   │   ├── 01_validate_request.yml
│   │   ├── 02_determine_state.yml
│   │   ├── 03_validate_target.yml
│   │   ├── 04_quarantine_source.yml
│   │   ├── 05_drain_source.yml
│   │   ├── 06_activate_target.yml
│   │   ├── 07_validate_service.yml
│   │   └── 08_evidence.yml
│   │
│   ├── recovery/
│   │   ├── 01_validate_recovery.yml
│   │   ├── 02_validate_infrastructure.yml
│   │   ├── 03_validate_application.yml
│   │   ├── 04_validate_network.yml
│   │   ├── 05_validate_terraform.yml
│   │   ├── 06_unlock_workspace.yml
│   │   ├── 07_return_to_standby.yml
│   │   └── 08_evidence.yml
│   │
│   └── demo/
│       ├── simulate_dc_failure.yml
│       └── restore_dc.yml
│
├── roles/
│   ├── haproxy_state/
│   ├── application_health/
│   ├── terraform_workspace/
│   ├── synthetic_validation/
│   └── evidence/
│
├── terraform/
│   ├── shared/
│   ├── dc1/
│   ├── dc2/
│   └── modules/
│       ├── application_node/
│       └── network/
│
├── portal/
│   ├── failover-template.yaml
│   └── recovery-template.yaml
│
├── profiles/
│   └── demo.yml
│
├── scripts/
│   ├── bootstrap.sh
│   ├── teardown.sh
│   ├── simulate-failure.sh
│   └── restore.sh
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── smoke/
│
└── docs/
    ├── architecture.md
    ├── demo-runbook.md
    ├── bootstrap.md
    ├── failure-scenarios.md
    └── security.md
```

---

# 28. Ansible coding standards

All playbooks and roles must:

- be idempotent where appropriate;
- use FQCNs;
- have meaningful task names;
- avoid shell/command where a module/API is available;
- mark sensitive tasks with `no_log: true`;
- validate input;
- fail with actionable error messages;
- emit structured facts/results;
- support check mode where sensible;
- pass `ansible-lint`.

Use blocks/rescue/always where that improves operational failure handling.

Do not hide errors simply to make the demo appear successful.

---

# 29. Terraform coding standards

Terraform must:

- use current stable AWS provider constraints;
- define required Terraform version;
- use modules for repeated DC infrastructure;
- tag every AWS resource;
- include the project prefix;
- expose useful outputs;
- avoid hardcoded credentials;
- pass `terraform fmt`;
- pass `terraform validate`;
- support clean destroy.

Example tags:

```hcl
tags = {
  Project   = "AAP-TFE-Failover-Demo"
  ManagedBy = "Terraform"
  Demo      = "Datacentre-Failover"
}
```

---

# 30. Safe teardown

Teardown is mandatory.

The command:

```bash
./scripts/teardown.sh profiles/demo.yml
```

must remove only resources created by this project.

Teardown should:

1. ensure workspaces are unlockable;
2. destroy DC1;
3. destroy DC2;
4. destroy shared AWS resources;
5. remove demo-specific AAP resources where safe;
6. optionally retain TFE workspace history based on profile setting.

Never delete arbitrary existing organisations, users or credentials.

All managed objects must use a unique project prefix or tag.

---

# 31. Testing

Implement automated tests.

Minimum:

## Static

- YAML syntax
- ansible-lint
- terraform fmt
- terraform validate

## Integration

Test:

- TFE API authentication;
- AAP API authentication;
- workspace discovery;
- lock;
- unlock;
- application health response parsing;
- HAProxy state changes.

## Smoke test

After deployment:

1. verify DC1 active;
2. verify DC2 healthy standby;
3. simulate DC1 failure;
4. launch failover;
5. verify DC2 active;
6. verify DC1 workspace locked;
7. restore DC1;
8. launch recovery;
9. verify DC1 standby;
10. verify workspace unlocked.

---

# 32. GitHub Actions

Create CI workflow.

On pull request:

```text
ansible-lint
yamllint
terraform fmt -check
terraform validate
pytest
```

Do not launch real AWS/TFE infrastructure on normal PRs.

Any live integration workflow must require explicit manual dispatch and secrets.

---

# 33. Documentation

README must contain:

1. what the demo proves;
2. architecture diagram;
3. prerequisites;
4. configuration;
5. bootstrap instructions;
6. demo procedure;
7. failure simulation;
8. recovery;
9. teardown;
10. troubleshooting.

`docs/demo-runbook.md` must provide a presenter-oriented script.

Example:

```text
1. Show application currently running from DC1.
2. Show restricted user in Automation Portal.
3. Simulate failure of DC1.
4. Restricted user selects Datacentre Failover.
5. Submit incident reference.
6. Open AAP workflow visualiser.
7. Show validation stages.
8. Show DC1 TFE workspace becoming locked.
9. Refresh application URL.
10. Show application now running from DC2.
11. Attempt activity against locked DC1 workspace.
12. Show DC2 Terraform workspace remains usable.
13. Explain recovery workflow.
```

---

# 34. Security constraints

Do not:

- commit secrets;
- print tokens;
- expose private keys;
- allow portal user to submit arbitrary Ansible extra vars;
- allow portal user to select arbitrary inventory;
- allow portal user to specify arbitrary Terraform workspaces;
- execute arbitrary shell provided by the user.

All portal parameters must be validated against allow-lists.

---

# 35. UX requirements

This is a demo.

The output must be easy to understand.

Prefer messages such as:

```text
✓ DC2 application health: PASS
✓ Terraform workspace ww-demo-dc1: LOCKED
✓ Existing DC1 sessions drained: 14 → 0
✓ Traffic activated on DC2
✓ Synthetic transaction: PASS
```

Avoid dumping large Ansible fact structures during the presentation.

Keep detailed diagnostic output available but not dominant.

---

# 36. Acceptance criteria

The implementation is complete when the following scenario works end to end.

## Provision

From a clean environment:

```bash
./scripts/bootstrap.sh profiles/demo.yml
```

Results in:

- AWS environment created;
- application deployed in DC1 and DC2;
- HAProxy configured;
- DC1 active;
- DC2 standby;
- TFE workspaces configured;
- AAP templates configured;
- failover workflow configured;
- recovery workflow configured;
- self-service templates available.

## Failover

With a restricted user:

1. open the portal;
2. launch `Datacentre Failover`;
3. choose DC2;
4. provide `INC0012345`;
5. submit.

AAP must:

- detect DC1 as current source;
- validate DC2;
- lock `ww-demo-dc1`;
- drain or disable DC1 as appropriate;
- activate DC2;
- validate the external service;
- record evidence.

The application must visibly change from DC1 to DC2.

TFE must visibly show DC1 locked.

DC2 workspace must remain usable.

## Recovery

After restoring DC1:

1. launch `Recover Datacentre`;
2. select DC1;
3. provide reference;
4. submit.

AAP must:

- validate DC1;
- validate Terraform state;
- unlock DC1;
- return DC1 to standby;
- verify service remains healthy;
- produce evidence.

---

# 37. Explicit non-goals for v0.1

Do not implement:

- actual production-grade disaster recovery;
- database replication;
- persistent session replication;
- BGP convergence;
- real customer infrastructure;
- ServiceNow;
- Event-Driven Ansible;
- Vault;
- multiple AWS regions unless needed to make the demo reliable;
- Kubernetes/OpenShift application hosting;
- a bespoke web frontend;
- multiple cloud providers;
- autonomous remediation;
- AI features.

The demonstration is about the **operating model**, not recreating an enterprise datacentre.

---

# 38. Implementation order

Implement in this exact order.

## Phase 1

For manual Phase 1 provisioning, the Terraform CLI wrapper may use the HCP
Terraform API to create a missing demo workspace before initialization. New
workspaces use local execution and auto-apply disabled; existing workspace
settings are not modified. This narrowly scoped helper does not replace the
Phase 6 Ansible bootstrap or implement operational workspace locking.

Terraform infrastructure:

- shared;
- DC1;
- DC2;
- application;
- HAProxy.

Prove manual failover.

Phase 1 live validation completed on 2026-10-20 in the lab's `us-east-2`
region. All three HCP Terraform workspaces were created and applied; the four
application health endpoints passed. Front-door requests alternated between
both DC1 nodes, then both DC2 nodes after manual activation, then both DC1
nodes after switching back. The browser page displayed a healthy DC1 service.
Post-deployment plans for all three roots reported no changes. Phase 2 is the
next implementation step after Phase 1; its completed validation is recorded below.

## Phase 2

Ansible runtime roles:

- health checks;
- HAProxy drain;
- activation;
- validation.

Prove failover from CLI.

Phase 2 runtime roles and the CLI entrypoint are implemented. At Phase 2
completion the entrypoint read the existing Terraform roots' JSON outputs;
Phase 3 replaces that discovery with API output retrieval and adds workspace
lock/unlock. AAP and Portal are not configured by Phase 2.

Live CLI validation on 2026-10-20 proved DC1-to-DC2 failover and DC2-to-DC1
switchback, with both nodes at the active site serving front-door requests.
The reusable roles check node identity/version, drain source sessions, activate
the target through the existing HAProxy socket, and validate external traffic,
the application page and source isolation. Operations use an exclusive
HAProxy-side marker; failures return nonzero even after a successful rollback.

Local tests use real HAProxy and four application processes in a disposable
container, without lab credentials. They cover invalid requests, an existing
operation marker, target readiness failure, refusal to skip draining a
responsive source, planned switching in both directions, target failure with
validated rollback, unavailable-source escalation, successful failure-mode
activation, and a nonzero-session drain timeout with rollback. The timeout
case uses TCP mode to hold an idle session deterministically; the remaining
scenarios use HTTP mode like the deployed front door.

Ansible/YAML/shell lint and the existing application and Phase 1 helper
regressions pass. Phase 3 completion and workspace quarantine evidence are
recorded below. Failure simulation on the live AWS nodes, AAP objects, and
Portal configuration remain later-phase work.

## Phase 3

TFE integration:

- discover workspaces;
- lock;
- unlock;
- retrieve outputs.

Phase 3 is implemented and validated. The `terraform_workspace` role uses the
verified `hashicorp.terraform` 2.2.1 collection interfaces, pinned from the
official Git release, and `pytfe` 1.4.1. CLI wrappers discover the exact existing
shared/DC1/DC2 workspaces and retrieve current output values without invoking
Terraform CLI, accessing AWS or downloading full state files. Only allowlisted
non-sensitive infrastructure outputs enter a private temporary inventory.
API credentials stay on the Ansible controller.

Runtime failover checks target health and current workspace availability, then
quarantines the source before draining or activating servers. Lock reasons are
stable per incident/change and datacentre; verification results include UTC
timestamps. Repeated same-incident locks are idempotent. Unrelated or run-owned
locks, API conflicts and missing permissions fail safely. The shared workspace
is never mutated, and no force-unlock is used. Runtime errors and successful
runtime rollback both retain quarantine.

The explicit administrative normal-unlock helper requires the original
reference, a healthy recovered site in maintenance and a validated healthy
service at the other site. It neither repairs infrastructure nor switches
traffic, and is not the full Phase 4 recovery workflow. Runtime and workspace
CLI operations share the HAProxy-side exclusive marker. External Terraform
administrators must coordinate: the normal unlock API has no atomic
lock-reason comparison, and the marker cannot serialize outside clients.

HCP Terraform Free is the live acceptance target. Operational API access also
accepts an HTTPS Terraform Enterprise base URL/token and optional trusted CA;
TLS verification is never disabled. Enterprise compatibility is verified with
a local TLS API fixture, not a live Enterprise deployment. Provisioning remains
HCP-only.

Live validation on 2026-10-20 proved:

- API discovery and non-sensitive output retrieval for all three workspaces;
- source quarantine before DC1-to-DC2 traffic activation;
- a locking Terraform plan against quarantined DC1 was rejected;
- a failover to locked DC1 was rejected without changing traffic;
- healthy-standby normal release with the original reference;
- DC2-to-DC1 switchback with DC2 quarantined, followed by guarded DC2 release;
- final healthy DC1 service, both DC1 nodes serving front-door requests and all
  three workspaces available;
- final locking Terraform plans for shared/DC1/DC2 all reported no changes.

Local validation uses the real collection/SDK against a TLS JSON:API fixture
(10 tests) and real HAProxy/four application processes in a disposable container.
It covers output/authentication failures, permissions/conflicts, incident lock
ownership, idempotent normal lock/unlock, locked-target refusal, active-site and
unhealthy-standby release refusal, and retained quarantine after drain-timeout
rollback. Application/Phase 1 helper regressions, Ansible/YAML/shell lint,
Terraform formatting and validation pass. CI runs both credential-free fixtures.
The Snyk code scan tool is unavailable in this environment; no successful Snyk
scan is claimed.

Phase 4 (AAP objects and workflow graph) is next. No AAP or Portal configuration
has been implemented or changed in Phase 3.

## Phase 4

AAP objects:

- project;
- credentials;
- inventory;
- job templates;
- workflow graph.

## Phase 5

Portal on RHDP OpenShift:

- detect any existing Self-Service Automation Portal deployment;
- deploy Portal to the supplied RHDP OpenShift cluster if missing;
- configure Portal against the existing AAP 2.7 instance;
- create restricted custom failover template;
- create recovery template;
- configure RBAC;
- verify restricted-user visibility and execution.

Current AAP 2.7 portal custom templates are Git-backed YAML definitions that can launch AAP automation through `rhaap:*` actions. Use the current injected AAP token secret mechanism rather than asking the user to provide a token.

## Phase 6

Bootstrap and teardown.

## Phase 7

Automated testing and CI.

## Phase 8

Demo polish.

Do not start the next phase until the previous phase works.

---

# 39. Development rule

When implementation choices are unclear:

1. prefer the simplest supported Red Hat/HashiCorp mechanism;
2. prefer API integrations to CLI scraping;
3. prefer declarative and idempotent implementation;
4. prefer clear demonstration behaviour over theoretical completeness;
5. document assumptions;
6. do not silently invent APIs or Ansible module parameters;
7. verify collection/module interfaces against current documentation before implementation.

---

# 40. First task

Start by creating:

- repository skeleton;
- `README.md`;
- architecture documentation;
- Terraform shared/DC modules;
- demo application;
- HAProxy configuration;
- CI skeleton.

Then implement Phase 1 completely.

Do not attempt the entire project in one giant commit.

Create small logical commits and keep the repository runnable as functionality is added.
