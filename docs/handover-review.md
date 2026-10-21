# Customer handover review

**Review date:** 21 October 2026  
**Purpose:** customer-owned RHDP evaluation/demo, not production deployment  
**Runtime baseline reviewed:** `8e76803d03ead5c987cb2d784d7006ea84797a7f`

[Home](../README.md) | [Setup](setup.md) | [Operations](operations.md) |
[Validation](validation.md)

## Executive assessment

The implementation is a credible, evidence-backed evaluation demonstration.
The original packaging was not ready to hand to a new customer: an 864-line
README mixed development history, multiple setup paths and historical lab
states; a license and basic GitHub collaboration files were missing.

The handover changes make the documentation task-oriented and customer-neutral,
retain honest validation boundaries, and add the authorized MIT license and
community files. They do not change runtime behavior or authorize deployment.
The original lab is offline after successful teardown.

**Recommendation:** deliver the source as an evaluation reference with this
review and a guided customer acceptance session. Do not represent it as a
production-ready DR solution, an automatically portable fork, or a validated
post-teardown rebuild.

## Scope and method

Reviewed the tracked repository inventory, design/acceptance record, Terraform
ownership/network/instance configuration, wrappers and lifecycle plans,
declarative AAP/Portal/image source configuration, staged markers/quarantine/
rollback, application and browser scenarios, CI/live approval boundaries,
documentation, optional AI guidance and GitHub metadata.

This is an engineering/handover review, not an exhaustive line-by-line audit,
penetration test, dependency vulnerability scan or legal review of third-party
components. The private `.env` was not read or included; ignore/tracking metadata
was checked instead. Live customer infrastructure was not recreated or mutated.
Historical live results are distinguished from current local/CI validation.

## Findings and disposition

P1 means resolve before the affected handover/use; P2 means a known evaluation
constraint or planned improvement. These are delivery priorities, not
vulnerability severity ratings.

