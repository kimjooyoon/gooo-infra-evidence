# Released-domain envelope v2 adoption candidate

## Scope and decision

This RFC proposes one Infra-only adoption candidate for the released-domain
envelope v2 consumer kit. It extends the already released semantic deployment
plan meaning: the eight typed Infra dependencies and the previously observed
OpenAPI, Terraform, and deployment-chain bindings are projected as released
declarations with evidence anchors. It does not execute Terraform or a
provider, generate an OpenAPI server, deploy anything, probe a network, or
claim semantic truth from a deterministic replay.

The implementation is a candidate only. Released adoption is `0/1 UNKNOWN`
until a later release publishes and adopts the envelope. External utility is
also `0/1 UNKNOWN` because no user evidence is supplied by this experiment.
The final pre-release disposition is therefore `DEFER`: the candidate is
ready for review, but release adoption and external utility remain
unobserved.

## Fixed inputs and authority

The CI workflow downloads only immutable GitHub release assets. It verifies
release id, prerelease tag, tag target, asset id, size, and SHA-256 before use.
The lock pins Core `v0.4.0-dev`, Interchange Spec `v0.3.0-dev`, and Infra
`v0.8.0-dev`. The Interchange kit is consumed directly from its downloaded
asset; CI performs no kit source checkout and copies no conformer. The
projector receives an explicit absolute repository root and rejects an output
directory that is the root or a descendant. Its output is written only to a
caller-owned temporary directory.

The product owns the projection and the claim-resolution report. Its project
authority is exactly:

```json
{
  "projection_owner": "INTERCHANGE_SPECIFICATION",
  "domain_release_adoption_claimed": false,
  "source_repository_writes": 0,
  "product_generation_authorized": false
}
```

No required gate is created for Core, Interchange Spec, or any other project.
The CI gate count for cross-project dependencies remains zero.

## Infra-only denominator

The denominator has exactly twelve cells and twelve distinct Gooo activities.
Each cell id, activity, and fact is one-to-one. The proof and indicator
denominators are both four per class:

| # | Cell / Gooo activity | Proof | Indicator |
|---:|---|---|---|
| 1 | `CORE_RELEASE` / `ObserveCurrentCoreRelease` | FOUNDATION | DRIVER |
| 2 | `INTERCHANGE_SPEC_RELEASE` / `ObserveInterchangeSpecRelease` | FOUNDATION | DRIVER |
| 3 | `INFRA_RELEASE` / `ObserveInfraSemanticPlanRelease` | FOUNDATION | DRIVER |
| 4 | `META_ACTIVITY_AUTHORITY` / `BindTwelveMetaActivities` | FOUNDATION | DRIVER |
| 5 | `INFRA_DEPENDENCY_SOURCE` / `ObserveEightInfraDependencies` | COHERENCE | OUTCOME |
| 6 | `PRODUCT_PROJECTION` / `ProjectInfraEnvelope` | COHERENCE | OUTCOME |
| 7 | `EIGHT_FILE_ENVELOPE` / `PublishEightFileInfraEnvelope` | COHERENCE | OUTCOME |
| 8 | `READ_ONLY_CONFORMANCE` / `ConformInfraEnvelopeReadOnly` | COHERENCE | OUTCOME |
| 9 | `UNKNOWN_CAUSALITY` / `PreserveUnknownCausality` | REGRESSION | GUARDRAIL |
| 10 | `DETERMINISTIC_REPLAY` / `VerifyEnvelopeReplay` | REGRESSION | GUARDRAIL |
| 11 | `REFUTED_COUNTEREXAMPLES` / `RefuteMalformedCoreReports` | REGRESSION | GUARDRAIL |
| 12 | `AUTHORITY_BOUNDARY` / `PreserveInfraAuthorityBoundary` | REGRESSION | GUARDRAIL |

