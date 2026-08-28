# Semantic Deployment Plan v1

## Decision

Infra Evidence exposes one read-only deployment-planning path whose semantic authority is a Gooo program.
The product invokes the released Core v0.4 claim-dependency primitive and projects an immutable Infra v0.7 deployment-contract receipt into JSON and Markdown.

The plan describes structural dependency and previously observed bindings. It does not deploy a service, apply Terraform, probe a network, mutate a repository, or claim external utility.

## User path

The generator accepts a released Gooo executable, one deployment program, four primitive conformance fixtures, one packet contract, one released deployment-contract report, and an output directory outside the source repository.
It emits `deployment-plan.json`, `deployment-plan.md`, and five released-command receipts.

The normal example contains six deployment activities and eight typed dependencies. Its dependency-kind counts are requires 3, supports 2, contradicts 2, and failure-entailment 1.
The plan also preserves exact prior evidence: 15/15 contract cells, 3/3 generated artifacts, 6/6 semantic edges, 1/1 OpenAPI binding, 1/1 Terraform binding, and 4/4 deployment-chain cells.

## Recovery and refusal

A missing producer lowers resolution to UNKNOWN and preserves six coordinates: stage, step, reason, unknown_class, next_operation, and blocked_by.
Unsupported dependency kinds, ambiguous producers, and cycles fail closed as REFUTED.
A changed prior-release receipt, missing Gooo meta activity, unevidenced utility claim, or execution-authority escalation also fails closed.

## Measurement

Conformance and utility are separate. Conformance is CLOSED declared cells divided by twelve declared cells. Utility is externally evidenced use cases divided by one declared use case.
This release closes the generated example but reports external utility as 0/1 UNKNOWN.

CI publishes exact activity, dependency, prior-evidence, artifact, replay, source-line, directory, file, time, memory, write, local-test, and cross-project-gate counts. The repository root README remains excluded.

## Portfolio boundary

This product consumes immutable Core and Infra releases but creates no required gate for either project. Local project management, design-system matching, and future infrastructure generators may consume the same primitive independently, so one vertical cannot block another.

