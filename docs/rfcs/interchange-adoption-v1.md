# Infra-evidence interchange adoption v1

## Decision

The infra evidence exports one advisory five-file interchange bundle. It does not mutate the observed project and it does not make another repository branch a required gate.

The immutable `gooo-interchange-spec` release report is an evidence input. The local exporter and conformer remain independently executable after that asset has been acquired and verified by digest.

The source asset digest covers the complete sorted `fixtures/checkout-service` tree, including Terraform declaration, plan and state, OpenAPI, service code, build and deployment receipts, and runtime observations.

## Meta authority

`examples/interchange-adoption/main.gooo` declares twelve activities. The released Gooo core must resolve each activity exactly once. An explicit `CLOSED` core decision is accepted; an unknown decision value is fail-closed as `UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION`.

The fixed denominator is twelve cells with exact splits:

- FOUNDATION 4, COHERENCE 4, REGRESSION 4
- OUTCOME 3, DRIVER 5, GUARDRAIL 4

The root README is excluded from readiness predecessors.

## Bundle contract

Every generated bundle contains exactly five files:

- `project.json`
- `relations.ndjson`
- `conformance.json`
- `unknowns.ndjson`
- `checksums.txt`

Every bundle receives exactly six local checks. The workflow generates the bundle twice and compares all five files byte-for-byte.

## Uncertainty and refutation

UNKNOWN requires `stage`, `step`, `reason`, `unknown_class`, and `next_operation`. An incomplete UNKNOWN tuple is fail-closed. Checksum drift is independently fail-closed.

## Adoption meaning

A pull request reports this release's adoption as 0/1. A successful main-branch run reports 1/1. Portfolio adoption remains `UNKNOWN` with class `SCOPE_DEFERRED` and next operation `OBSERVE_WITH_GOOO_LINK`; this repository does not infer the state of other domains. Neither state starts the connector.
