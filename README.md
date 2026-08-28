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

## Non-claims

The v1 fixture does not execute Terraform, contact a cloud provider, deploy a
service, or send a network probe. It verifies captured receipt relationships.
Those live capabilities remain `NOT_CLAIMED`, not silently successful.

See [the v1 RFC](docs/rfcs/infra-evidence-v1.md).
