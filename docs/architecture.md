# Phase 1 architecture

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
future operational automation can quarantine one site without affecting the
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
Phase 1 implementation neither installs nor changes them. Self-Service
Automation Portal is an add-on: a later phase will detect and reuse an existing
Portal deployment, or deploy Portal onto the supplied OpenShift cluster if
missing. No AAP or Portal configuration is part of Phase 1.

## Phase 1 limitations

- HAProxy state changes are manual and are reset to DC1 if the HAProxy instance
  is replaced.
- No AAP workflow, Portal template, HCP Terraform API automation, workspace
  locking, recovery workflow, bootstrap, or teardown automation is implemented
  in this phase.
- The switch command requires both target application nodes to pass `/health`.
