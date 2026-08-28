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
