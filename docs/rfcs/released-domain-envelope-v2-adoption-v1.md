# Released-domain envelope v2 adoption candidate

## Scope and decision

This RFC proposes one Infra-only adoption candidate for the released-domain
envelope v2 consumer kit. It extends the already released semantic deployment
plan meaning: the eight typed Infra dependencies and the previously observed
OpenAPI, Terraform, and deployment-chain bindings are projected as released
declarations with evidence anchors. It does not execute Terraform or a
provider, generate an OpenAPI server, deploy anything, probe a network, or
claim semantic truth from a deterministic replay. It also does not import,
vendor, build, initialize, plan, apply, or test OpenTofu.

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

Infra owns the projected source evidence and the claim-resolution report. The
immutable consumer kit owns the project-envelope schema, so the emitted
`projection_owner` is the kit's required value rather than a relabeling of the
Infra evidence domain. The authority is exactly:

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

## OpenTofu receipt boundary

`INFRA_DEPENDENCY_SOURCE` keeps the released Terraform binding as Terraform:
it records `iac_engine: "TERRAFORM"` and
`reclassified_as_opentofu: false`. It is not an OpenTofu receipt, and the
project does not rename the fixture to claim an OpenTofu adoption.

OpenTofu is the preferred future candidate only at a stable JSON receipt
boundary. This is based on OpenTofu main declaring Go `1.27` in its
[module file](https://github.com/opentofu/opentofu/blob/main/go.mod), and its
[v1 compatibility promise](https://opentofu.org/docs/language/v1-compatibility-promises/)
that limits external automation compatibility to machine-readable JSON modes
and exit statuses. A supplied OpenTofu receipt must declare an explicit
`iac_engine` enum value (`OPENTOFU`, `TERRAFORM`, or `UNKNOWN`), plus
`iac_engine_version`, immutable release id, binary digest, and
`machine_readable_format_version`. Its engine is never inferred from
`terraform_version`: the [JSON format](https://opentofu.org/docs/internals/json-format/)
keeps that field name for compatibility. A submitted `UNKNOWN` engine or any
unrecognized top-level receipt state is `REFUTED`/fail-closed.

There is no immutable OpenTofu JSON receipt in this run. The product-specific
observation is therefore `opentofu_adoption: 0/1 UNKNOWN`, with
`next_operation: PROVIDE_IMMUTABLE_OPENTOFU_JSON_RECEIPT`. This observed
absence closes the existing `INFRA_DEPENDENCY_SOURCE` fact without treating
the absent adoption as zero evidence or relabeling Terraform.

OpenTofu access is fixed at zero for `init`, `plan`, `apply`, `test`, provider,
network, and cloud operations. This matters because
[`tofu test`](https://opentofu.org/docs/cli/commands/test/) creates and then
destroys real infrastructure by default. A future, separately opted-in fixture
may consider `command = plan`, `refresh = false`, and mock providers; it is
not part of this PR's conformance denominator or current-run counts.

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

The dependency graph is materialized by the Gooo graph, not self-looped
activities: each activity consumes the preceding activity output entity, and
the workflow observes the resulting `used`/`wasGeneratedBy` bindings. It
requires all twelve cell bindings and the exact denominator frontier before it
sets the graph-binding fact. Release observations precede the source and
projection; the envelope precedes conformance; conformance precedes the
causality and counterexample observations; the final authority cell consumes
all three regression outputs. Generic Interchange product cells and unrelated
Local or Design release cells are not in this denominator.

## Evidence and state rules

The normal run uses one current-run eight-file bundle, its bundle digest, its
eight-file replay, and the conformer report. The eight relations, eight
evidence records, and eight resolutions all point to the immutable Infra plan
asset and its JSON pointers. The public Infra replay is a source replay
receipt; the workflow separately compares all eight envelope files.

The workflow then creates exactly five actual evaluator reports from the same
bundle: one normal candidate is counted from conformer/replay evidence, two
UNKNOWN reports, and three REFUTED reports.

1. A missing Core receipt yields `UNKNOWN` with `DIRECT_MISSING` at the
   missing activity and `DEPENDENCY_BLOCKED` on downstream cells, preserving
   the minimal dependency frontier.
2. A valid Core `UNKNOWN` receipt and a focused downstream
   `PRODUCT_PROJECTION` claim yield `UNKNOWN` with the minimal
   `DEPENDENCY_BLOCKED` frontier and all six coordinates: `stage`, `step`,
   `reason`, `unknown_class`, `next_operation`, and `blocked_by`.
3. A malformed `UNKNOWN` receipt yields `REFUTED`.
4. A `FIXED_POINT` receipt yields `REFUTED`.
5. An unrecognized top-level decision yields `REFUTED`; the same report also
   contains an earlier valid UNKNOWN so the evaluator proves that its
   top-level claim selects `REFUTED` first.

Those five reports are the main-path denominator only. Two separate OpenTofu
boundary reports are not added to its `1/2/3` count: an explicit unknown
engine and an unrecognized receipt state each fail closed. The independent
guardrail is therefore `opentofu_boundary_cases=2/2`.

Only after those reports are hashed are their report digests merged into the
facts file. The final normal evaluator then runs from the merged facts. This
prevents a counterexample report from being asserted using a digest produced
after the assertion itself.

Core `UNKNOWN` is accepted only when the decision is `UNKNOWN`, claim state is
`UNKNOWN`, occurrences are zero, the reason is `ACTIVITY_NOT_FOUND`, all six
coordinates are valid, `unknown_class` is exactly `DIRECT_MISSING`, and
`blocked_by` is exactly `[]`. A downstream causal claim alone may be
`DEPENDENCY_BLOCKED`, with its smallest graph frontier. Missing, malformed, or
unrecognized Core receipts are never converted to zero; they remain
`UNKNOWN` or `REFUTED` as specified by the report. A REFUTED cell always wins
the report's top-level claim over an earlier UNKNOWN. Unobserved values are
`null` or `UNOBSERVED`, not zero; no phase label changes a null fact into a
closed fact. The `UNKNOWN coordinates=6` observation is calculated from the
two report claims' non-null `stage`, `step`, `reason`, `unknown_class`,
`next_operation`, and `blocked_by` fields, not assigned as a literal.

## Execution and receipt accounting

The runtime artifact separates current CI work from upstream release evidence.
`ci_build_executions=0`, `ci_build_wall_ms=0`, and
`ci_build_reason=NO_PRODUCT_BUILD_REQUIRED` state that this product does not
need a build. The current bundle records actual Core graph and resolution,
conformance, scenario, and replay execution and wall-time fields.
`current_subject_checks_executed` is the sum of those current-run checks; it
is not an upstream test count.

`upstream_test_receipts_available`, `upstream_test_receipts_reused`, and
`upstream_test_receipts_unknown`, and `stale_receipts` are distinct counters.
CI actually downloads and validates the immutable v0.8 semantic deployment
plan replay receipt, so it records `available=1`, `reused=0`, `unknown=1`,
and `stale=0`. Its subject, contract, and toolchain tuple digests are derived
from the lock and replay receipt. The receipt has no canonical command digest;
both command-digest fields therefore remain `null`, its reuse decision stays
`UNKNOWN`, and it is not reused. A receipt is reusable only when all four
tuple digests match current values. `reexecutions_skipped_due_to_exact_receipt`
may be counted later, but time saved and exact improvement remain `UNKNOWN`
until before/after evidence exists.

## Acceptance targets

The PR CI reports the following observed targets independently:

| Measure | Target |
|---|---:|
| Product projection | 1/1 |
| Envelope files | 8/8 |
| Relations / evidence / resolutions | 8/8/8 |
| Kit conformer checks | 10/10 |
| Source replay / file replay | 1/1 / 8/8 |
| Normal / UNKNOWN / REFUTED paths | exactly 1/2/3 |
| OpenTofu fail-closed boundary cases | 2/2, outside main path denominator |
| Upstream replay receipt: available / reused / unknown / stale | 1/0/1/0 |
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
