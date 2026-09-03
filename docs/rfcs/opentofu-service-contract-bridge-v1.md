# RFC: OpenTofu service-contract bridge v1

## Status

Candidate implementation in `gooo-infra-evidence`. The conformance gate is
GitHub Actions-only. A release is eligible only after the PR path is green,
the merged `main` workflow is green, and the draft-first patch release has an
immutable tag target and digest-verified assets.

## Problem and boundary

An infrastructure receipt and a service contract are different authorities.
This bridge makes their relationship inspectable without claiming that a plan
was applied or that a service is live. It consumes:

1. an immutable OpenTofu machine-readable plan representation;
2. an immutable OpenTofu machine-readable state representation;
3. an OpenAPI document and its exact digest; and
4. optional service metadata.

OpenTofu documents `tofu show -json` as the machine-readable representation
for plans and states. The documented top-level `format_version` is `1.0`, and
plan JSON includes planned values, resource changes, configuration, and
current state projections. The bridge records those inputs as `PLAN` or
`STATE`; it does not treat the compatibility key `terraform_version` as engine
identity. See the official [JSON output format](https://opentofu.org/docs/internals/json-format/)
and [`tofu show`](https://opentofu.org/docs/cli/commands/show/).

The Actions workflow verifies the public OpenTofu `v1.12.6` release, its Linux
archive digest, the extracted binary digest, and a `tofu version -json`
receipt. The captured plan/state compatibility key is retained as input data
but is not used as the `iac_engine` identity.

## Gooo authority

`.gooo` owns the bridge's meaning, activity graph, relation vocabulary, proof
policy, indicator policy, and resolution precedence. The twelve activities in
`examples/opentofu-service-contract-bridge/main.gooo` are resolved against a
released Gooo graph in Actions. Shell and `jq` only project immutable fixture
receipts into the machine bundle and human dossier; they do not become a
semantic authority.

The mapping ontology is Gooo-owned and requires exact typed identities. The
workflow compares the fixed denominator's twelve distinct activity names with
the released graph's twelve activity nodes and twelve unique cardinality
receipts, in denominator order, before any cell is closed:

| Subject | Relation | Object | Required basis |
|---|---|---|---|
| OpenTofu resource | `PROVISIONS` | service operation | explicit resource and operation identity |
| service operation | `ASSERTS` | service claim | explicit operation and claim identity |
| service claim | `SUPPORTED_BY` | OpenTofu plan evidence | exact JSON pointer and digest |
| service claim | `SUPPORTED_BY` | OpenTofu state evidence | exact JSON pointer and digest |
| service claim | `DECLARED_BY` | OpenAPI operation evidence | exact operation ID and digest |

Resource labels, operation IDs, paths, or claim names that merely look alike
never create a relation. Missing typed evidence is `UNKNOWN`. Contradictory
mapping rows, authority escalation, or different immutable identities are
`REFUTED`; `REFUTED > UNKNOWN > CLOSED` is applied before a dossier decision.

## Fixed denominator

The denominator is twelve cells, with proof and indicator dimensions kept
independent:

- proofs: `FOUNDATION 4`, `COHERENCE 4`, `REGRESSION 4`;
- indicators: `DRIVER 4`, `OUTCOME 4`, `GUARDRAIL 4`;
- required UNKNOWN coordinates: `stage`, `step`, `reason`, `unknown_class`,
  `next_operation`, `blocked_by`.

Actions must preserve these three scenario vectors:

| Scenario | CLOSED | UNKNOWN | REFUTED | Decision |
|---|---:|---:|---:|---|
| normal | 12 | 0 | 0 | `CLOSED` |
| missing OpenTofu state | 9 | 3 | 0 | `UNKNOWN` |
| mapping conflict plus missing state | 8 | 1 | 3 | `FAIL_CLOSED` |

The last case is intentionally mixed: a direct missing state remains an
`UNKNOWN` frontier, but a conflicting mapping and its dependants are
`REFUTED`, so the overall decision is fail-closed.

## Evidence and non-claims

Every bundle has an exact digest for the plan, state when present, OpenAPI
document, mapping, optional metadata, ontology, Actions evidence, and release
lock. It also carries the pinned `OPENTOFU` release identity, archive digest,
binary digest, version-receipt digest, and exact activity-to-cell binding
digest. A normal bundle contains five exact relations: one resource-to-
operation, one operation-to-claim, and three claim-to-evidence relations. The
missing-state case emits only the four relations that have evidence and keeps
the unresolved state edge in the causal frontier.

Build and test executions are explicitly zero in the workflow. Their
`execution_state` is `NOT_EXECUTED`, their `cache_state` is
`NOT_APPLICABLE`, and their wall time, peak RSS, and executed/reused/skipped
counts are recorded as null/null/0/0/0 rather than fabricated timings. The
executed Gooo graph, activity-resolution, and OpenTofu identity phases record
integer wall time, peak RSS, and executed/reused/skipped counts. Go/Gooo lines,
files, and directories exclude root `README.md` and are captured as exact
Actions evidence. The workflow does not run `go build`, `go test`, `gofmt`,
`go vet`, `actionlint`, `tofu init`, `tofu plan`, `tofu apply`, or `tofu test`.
The only OpenTofu execution is the pinned binary's read-only `version -json`
identity receipt; it does not install providers, write remote state, deploy,
or contact a service runtime. Any future accidental operational execution
must be recorded as `OPERATIONAL_REFUTED` rather than hidden.

No prior evidence is reused in this candidate. If reuse is introduced later,
the subject SHA, source tree, toolchain digest, command digest, and input
digest must all match exactly; a partial match is not reusable evidence.

External utility is `0/1 UNKNOWN` without an independent external-user
receipt. Improvement is `null` plus `UNKNOWN` without an exact matched
before/after integer pair under the same immutable identities.

## Release and merge protocol

The implementation is PR-first. A failed Actions run remains part of the
review history. After a green PR, the merged `main` workflow is the release
input. The patch release is draft-first, uses a new immutable tag, never
reuses a version, and publishes exact asset digests. Release or tag deletion
is not part of the protocol.

The only repository extended by this RFC is
`kimjooyoon/gooo-infra-evidence`. `meta-ontology-go`, OpenTofu upstream, a
service repository, and `gooo-self-improvement-ledger` are inputs or external
authorities and are not modified.
