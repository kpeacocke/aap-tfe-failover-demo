# Set up your own evaluation lab

[Home](../README.md) | [Operations](operations.md) | [Validation](validation.md)

This guide deploys demo-owned content onto **existing RHDP AAP 2.7 and
OpenShift**, plus a small AWS application. It does not install either platform.
The original demonstration lab has been torn down; do not reuse its endpoints,
account IDs, workspace IDs or browser authorization links.

## 1. Confirm prerequisites and ownership

Before spending money or changing a lab, record:

- Your RHDP lab owner, expiry time and authorized maintenance window.
- The existing AAP 2.7 HTTPS base URL and administrator authentication.
- The existing OpenShift API URL, short-lived token, AAP namespace, ingress,
  default storage and capacity for Portal and an execution-image build.
- Your own AWS **12-digit account ID and verified workload region**, with
  capacity for five EC2 instances, EBS volumes, public IPv4 and a VPC.
- A dedicated HCP Terraform organization and token; the organization must
  already exist. Use HCP Terraform Free at `app.terraform.io`.
- Permission/entitlement to pull the pinned base image and Red Hat Portal
  components and, if applicable, consent to reuse cluster registry credentials.
- Who will hold administrator credentials, restricted operator credentials,
  local SSH keys, and retained storage after teardown.

Check the pinned Portal interfaces in [Portal variables](../bootstrap/portal/vars.yml)
and [preflight](../bootstrap/portal/check.yml). The current implementation
checks OpenShift 4.16-4.20 and uses chart 2.2.11 with AAP 2.7. Verify current
vendor compatibility/entitlements for your lab; do not upgrade RHDP platforms
to work around a failed check. An unrelated existing Portal is refused, not
silently adopted or overwritten.

### Local tools

| Tool | Requirement |
| --- | --- |
| Python | 3.12-3.14 for lifecycle; set `BOOTSTRAP_PYTHON` if needed |
| Terraform CLI | 1.9.x for guarded lifecycle; CI pins 1.9.8 |
| Docker | Installed **and daemon running**; Docker Desktop on macOS is suitable |
| Git, curl, jq | Available on `PATH` |
| OpenSSH tools | `ssh`, `ssh-keygen` and a writable trusted `known_hosts` file |
| OpenSSL | Used to generate a private reusable operator password |
| Node.js / npm | Optional for browser tests; CI uses Node 24 and locked packages |

Check tools before deployment:

```bash
python3 --version
terraform version
docker info
git --version
curl --version
jq --version
ssh -V
openssl version
```

The lifecycle wrapper creates ignored `.local/lifecycle-venv` and isolated
collections from the pinned manifests. Do not use a Python 3.15 virtual
environment for this path. Internet access is needed for packages, Git,
Terraform providers, image pulls, chart download and AWS package installation.

## 2. Prepare the private environment

From the repository root:

```bash
cp .env.example .env
chmod 600 .env
```

Edit the file locally. It is **trusted shell-compatible configuration**, not
an untrusted dotenv upload: wrappers source it and export its assignments.
Quote secrets and values containing shell-special characters. Never source a
file supplied by an untrusted party. Never print or attach this file to an issue.

Use [.env.example](../.env.example) as the complete field reference:

| Group | Values and checks |
| --- | --- |
| HCP | `HCP_TERRAFORM_ORGANIZATION`, `TF_TOKEN_app_terraform_io`; set `TF_VAR_terraform_organization` to the same organization |
| AWS identity | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, optional `AWS_SESSION_TOKEN`; pin `TF_VAR_aws_account_id` |
| AWS region | `TF_VAR_aws_region`; obtain it from the lab's AWS workload provisioning details, not its sign-in URL |
| Presenter SSH | `TF_VAR_admin_cidr`, your terminal's public IPv4 `/32`; `SSH_PRIVATE_KEY_PATH`, `SSH_PUBLIC_KEY_PATH` |
| Existing AAP | `AAP_HOSTNAME` without UI paths, plus `AAP_TOKEN` or `AAP_USERNAME` / `AAP_PASSWORD` |
| Existing OpenShift | `OPENSHIFT_API_URL`, `OPENSHIFT_TOKEN`, `AAP_OPENSHIFT_NAMESPACE` if not `aap` |
| TLS | Leave certificate verification enabled; provide `OPENSHIFT_CA_CERT` for a private cluster CA |
| Revisions | `DEMO_SCM_REVISION`; use published code as described below |
| Portal registry | `DEMO_PORTAL_REUSE_CLUSTER_REGISTRY_AUTH=true` **only with explicit approval** |

AWS console URLs/usernames/passwords are browser credentials, not Terraform
inputs. Do not store them here. Never use AWS root credentials.

For the **complete AAP path**, supply AWS access keys and a session token when
required. Terraform locally supports profiles/SSO, but the container wrapper
does not forward your AWS profile files or obtain SSO credentials for AAP;
the AAP health-read credential is populated from the explicit environment
values. Its label does not reduce the IAM permissions of the supplied keys.
Use lab-scoped credentials and deliberate expiry/rotation.

The HCP token needs organization/workspace/project access for bootstrap,
workspace creation and state-sharing configuration, state/output access for
local Terraform, and DC lock/normal-unlock permissions for operations.
Safe-delete additionally needs workspace deletion permission. Use the same
locking identity for normal unlock. Do not substitute force-unlock permissions
for correct ownership.

