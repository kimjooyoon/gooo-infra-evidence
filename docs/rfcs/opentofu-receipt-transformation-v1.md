# OpenTofu Receipt V1 transformation consumer

## User question

Does the released Gooo transformation effect remain semantically valid when an
independent consumer adopts it for the OpenTofu Receipt V1 domain?

This is a consumer experiment. It does not claim that the Gooo language as a
whole generalized. The only closed scope is the second independent domain
consumer: 1/1 CLOSED.

## Immutable released inputs

The producer is the public release
kimjooyoon/gooo-evidence-generator@v0.4.0-dev, whose tag resolves to
c60dfed9c082d91b9b20e3f465b3a7f2c0f522a0. CI verifies the release id, tag,
tag target, ZIP asset id 536426088, size 53113, and ZIP SHA-256
cd15f867b90615133a6bb2ea2eb31a2745e1c9a730c6a80d37c1a6ca2cb1331d before
using it. The ZIP is a released evidence artifact; the producer source is
never checked out. Its five public conformance receipts and their eight-file
scenario manifests are verified and reused as immutable evidence.

Gooo Core is acquired only from the existing immutable
kimjooyoon/meta-ontology-go@v0.4.0-dev release lock. The consumer runs that
released binary's syntax check, semantic check, graph dump, and twelve
activity resolutions against examples/opentofu-receipt-transformation-v1/main.gooo.
No copied producer evaluator, source checkout, sibling checkout, or
title/score inference is used.

## OpenTofu Receipt V1 semantic unit

The consumer's actual semantic unit is a twelve-cell OpenTofu Receipt V1
project snapshot in fixtures/opentofu-receipt-v1/before.json and
fixtures/opentofu-receipt-v1/after.json.

The exact pair is:

- before: 11 CLOSED / 1 UNKNOWN / 0 REFUTED;
- after: 12 CLOSED / 0 UNKNOWN / 0 REFUTED;
- target cell: OPENTOFU_RECEIPT_UNKNOWN_TRACE;
- target transition: exactly one UNKNOWN -> CLOSED;
- delta: closed +1, unknown -1, refuted 0, denominator 0;
- unrelated cell changes: 0;
- unrelated canonical digests: equal.

The before target preserves all six UNKNOWN coordinates:
stage, step, reason, unknown_class, next_operation, and blocked_by. The after
target is explicit CLOSED evidence. The producer receipt's UNKNOWN_TRACE is
bound to this consumer target by an explicit ordinal and semantic-role
mapping.

## Case corpus

Each case preserves closed + unknown + refuted = 12.

| Case | CLOSED | UNKNOWN | REFUTED | Meaning |
|---|---:|---:|---:|---|
| normal | 12 | 0 | 0 | exact isolated transition |
| normal replay | 12 | 0 | 0 | producer replay receipt |
| missing evidence | 11 | 1 | 0 | six-coordinate UNKNOWN |
| digest-valid effect laundering | 6 | 0 | 6 | valid digests do not prove an effect; authority escalation is REFUTED |
| refuted over unknown | 4 | 2 | 6 | REFUTED has precedence over UNKNOWN |

The missing-evidence case remains lower resolution. The digest-valid
laundering case is rejected even though its digests are valid and its
before/after transition count is zero. The mixed case is rejected with
REFUTED selected over UNKNOWN.

## Fixed denominator and indicators

The consumer .gooo source declares exactly twelve activities. The fixed
denominator is twelve cells: FOUNDATION, COHERENCE, and REGRESSION each have
four cells; DRIVER, OUTCOME, and GUARDRAIL each have four cells.

The consumer's released Core graph/check outputs and the producer's released
graph/check/conformance files are included in one manifest-bound CI artifact.
The manifest has exactly 79 files: all 56 files from the producer ZIP, the
verified producer acquisition files, the Core release/check evidence, the
consumer pair and bindings, five consumer case receipts, and the adoption,
conformance, and report files.

## Non-claims and exact metrics

CI uses Go 1.27 and does not run local tests. Go build/test executions are
zero. OpenTofu init, validate, and plan executions are zero; no provider,
cloud, source checkout, or runtime network claim is made.

producer_conformance_receipt_reuse is 5/5 CLOSED. Released test receipt reuse
is 0/1 UNKNOWN. saved_build_ms and saved_test_ms remain UNKNOWN because no
same-digest, same-toolchain, same-scenario exact before/after build/test pair
exists. External user utility remains 0/1 UNKNOWN.
