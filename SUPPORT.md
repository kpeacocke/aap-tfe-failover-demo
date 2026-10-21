# Support

This repository is an evaluation reference, **not a supported product or
managed service**. No response time, production SLA or on-call cover is offered.
An issue here does not open a Red Hat, HashiCorp, AWS or RHDP support case.

## Before opening an issue

1. Start with [setup](docs/setup.md) and [operations](docs/operations.md).
2. Check the [handover limitations](docs/handover-review.md).
3. For an existing lab, inspect readiness privately. Do not run a traffic change
   merely to reproduce a reporting issue.
4. Record your commit, relevant tool/platform versions, sanitized reproduction
   steps, expected/actual result and exact failing command/exit code.

Use the [bug report](https://github.com/kpeacocke/aap-tfe-failover-demo/issues/new?template=bug_report.yml)
or [change proposal](https://github.com/kpeacocke/aap-tfe-failover-demo/issues/new?template=feature_request.yml).
For a private customer environment, agree a private support channel with its
owner before exchanging diagnostic information.

Never upload environment files, credentials, private keys, full Terraform
state/plans, Secret data, browser auth URLs/state or unsanitized logs.
Use the [security policy](SECURITY.md) for vulnerabilities.

## Where a problem belongs

| Problem | Route |
|---|---|
| Reproducible repository behavior/documentation bug | Sanitized GitHub issue |
| RHDP access, expiry or supplied platform health | Your RHDP lab owner/catalog support route |
| AAP/Portal/OpenShift product issue | Your organization's entitled Red Hat support route |
| HCP Terraform/AWS account, quota or billing | Your account owner and applicable provider support |
| Production adaptation or operational incident | Customer's own engineering/incident process; this demo is not a production runbook |

Do not restart, upgrade or remove RHDP platforms to work around a demo failure.
Do not ask a restricted user to supply an administrator token.
