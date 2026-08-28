# RFC: Gooo Infrastructure Deployment Contract Packet v1

Status: Experimental. Immutable release assets and GitHub Actions are the only conformance authority.

## User path

A checkout-service owner submits one explicit production review request. The system joins released Terraform, OpenAPI, Go handler, build, deployment, runtime, and claim-resolution evidence into three deterministic outputs:

1. `deployment-contract.json` records the decision and all evidence coordinates.
2. `deployment-generation-manifest.json` exposes typed inputs for downstream configuration, service-binding, and deployment-review generators.
3. `deployment-runbook.md` gives a human reviewer the same decision without requiring JSON inspection.

The packet never runs Terraform, applies infrastructure, deploys an artifact, probes a network, writes source files, or authorizes an automatic merge.

## Metaprogramming boundary

`examples/deployment-contract-packet/main.gooo` declares all fifteen product activities and five active decision tuples. Released Gooo v0.3 checks the program, emits its graph, and resolves normal CLOSED, missing-state UNKNOWN, artifact-drift REFUTED, handler-ambiguity REFUTED, and execution-authority REFUTED receipts. Projection code may join immutable evidence but cannot invent these claims.

The three locked inputs are Gooo core v0.3.0-dev, Infra evidence v0.5.0-dev, and Infra claim-resolution adoption v0.6.0-dev.

## Fixed denominator and exact indicators

FOUNDATION, COHERENCE, and REGRESSION each own 5/15 cells. DRIVER, OUTCOME, and GUARDRAIL each own 5/15 cells.

Normal conformance records:

- Infra evidence cells: 12/12.
- Claim-adoption cells: 12/12.
- Terraform resource binding: 1/1.
- OpenAPI-to-Go binding: 1/1.
- Semantic edges: 6/6.
- Plan, state, build, and deployment chain: 4/4.
- Released claim tuples and fields: 3/3 and 18/18.
- Gooo decision receipts and fields: 5/5 and 30/30.
- Generated artifacts: 3/3.
- Counterexamples: 4/4.
- Artifact replay: 3/3.
- Repository writes, local tests, and cross-project required gates: 0/0/0.

Repository inventory excludes the root `README.md` and records every Go and Gooo file with its physical line count.

## Resolution loss

- Missing Terraform state produces 11 CLOSED / 4 UNKNOWN. The direct cell records `INFRA_STATE`, `BIND_TERRAFORM_STATE`, `TERRAFORM_STATE_UNAVAILABLE`, `DIRECT_MISSING`, and `PROVIDE_TERRAFORM_STATE_RECEIPT`; three dependents record `DEPENDENCY_BLOCKED`.
- Deployment artifact drift produces 12 CLOSED / 3 REFUTED.
- Ambiguous OpenAPI handler registration produces 11 CLOSED / 4 REFUTED.
- Terraform-apply and deployment authority escalation produces 13 CLOSED / 2 REFUTED.

Removing any declared Gooo activity rejects generation before evidence projection.

## Independence

The generated manifest is advisory input, not execution authority. Infra can publish this packet without Link. A later Link observation may count the released user path but cannot gate this repository.
