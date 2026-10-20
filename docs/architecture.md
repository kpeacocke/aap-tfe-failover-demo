# Demo architecture (Phases 1-3)

## Responsibility boundaries

Terraform owns the AWS network and compute lifecycle. It creates three
independently managed HCP Terraform workspaces:

| Workspace | Owns |
| --- | --- |
| `ww-demo-shared` | VPC, internet gateway, HAProxy subnet/host, Elastic IP, shared security group, demo public-key registration |
| `ww-demo-dc1` | DC1 subnet, route table, application security group, two DC1 instances |
| `ww-demo-dc2` | DC2 subnet, route table, application security group, two DC2 instances |

The DC roots read the shared workspace's VPC, gateway, and subnet CIDR outputs
with `terraform_remote_state`. HCP Terraform state sharing must be enabled for
the two consumer workspaces. Each DC remains a separate state boundary so that
operational automation can quarantine one site without affecting the
other.

The dedicated SSH private key stays in the presenter's Git-ignored local
directory and survives Terraform destroy. Terraform registers only the public
key as a prefixed, tagged EC2 key pair and removes that registration on destroy.
Recreation reuses the same local key; it does not depend on an existing lab
private key or modify personal SSH credentials.

## Network and traffic

```text
Internet
   |
   v
HAProxy :80 (public Elastic IP; SSH limited to administrator CIDR)
   |
   +-- DC1 subnet: dc1-app-01, dc1-app-02 (TCP/8080)
   |
   +-- DC2 subnet: dc2-app-01, dc2-app-02 (TCP/8080)
```

All resources use the verified RHDP lab AWS region, explicitly supplied through
`TF_VAR_aws_region` in `.env`; no region is assumed. The app instances receive
public IPs for operating-system package installation, but their security group
accepts application traffic only from the HAProxy security group and has no
inbound SSH rule. The subnet routing is public; the security-group boundary is
the control that prevents direct Internet access to the app service. DC1 and
DC2 are placed in separate availability zones within the region; this models
site separation for the demo, not a multi-region disaster-recovery design.

HAProxy uses a Unix runtime socket. Both DC1 servers start enabled and both DC2
servers start disabled. Its health checks call `/health`. An operator uses the
restricted SSH entry point; a fixed remote script verifies both target health
endpoints before making the target ready and putting the other site's servers
in maintenance state. The switch is manual in Phase 1 and does not write
Terraform state.

## Application

Each EC2 instance runs the standard-library Python HTTP server as a dedicated,
unprivileged system user under systemd. `/health` returns JSON containing
`status`, `datacentre`, `hostname`, and `version`. `/` renders the same
identity in a presenter-friendly page.

## RHDP boundary

The RHDP catalog environment supplies AAP 2.7 and the OpenShift cluster. This
implementation neither installs nor changes them. Self-Service
Automation Portal is an add-on: a later phase will detect and reuse an existing
Portal deployment, or deploy Portal onto the supplied OpenShift cluster if
missing. No AAP or Portal configuration is part of the completed phases.

## API-integrated runtime failover

The Phase 2 CLI uses reusable Ansible roles to discover actual HAProxy state,
validate node identity/version, drain sessions, activate a target and validate
external traffic. Failed transitions attempt rollback only to a healthy source;
failures remain failures even when rollback succeeds.

Phase 3 uses `hashicorp.terraform` 2.2.1 and its Python SDK to discover the exact
three workspaces and retrieve allowlisted non-sensitive outputs. The controller
generates a private temporary inventory; API credentials never enter it or SSH
tasks. Terraform CLI and AWS credentials are not needed for operational
failover. TLS-verified API reads verify workspace identity and authoritative
lock metadata.

After target readiness and a fresh unlocked-target check, the controller
quarantines the source workspace with a stable incident/change reason before
traffic changes. Existing locks are accepted only for the same demo incident;
unrelated or run-owned locks are never overwritten or released. The shared
workspace is never locked. Rollback does not clear quarantine.

An explicit administrative release uses normal unlock only, with the original
reference. It requires both recovered nodes healthy, the recovered site in
maintenance, and a validated active service at the other site. It does not
switch traffic or implement the later recovery workflow. A shared HAProxy-side
marker serializes runtime and administrative CLI operations, but cannot
serialize outside Terraform administrators; concurrent manual lock changes or
infrastructure mutations must be avoided.

## Current limitations

- HAProxy runtime state resets to DC1 on restart or replacement.
- No AAP workflow, Portal template, full recovery workflow, Ansible bootstrap,
  or automated teardown is implemented yet.
- The Phase 1 manual switch helper bypasses Phase 3 quarantine; use the Ansible
  CLI for integrated operations and do not run both concurrently.
- Enterprise endpoint compatibility is fixture-tested; live acceptance uses
  HCP Terraform Free.
