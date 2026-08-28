# RFC: Infra claim resolution adoption v1

Status: Experimental independent consumer

## Decision

The infra evidence product directly adopts the released Gooo
`gooo.primitive.claim-resolution-tuple.v1` operation. It does not replace the
infra evaluator. It resolves three claims already present in immutable v0.5
release evidence and checks exact six-field equality.

The three released scenarios are:

- complete evidence: 12 CLOSED, 0 UNKNOWN, 0 REFUTED
- unresolved HCL value: 6 CLOSED, 6 UNKNOWN with `CONTEXT_MISSING`
- deployment artifact mismatch: 10 CLOSED, 0 UNKNOWN, 2 REFUTED

Together they provide 18 released claim fields. The released core produces 18
corresponding fields. CI accepts the adoption only when all 3 scenario tuples
are equal.

## Meta binding

The fixed denominator has twelve cells. Every cell names one activity in
`examples/claim-resolution-adoption/main.gooo`, and every activity carries a
`claim.resolve:v1` value program. Core receipts must identify the selected
activity exactly once and identify the candidate primitive.

Munchausen choices are FOUNDATION 4, COHERENCE 4, and REGRESSION 4. Indicator
classes are DRIVER 4, OUTCOME 4, and GUARDRAIL 4. A score without the twelve
Gooo activity receipts cannot close.

## Resolution lowering

A missing core receipt is UNKNOWN at `CORE_RECEIPT /
OBSERVE_CLAIM_RESOLUTION_RECEIPT`, classified as `DIRECT_MISSING`, with
`PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT` as the next operation. A changed
released tuple is REFUTED. An incomplete UNKNOWN tuple and an unrecognized
parent state must both be rejected by the released core with `FAIL_CLOSED`.

## Human-readable indicators

CI publishes exact repository file and descendant-directory counts, total and
per-file Go and Gooo line counts, claim-resolution peak RSS and wall time,
scenario and field denominators, repository writes, local test executions, and
cross-project required gates. Root README presence is excluded from readiness.

## Authority boundary

Both inputs are pinned public release assets with exact commit, asset, size,
and SHA-256 identities. The consumer performs no Terraform execution, cloud
query, deployment, network probe, source mutation, automatic merge, or core
mutation. Generator authority is false and cross-project required gates remain
zero.
