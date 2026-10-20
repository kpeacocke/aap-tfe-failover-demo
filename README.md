# AAP Self-Service Datacentre Failover Demo

This repository demonstrates a small AWS application spanning two datacentres,
fronted by HAProxy. The implementation is being delivered in phases; the
current phase provisions the infrastructure and demonstrates a manual traffic
switch.

## Phase 1 architecture

- `ww-demo-shared` owns the VPC, internet gateway, HAProxy host, and public
  address.
- `ww-demo-dc1` and `ww-demo-dc2` each own one application subnet and two
  application instances.
- HAProxy starts with DC1 enabled and DC2 disabled. Its health checks use each
  application's `/health` endpoint.
- The demo application has no third-party runtime dependencies. Its home page
  identifies the active datacentre and serving node.
- HCP Terraform stores state in three distinct workspaces. DC workspaces read
  only the shared workspace's network outputs.

See [docs/architecture.md](docs/architecture.md) for the network and
workspace details.

## Prerequisites

- Terraform CLI 1.6 or later.
- An HCP Terraform account at `app.terraform.io`, with three workspaces:
  `ww-demo-shared`, `ww-demo-dc1`, and `ww-demo-dc2`.
- An HCP Terraform token in `.env` and shared state output access granted to
  both DC workspaces.
- AWS credentials available to the local Terraform process, for example through
  `AWS_PROFILE` or the standard AWS environment variables.
- An existing EC2 key pair in `ap-southeast-2` and the presenter's public IPv4
  CIDR for restricted SSH access to HAProxy.

This phase does not configure AAP or Self-Service Automation Portal. In the
RHDP environment, AAP 2.7 and OpenShift are supplied; Portal will be deployed
onto that existing OpenShift cluster in a later phase if it is absent.

## Configure and provision

Copy `.env.example` to `.env` and fill in:

| Setting | Required value |
| --- | --- |
| `HCP_TERRAFORM_ORGANIZATION` | Your HCP Terraform organization name. |
| `TF_TOKEN_app_terraform_io` | HCP Terraform user/team API token with access to the three workspaces and shared state. |
| `AWS_PROFILE` | A local AWS CLI profile with permission to create the demo resources in `ap-southeast-2`. Alternatively, remove this line and provide `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_SESSION_TOKEN`. |
| `TF_VAR_ssh_key_pair_name` | Name of an existing EC2 key pair in `ap-southeast-2`. |
| `SSH_PRIVATE_KEY_PATH` | Path to the matching local private key file. |
| `TF_VAR_admin_cidr` | Your public IPv4 address with `/32`, restricting SSH access to HAProxy. |
| `TF_VAR_terraform_organization` | Same value as `HCP_TERRAFORM_ORGANIZATION`; used by the DC workspaces to read shared outputs. |
| `HAPROXY_PUBLIC_IP` | Leave empty until provisioning; then set it to the shared workspace's `frontdoor_public_ip` output. |

Use a valid local AWS profile or temporary AWS credentials; do not put AWS root
credentials in `.env`. Quote values that contain spaces. The file is
shell-compatible local configuration, is ignored by Git, and should be kept
private (`chmod 600 .env`). Do not commit it or paste tokens into chat.

The Terraform wrapper loads `.env`, generates the ignored backend configuration
for the selected root, and passes the HCP token through the standard Terraform
environment variable. Run provisioning in dependency order:

```bash
cp .env.example .env
chmod 600 .env
# Edit .env before continuing.

./scripts/terraform.sh shared init
./scripts/terraform.sh shared apply

./scripts/terraform.sh dc1 init
./scripts/terraform.sh dc1 apply

./scripts/terraform.sh dc2 init
./scripts/terraform.sh dc2 apply
```

The DC workspaces need permission to read the shared workspace's state outputs.
Enable HCP Terraform remote state sharing from `ww-demo-shared` to
`ww-demo-dc1` and `ww-demo-dc2` before applying them. Keep the workspaces in
local execution mode for this phase, or configure equivalent AWS credentials
in each remote-execution workspace.

The shared workspace outputs `frontdoor_url`, `frontdoor_public_ip`, and
`haproxy_private_ip`. After both DC applies complete, open `frontdoor_url`.
It should display DC1 as active. The DC workspaces output private health URLs
and instance IDs for inspection.

Terraform creates the HCP backend configuration in each root's ignored
`backend.hcl`; you do not need to edit those files manually. The HCP Terraform
organization and all three workspace names must already exist.

## Prove manual failover

After setting `HAPROXY_PUBLIC_IP` in `.env` to the shared workspace output, the
manual operator command checks both target `/health` endpoints from HAProxy,
then switches its runtime server state. It does not change Terraform
configuration or state. The key path and HAProxy address are read from `.env`:

```bash
./scripts/manual-failover.sh dc2
```

You can also pass the address and key explicitly:
`./scripts/manual-failover.sh dc2 203.0.113.10 ~/.ssh/demo-key.pem`.

Refresh the front-door URL and confirm the page reports DC2. Switch back with
`dc1`. The HAProxy security group restricts SSH to `admin_cidr`; application
port 8080 is reachable only from HAProxy's security group. The remote switch
command accepts only `dc1` or `dc2` and leaves the current backend untouched if
the target health checks fail.

## Validate locally

```bash
terraform fmt -check -recursive terraform
for root in terraform/shared terraform/dc1 terraform/dc2; do
  terraform -chdir="$root" init -backend=false
  terraform -chdir="$root" validate
done
python3 -m unittest discover -s tests -v
shellcheck scripts/load-env.sh scripts/terraform.sh scripts/manual-failover.sh terraform/shared/set-active-datacentre.sh
```

The Terraform validation initializes providers but does not contact AWS or
create infrastructure. Applying the configuration creates billable AWS
resources. Destroy in reverse dependency order (`dc2`, `dc1`, then `shared`)
when finished. The wrapper loads `.env` for each command:

```bash
./scripts/terraform.sh dc2 destroy
./scripts/terraform.sh dc1 destroy
./scripts/terraform.sh shared destroy
```
