# RFC: Core v0.2 service-symbol evidence

Status: Experimental independent consumer

## Decision

This path adds evidence without replacing the v1 captured-receipt evaluator.
It consumes immutable Gooo v0.2.0-dev activity-resolution receipts and the
portable evidence generator v0.3.1-dev. The domain observer uses the Go AST to
bind one OpenAPI method, path, and operation to one Go handler definition,
HTTP signature, and registration.

The user-visible claim closes twelve cells with fixed totals:

- proof choices: FOUNDATION 4, COHERENCE 6, REGRESSION 2;
- indicator classes: DRIVER 5, OUTCOME 3, GUARDRAIL 4;
- semantic edges: declaration-to-plan, plan-to-state, OpenAPI-to-handler,
  handler-to-artifact, artifact-to-deployment, deployment-to-runtime: 6.

## Resolution loss

Missing build or Terraform state evidence is UNKNOWN, not success. The direct
cell reports stage, step, reason, unknown_class, and next_operation. Dependent
cells lower resolution to PREREQUISITE_CLASS and identify blocked_by cells.
An ambiguous Go route registration, a core release identity mismatch, or an
artifact contradiction is REFUTED and fails closed.

## Metaprogramming boundary

The Gooo activity is not a label attached after measurement. Released Gooo
resolves each activity selector, and the fixed denominator binds each domain
observation to that activity receipt. The Go AST observer is a replaceable
adapter; it cannot close a cell without the corresponding released Gooo
activity and its dependency predecessors.

## Independence and non-claims

This repository does not wait for the local-ledger or design-evidence
projects. It publishes its own claim and can fail without blocking either
project. Cross-project orchestration may consume released claims later, but is
not a readiness predecessor here.

Terraform execution, Terraform validation, live cloud state, deployment
execution, and live network probing remain NOT_CLAIMED. CI evaluates captured
receipts and performs zero source-repository writes.
