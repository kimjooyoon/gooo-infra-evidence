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

## OpenTofu adoption boundary

The released-domain envelope v2 candidate keeps its observed Terraform binding
as `iac_engine: TERRAFORM`; it does not relabel that fixture as OpenTofu.
OpenTofu adoption is `0/1 UNKNOWN` until an immutable, machine-readable JSON
receipt supplies `iac_engine`, engine version, release id, binary digest, and
format version. `iac_engine` is explicitly one of `OPENTOFU`, `TERRAFORM`, or
`UNKNOWN`; the `terraform_version` JSON key is not used to infer the engine.
With no actual OpenTofu receipt, the only next operation is
`PROVIDE_IMMUTABLE_OPENTOFU_JSON_RECEIPT`. Unknown engines or unknown receipt
states fail closed.

No OpenTofu source import, vendor, build, `init`, `plan`, `apply`, `test`,
provider, network, or cloud access is in this candidate. Although a future
separately opted-in fixture may use `tofu test` with `command = plan`,
`refresh = false`, and mock providers, it is not part of current conformance.

See [the v1 RFC](docs/rfcs/infra-evidence-v1.md).

## OpenTofu receipt V1

The additive OpenTofu receipt path closes one previously UNKNOWN integration
boundary with an actual released CLI observation. CI digest-locks OpenTofu
`v1.12.6`, executes `tofu version -json` twice, and binds an explicit
`iac_engine: OPENTOFU` receipt to twelve Gooo meta activities. Engine identity
is not inferred from the compatibility key `terraform_version`.

The normal path is `12/12 CLOSED`, OpenTofu adoption is `1/1 CLOSED`, and the
executed case corpus is exactly one normal, one UNKNOWN, and two REFUTED
paths. The UNKNOWN path preserves both `DIRECT_MISSING` and
`DEPENDENCY_BLOCKED` claims with six coordinates. CI writes exactly seven
caller-owned artifacts and records version-command wall time, peak RSS,
repository inventory, Go/Gooo physical lines, and zero init/plan/apply/test
executions. Release adoption, independent external utility, and exact
before/after improvement remain `0/1 UNKNOWN`.

See [the OpenTofu receipt RFC](docs/rfcs/opentofu-receipt-v1.md).

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
unrelated cells and canonical digests are unchanged. The transformation
consumer `.gooo` source declares exactly twelve activities, with
FOUNDATION/COHERENCE/REGRESSION and DRIVER/OUTCOME/GUARDRAIL each fixed at
`4/4`.

CI preserves normal, missing-evidence, digest-valid effect-laundering, and
REFUTED-over-UNKNOWN cases with `closed + unknown + refuted = 12` per case.
Go 1.27 is used; Go build/test and OpenTofu init/validate/plan executions are
zero. Producer conformance reuse is `5/5 CLOSED`, released test receipt reuse
is `0/1 UNKNOWN`, saved build/test times are UNKNOWN without exact same-digest
before/after pairs, and external user utility remains UNKNOWN.

See [the transformation consumer RFC](docs/rfcs/opentofu-receipt-transformation-v1.md).

## OpenTofu service-contract bridge

The service-contract bridge is the next independent read-only product path in
this repository. It consumes only immutable `tofu show -json`-shaped plan and
state fixtures, an OpenAPI document digest, and optional service metadata. It
does not run OpenTofu, install a provider, write remote state, deploy a
service, or probe a live endpoint.

The OpenTofu JSON input follows the documented `format_version: "1.0"`
representation. A plan carries planned values, resource changes, and the
configuration projection; a state carries the values projection. The bridge
records the explicit representation type (`PLAN` or `STATE`) and never infers
the engine from the compatibility field `terraform_version`. See the official
[OpenTofu JSON output format](https://opentofu.org/docs/internals/json-format/)
and [`tofu show -json`](https://opentofu.org/docs/cli/commands/show/).

The Gooo-owned mapping ontology has exact typed relations:

```text
OpenTofu resource --PROVISIONS--> service operation
service operation --ASSERTS--> service claim
service claim --SUPPORTED_BY--> OpenTofu plan/state evidence
service claim --DECLARED_BY--> OpenAPI operation evidence
```

Name similarity is not a mapping basis. Missing typed evidence is `UNKNOWN`
with exactly `stage`, `step`, `reason`, `unknown_class`, `next_operation`, and
`blocked_by`. Conflicting mappings or immutable identities are `REFUTED`, and
the fixed precedence is `REFUTED > UNKNOWN > CLOSED`.

The Actions-only conformance corpus is fixed at 12 cells and includes normal,
missing-state `UNKNOWN`, and mixed `REFUTED`-over-`UNKNOWN` cases. The emitted
machine bundle contains the mapping ontology, exact relations, unresolved
causal frontier, counterexamples, action execution evidence, release-lock
identities, and a deterministic human dossier. Proof choices and indicator
classes are independent; no score or percentage is emitted. Exact
before/after integer improvement remains `null` plus `UNKNOWN`, and external
utility remains `0/1 UNKNOWN` without an independent external-user receipt.

The bridge is validated only in
[GitHub Actions](.github/workflows/opentofu-service-contract-bridge.yml) with
Go 1.27 and released Gooo. The OpenTofu release is digest-locked to `v1.12.6`
and is verified as an immutable asset but never executed. Root `README.md` is
excluded from Go/Gooo inventory readiness. The bridge's required
cross-project gates, repository writes, provider accesses, remote-state
writes, and OpenTofu executions are all zero.
