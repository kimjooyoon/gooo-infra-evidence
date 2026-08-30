# OpenTofu receipt V1

## User question

This vertical slice answers one exact question:

> Did this Infra Evidence run observe the pinned OpenTofu release as OpenTofu,
> through a machine-readable released CLI receipt, without inferring the
> engine from Terraform-compatible JSON keys?

The user path is fixed to four operations: verify the pinned release asset,
execute `tofu version -json`, publish an explicit engine receipt, and replay
the observation. The official OpenTofu version command documents `-json` as
machine-readable output. Its compatibility key remains `terraform_version`;
that key is recorded but never used as the source of engine identity.

## Fixed semantic denominator

The denominator is exactly twelve cells and twelve Gooo activities. Cells
1-4 are FOUNDATION/DRIVER, 5-8 are COHERENCE/OUTCOME, and 9-12 are
REGRESSION/GUARDRAIL. The cells cover released Gooo authority, the pinned
OpenTofu release and asset, binary digest, version JSON execution, explicit
engine identity, receipt publication, deterministic replay, UNKNOWN
causality, refuted counterexamples, and read-only authority.

The normal case is `12/12 CLOSED`. A missing release receipt is executed and
preserved as one `DIRECT_MISSING` claim plus one `DEPENDENCY_BLOCKED` claim,
each with `stage`, `step`, `reason`, `unknown_class`, `next_operation`, and
`blocked_by`. A binary digest contradiction and an explicit `UNKNOWN` engine
are executed as two REFUTED cases. REFUTED is never converted to UNKNOWN.

## Immutable inputs and output

The lock pins Gooo Core `v0.4.0-dev` and OpenTofu `v1.12.6` by release id,
tag target, asset id, size, and SHA-256. CI checks OpenTofu's official
`SHA256SUMS` entry before executing the binary. It writes exactly seven files
to caller-owned temporary output:

1. `manifest.json`
2. `opentofu-release-receipt.json`
3. `opentofu-version-first.json`
4. `opentofu-version-replay.json`
5. `opentofu-adoption-receipt.json`
6. `opentofu-report.md`
7. `conformance.json`

The manifest binds the other six files by digest. A final consumer recomputes
the exact file set and every listed SHA-256.

## Execution and non-claims

CI executes only `tofu version -json`, exactly twice. OpenTofu source
checkout, build, init, plan, apply, test, provider access, and cloud access
are all zero. Runtime network access is not inferred as zero: it is
unauthorized, unclaimed, and recorded as unobserved. The two official release
asset downloads are counted separately from OpenTofu runtime behavior.

The receipt records first/replay wall time as ceiling milliseconds and peak
RSS KiB, plus repository regular files, descendant directories, per-file Go
and Gooo physical lines, and root README exclusion. Released binary reuse is
`1/1`; no source build or test receipt reuse is claimed. Time saved and exact
improvement remain UNKNOWN without a same-condition before/after pair.

OpenTofu adoption is `1/1 CLOSED` for this exact receipt path. Release adoption
of the new Infra feature, independent external utility, and exact improvement
remain `0/1 UNKNOWN` until separate evidence exists.
