# Gooo Infra Evidence

Gooo Infra Evidence is a read-only claim ledger for infrastructure and service
receipts. It keeps declaration, plan, state, source, artifact, deployment,
policy, and runtime observations separate instead of merging them into one
unqualified "current state".

The first fixture follows one checkout service:

```text
Gooo authority
  -> Terraform declaration
  -> Terraform plan
  -> Terraform state binding
  -> service source and artifact receipt
  -> deployment output
  -> policy decision
  -> two runtime observations
```

## Fixed denominator

| Cell | Proof choice |
|---|---|
| RELEASED_GOOO_IDENTITY | FOUNDATION |
| GOOO_SOURCE_AUTHORITY | FOUNDATION |
| GOOO_GRAPH_BINDING | COHERENCE |
| TERRAFORM_DECLARATION | FOUNDATION |
| TERRAFORM_PLAN | COHERENCE |
| TERRAFORM_STATE | COHERENCE |
| OPENAPI_CONTRACT | FOUNDATION |
| SERVICE_ARTIFACT_PROVENANCE | COHERENCE |
| DEPLOYMENT_OUTPUT | COHERENCE |
| POLICY_DECISION | COHERENCE |
| RUNTIME_DRIFT_REGRESSION | REGRESSION |
| READ_ONLY_EFFECT | REGRESSION |

CI evaluates three views without modifying the repository:

- complete captured evidence: `12/12 CLOSED`;
- missing Terraform state: one `DIRECT_MISSING` UNKNOWN and two
  `DEPENDENCY_BLOCKED` UNKNOWN cells;
- deployment artifact drift: deployment and runtime cells are REFUTED.

The v2 path parses `terraform/main.tf` with the digest-locked HashiCorp HCL
v2.24.0 syntax tree. It observes the resource labels, required literal
attributes, and source range, then binds that receipt to the released Gooo
`ObserveTerraformDeclaration` activity. Missing source and missing expression
context remain distinct UNKNOWN classes; invalid syntax and contradictory
literals are REFUTED. CI reports parser peak RSS and wall time separately from
the released Gooo graph command.

## Non-claims

The v1 fixture does not execute Terraform, contact a cloud provider, deploy a
service, or send a network probe. It verifies captured receipt relationships.
Those live capabilities remain `NOT_CLAIMED`, not silently successful.

## OpenTofu Receipt V1 transformation consumer

This repository is the second independent domain consumer of the released
Gooo transformation effect: `1/1 CLOSED`. It does not claim whole-language
generalization (`0/1 UNKNOWN`). The producer is the immutable public release
`kimjooyoon/gooo-evidence-generator@v0.4.0-dev`, tag target
`c60dfed9c082d91b9b20e3f465b3a7f2c0f522a0`, and transformation-effect ZIP
digest `sha256:cd15f867b90615133a6bb2ea2eb31a2745e1c9a730c6a80d37c1a6ca2cb1331d`.
Producer source is never checked out; its five conformance receipts are
digest-verified and reused.

The actual OpenTofu Receipt V1 semantic pair is `11 CLOSED / 1 UNKNOWN / 0
REFUTED` before and `12 CLOSED / 0 UNKNOWN / 0 REFUTED` after. Exactly one
target cell, `OPENTOFU_RECEIPT_UNKNOWN_TRACE`, changes from UNKNOWN to CLOSED;
unrelated cells and canonical digests are unchanged. The consumer `.gooo`
source declares exactly twelve activities, with FOUNDATION/COHERENCE/REGRESSION
and DRIVER/OUTCOME/GUARDRAIL each fixed at `4/4`.

CI preserves normal, missing-evidence, digest-valid effect-laundering, and
REFUTED-over-UNKNOWN cases with `closed + unknown + refuted = 12` per case.
Go 1.27 is used; Go build/test and OpenTofu init/validate/plan executions are
zero. Producer conformance reuse is `5/5 CLOSED`, released test receipt reuse
is `0/1 UNKNOWN`, saved build/test times are UNKNOWN without exact same-digest
before/after pairs, and external user utility remains UNKNOWN.

See [the OpenTofu Receipt V1 transformation RFC](docs/rfcs/opentofu-receipt-v1.md).