The cluster token must allow the inspections and project-scoped resource
creation in the supplied playbooks. Registry reuse reads the cluster pull
secret and copies **only** its `registry.redhat.io` entry into the demo
namespace. It is off by default. If reuse is prohibited, stop and agree a
supported credential configuration; do not bypass the guard.

### Source repository and revisions

The delivered configuration currently fetches this public upstream repository.
It is not automatically fork-aware:

| Surface | Configuration |
| --- | --- |
| AAP project | [aap-bootstrap-vars.yml](../bootstrap/aap-bootstrap-vars.yml) |
| OpenShift execution-image build | [build-ee.yml](../bootstrap/build-ee.yml) |
| Portal catalog | [portal/vars.yml](../bootstrap/portal/vars.yml) |
| Safe cleanup source allowlist | [inspect-objects.yml](../bootstrap/lifecycle/inspect-objects.yml) |
| Matching contract expectations | [tests/](../tests/) |

For an unchanged evaluation, use a published upstream commit. `build-ee`
uses the local checked-out commit SHA, which must be reachable in the configured
remote. A locally modified/unpublished image source is not deployed by the
OpenShift Git build.

`DEMO_SCM_REVISION` defaults to `main`; for a repeatable evaluation, set it to
the published commit you checked out. Portal catalog URLs still follow the
configured `main` base. A stable release/fork therefore requires coordinated
source/catalog/guard/test changes, not just `git remote set-url`. Do not claim
fully version-pinned distribution until those surfaces are aligned and tested.
Do not rename the `ww-demo` workspaces or namespaces in isolation.

## 3. Bootstrap in dependency order

Review [profiles/demo.yml](../profiles/demo.yml). It contains only non-secret
topology/project/retention settings. The supported topology has Portal enabled,
a `ww-demo` prefix and three fixed local-execution workspaces.

```bash
# Mutating: authorizes AWS infrastructure changes and demo AAP/Portal setup.
bash scripts/bootstrap.sh profiles/demo.yml --apply
```

If needed, prefix the command with a compatible installed interpreter:

```bash
BOOTSTRAP_PYTHON=python3.14 bash scripts/bootstrap.sh profiles/demo.yml --apply
```

The wrapper verifies actual AWS identity, existing AAP 2.7, workspace
identity/execution mode, active AAP jobs, object ownership and any retained
operation marker. It creates/reuses the HCP project/workspaces, grants only
the two DC state consumers, and applies **shared -> DC1 -> DC2** saved plans.
Terraform execution is local; HCP holds state, not your AWS execution process.

### Verify HAProxy host trust

On a new host, bootstrap can stop **after provisioning AWS** if the discovered
front door has no trusted SSH entry. This is intentional, not a clean rollback.

1. Read the shared front-door outputs:

   ```bash
   bash scripts/terraform.sh shared output -raw frontdoor_public_ip
   bash scripts/terraform.sh shared output -raw frontdoor_url
   ```

2. Independently verify the host fingerprint using a trusted EC2 console or
   equivalent administrative source.
3. Add the verified host key to your `known_hosts` file (or the absolute path
   in `SSH_KNOWN_HOSTS_PATH`). A key scan alone is not identity verification.
4. Set `HAPROXY_PUBLIC_IP` in private `.env` to the actual output.
5. Resume bootstrap. Do not disable host-key verification.

After AWS exists, a repeat bootstrap without apply refuses infrastructure
drift but **can still reconcile AAP/Portal/HCP metadata**:

```bash
bash scripts/bootstrap.sh profiles/demo.yml
```

It is not a dry-run command. If a reviewed infrastructure change is genuinely
required, use `--apply` only within the authorized maintenance window.

Bootstrap reports the actual Portal URL and discovers the execution-image
digest without requiring you to copy it. Set `DEMO_PORTAL_URL` in `.env` to the
verified HTTPS base URL without a trailing slash.

### Verify AAP execution access

Local SSH success does not prove AAP execution-pod SSH access:

```bash
bash scripts/aap-configure.sh readiness
```

This launches a read-only AAP readiness job and reports
`TF_VAR_aap_ssh_cidr`. Verify and record that exact `/32` in private `.env`.
Review and apply **only the shared root** to add its narrowly scoped SSH rule:

```bash
bash scripts/terraform.sh shared plan
bash scripts/terraform.sh shared apply
```

Keep the presenter rule. Do not use `0.0.0.0/0` if egress discovery fails.
Changing egress or expiring credentials requires revalidation.

## 4. Accept the deployment

```bash
bash scripts/demo-status.sh
```

Require exit 0 / READY, then perform [customer acceptance](validation.md#customer-acceptance).
Log into Portal with `ww-demo-operator` in a separate browser profile. The
generated password is retained privately in `.local/aap-operator-password`
unless you supplied `DEMO_OPERATOR_PASSWORD`. Never display the password in
screen sharing or commit it.

Fresh infrastructure starts on DC1. Repeat deployments may legitimately be
DC2-active; inspect actual state rather than resetting to match old notes.

## Costs and end of evaluation

Budget for five running EC2 instances, five root volumes, public IPv4 addresses,
cross-AZ/network traffic and existing-cluster Portal storage/capacity. No fixed
price estimate is promised; region, instance selection and lab entitlements
affect cost. An RHDP lab expiry is not a substitute for verifying your AWS
cleanup.

Agree [teardown](operations.md#teardown) and retained-credential/storage ownership
before handing the environment to another operator. Do not delete the whole
namespace, RHDP platform or local credential directory as a shortcut.