The dependency graph is intentionally ordered: release observations precede
the source and projection; the envelope precedes conformance; conformance
precedes the causality and counterexample observations; the final authority
cell depends on all three regression branches. Generic Interchange product
cells and unrelated Local or Design release cells are not in this denominator.

## Evidence and state rules

The normal run uses one current-run bundle, its six-file payload digest, its
eight-file replay, and the conformer report. The eight relations, eight
evidence records, and eight resolutions all point to the immutable Infra plan
asset and its JSON pointers. The public Infra replay is a source replay
receipt; the workflow separately compares all eight envelope files.

The workflow then creates four actual evaluator reports from the same bundle:

1. A missing Core receipt yields `UNKNOWN` with `DIRECT_MISSING` at the
   missing activity and `DEPENDENCY_BLOCKED` on downstream cells, preserving
   the minimal dependency frontier.
2. A valid Core `UNKNOWN` receipt yields `UNKNOWN` with all six coordinates:
   `stage`, `step`, `reason`, `unknown_class`, `next_operation`, and
   `blocked_by`.
3. A malformed `UNKNOWN` receipt yields `REFUTED`.
4. A `FIXED_POINT` receipt yields `REFUTED`.
5. An unrecognized top-level decision yields `REFUTED`.

Only after those reports are hashed are their report digests merged into the
facts file. The final normal evaluator then runs from the merged facts. This
prevents a counterexample report from being asserted using a digest produced
after the assertion itself.

Core `UNKNOWN` is accepted only when the decision is `UNKNOWN`, claim state is
`UNKNOWN`, occurrences are zero, the reason is `ACTIVITY_NOT_FOUND`, all six
coordinates are valid, and `blocked_by` is an array. Missing, malformed, or
unrecognized Core receipts are never converted to zero; they remain
`UNKNOWN` or `REFUTED` as specified by the report. Unobserved values are
`null` or `UNOBSERVED`, not zero.

## Acceptance targets

The PR CI reports the following observed targets independently:

| Measure | Target |
|---|---:|
| Product projection | 1/1 |
| Envelope files | 8/8 |
| Relations / evidence / resolutions | 8/8/8 |
| Kit conformer checks | 10/10 |
| Source replay / file replay | 1/1 / 8/8 |
| Normal / UNKNOWN / REFUTED paths | at least 1/2/1 |
| UNKNOWN coordinates | 6 |
| Meta cells | 12/12 |
| Proof and indicator class cells | 4/4/4 each |
| Repository writes / local tests / cross-project gates | 0/0/0 |
| Kit source checkout / conformer copy | 0/0 |
| Released adoption | 0/1 UNKNOWN |
| External utility | 0/1 UNKNOWN |
| Exact before/after improvement | 0/1 UNKNOWN |

CI also records the actual Go `1.27.x` version, physical Go and Gooo lines
per file, regular files, descendant directories, module roots, empty go-fix
roots, peak RSS KiB, and wall milliseconds. The repository-root README is
excluded from those inventory counts.

## Increment and portfolio disposition

This candidate fits in one PR to the existing `gooo-infra-evidence` release
line: one Infra-specific denominator, one release lock, one product-owned
projector/evaluator pair, one Gooo activity program, and one workflow. A new
repository would be warranted only if the envelope becomes a reusable
cross-product consumer with independent lifecycle, external utility evidence,
or authority that cannot remain Infra read-only. Those conditions are not
observed here.

The current-run source observation records the released v0.8 plan's six
activities, eight typed dependencies, four dependency kinds, six prior
semantic edges, one OpenAPI binding, one Terraform binding, and four
deployment-chain cells. These values are read from the immutable plan asset;
they are not closed by Gooo declarations alone.

Disposition: **DEFER** pending released adoption and user-supplied external
utility evidence. Exact before/after improvement is also `0/1 UNKNOWN` before
release. The implementation is not a Terraform/HCL runtime,
OpenAPI Generator template, provider, deployment executor, or cross-project
CI gate.