| Priority | Finding / evidence | Disposition |
|---|---|---|
| P1 | No repository license; GitHub license metadata was empty | **Addressed:** owner authorized [MIT](../LICENSE) for first-party content; third-party entitlements remain separate |
| P1 | README was a development transcript with old account/state examples and competing setup/cleanup paths | **Addressed:** concise [README](../README.md) with dedicated [setup](setup.md), [operations](operations.md) and [validation](validation.md) |
| P1 | [Architecture](architecture.md) and [presenter runbook](demo-runbook.md) still called teardown unverified after it passed | **Addressed:** teardown evidence corrected; recreation still explicitly unverified |
| P1 | [Example environment](../.env.example) included the old lab's AWS account ID | **Addressed:** blank explicit customer account pin; private environment remains excluded |
| P1 | Fresh post-teardown recreation has never been live-accepted | **Open:** run approved bootstrap and full acceptance on the customer's own lab; documentation is not evidence of rebuild success |
| P1 | No `demo-live` GitHub environment or approval rules were configured at review time | **Open before storing live secrets:** create protected environment, reviewers and branch restriction; do not treat YAML `environment:` as approval |
| P1 | `main` was unprotected; no required checks/reviewer policy | **Open owner decision:** configure ruleset/protection and require both CI jobs before customer-maintained changes |
| P1 | GitHub private vulnerability reporting, secret scanning and push protection were disabled | **Open owner action:** enable available features, agree private reporting ownership and review alerts before distribution; no secret scan was performed in this review |
| P2 | AAP project, OpenShift build, Portal catalog and cleanup guard pin the upstream repository | **Documented, not changed:** a fork is not automatic; coordinate all [source surfaces](setup.md#source-repository-and-revisions) and tests |
| P2 | `DEMO_SCM_REVISION` can pin AAP while Portal catalog still follows `main` | **Open for immutable distribution:** align source/catalog/EE revisions and validate before claiming a fully pinned release |
| P2 | HAProxy runtime state resets to DC1 on restart/replacement; marker is on the same host | **Documented limitation:** no durable/HA routing or distributed operation guarantee; do not restart to reset |
| P2 | HTTP front door, one proxy, one region and stateless application | **Intentional evaluation scope:** no production security/availability, data replication or RTO/RPO claim |
| P2 | AWS profile/SSO works locally but is not forwarded into AAP; existing AAP secrets use `update_secrets: false` | **Documented:** explicit lab credentials and deliberate [rotation](operations.md#credentials-and-retained-material) required |
| P2 | Latest matching AMI is selected at plan time; later runs can propose replacement | **Documented:** inspect saved plans; no promise that a future bootstrap is no-change |
| P2 | No contribution, support, security, conduct, issue/PR or dependency-review files | **Addressed:** native files added without inventing a support SLA or maintainer team |
| P2 | No GitHub description/topics or versioned release baseline | **Metadata addressed:** evaluation-focused description and six topics set; tag/release awaits agreed ownership and customer acceptance |
| P2 | Agents could look like a required component or still demand a next phase | **Addressed:** concise optional [AGENTS.md](../AGENTS.md) and [Copilot guidance](../.github/copilot-instructions.md); all eight phases complete |

## Should the agents remain?

**Yes, as optional development guidance.** The tracked repository has an
`AGENTS.md` instruction file and a Copilot instruction file, not deployed
autonomous agent services. They reinforce important boundaries for future
contributors, including not installing/removing RHDP platforms or bypassing
quarantine and ownership checks.

Keep one canonical cross-tool guide and a short Copilot-specific pointer.
Do not ship personal prompts, credentials, editor/session state, unrelated
agent definitions or a requirement to buy an AI subscription. Human setup and
operations must remain complete without these files.

## GitHub-native files

### Added for this handover

- [LICENSE](../LICENSE), [CHANGELOG.md](../CHANGELOG.md)
- [CONTRIBUTING.md](../CONTRIBUTING.md), [SUPPORT.md](../SUPPORT.md)
- [SECURITY.md](../SECURITY.md), [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md)
- [Bug form](../.github/ISSUE_TEMPLATE/bug_report.yml),
  [proposal form](../.github/ISSUE_TEMPLATE/feature_request.yml),
  [issue routing](../.github/ISSUE_TEMPLATE/config.yml)
- [PR template](../.github/pull_request_template.md)
- [Dependabot](../.github/dependabot.yml) for Actions, Python and browser npm
  dependencies; proposals require review, not automatic merge

Existing [CI](../.github/workflows/ci.yml), [manual live workflow](../.github/workflows/live.yml),
ignore rules, editor settings and Terraform/npm locks are retained.
Ansible collections, Portal chart, container base and AMIs still need deliberate
compatibility/lifecycle review; the new Dependabot file does not cover them all.

### Not invented

- **CODEOWNERS:** add after the customer designates actual GitHub users/teams
  with appropriate access. A guessed owner is worse than an explicit decision.
- **Release/tag:** agree a version and distribution source, align revision
  surfaces, then publish release notes after acceptance. No fabricated `v1.0`.
- **Funding, citation and DCO/CLA:** no project requirement was supplied.
- **Product support contact/SLA:** no entitlement or staffing commitment was
  invented.

## GitHub owner settings

Files do not configure repository governance. The owner/customer should:

1. Decide whether the authoritative distribution is upstream, a transfer or a
   customer fork/mirror. Coordinate source allowlists and catalog paths first.
2. Set a concise description/topics; confirm Issues availability and who triages
   them. Discussions are optional, not required.
3. Protect `main`: PR review, required `application-browser` and `validate`
   checks, resolved conversations and a deliberate bypass/administrator policy.
   Add CODEOWNERS only after naming actual responsible maintainers.
4. Create `demo-live` **before secrets**; require reviewers, restrict deployment
   to `main`, separate read-only and mutation approvals operationally, and never
   place cloud/admin credentials in normal PR CI.
5. Enable private vulnerability reporting, secret scanning/push protection and
   Dependabot alerts/security updates where available. Assign a response owner;
   configuration alone is not a completed scan or remediation.
6. Review Actions permissions and allowed actions. Current workflows request
   read-only repository contents, but repository policy allowed all actions.
   Consider immutable action SHA pins in a separately validated maintenance PR.
7. Review history and any downloadable release archive for private/customer
   information. Never hand over the entire local workspace, `.env`, `.local`,
   state/plans, browser output or the untracked historical run sheet.
8. Publish a reviewed tag/release only once revision alignment and evaluation
   acceptance are agreed. Distribute licensed source, not preconfigured access.

No settings above were silently changed by adding policy/template files.
Only the public description/topics were updated; protections and security
settings remain explicit owner actions.

## Handover validation

- Local Markdown checks passed: 123 relative file/heading links across 16
  deliverable Markdown files at the first check; the historical untracked lab
  run sheet was excluded from distribution.
- New GitHub YAML passed lint and structural checks for valid ecosystem paths,
  unique issue-form IDs and safe reporting fields.
- Credential-free Terraform environment, runtime environment, SSH-key lifecycle
  and workspace wrapper regressions passed.
- `git diff --check` passed. Git tracking/ignore checks confirmed private
  environment/key/state material is excluded; its contents were not inspected.
- Full handover-commit CI is required before delivery; the README badge and
  Actions run are the current result, not the historical baseline's result.
- No live provisioning, failover, fault injection, teardown, CVE/SAST scan or
  post-teardown recreation was performed for this documentation review.

## Delivery checklist

- [ ] Customer maintainer, license attribution and private reporting route agreed.
- [ ] Distribution source/fork changes and supported platform versions agreed.
- [ ] GitHub owner settings above applied and checked.
- [ ] Full CI green for the actual handover commit.
- [ ] Customer environment configured privately; no old lab credentials copied.
- [ ] Fresh bootstrap and required [customer acceptance](validation.md#customer-acceptance) recorded.
- [ ] Optional real outage approved separately, or explicitly excluded.
- [ ] Teardown, retained-material ownership and final disposal agreed.

The MIT license was explicitly approved by the repository owner. Unchecked
items are receiving-owner/environment actions, not claims of completed work.
