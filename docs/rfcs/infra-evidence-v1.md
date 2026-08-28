# RFC: Gooo Infra Evidence v1

Status: Experimental captured-receipt vertical slice

## Decision

The first slice evaluates one service evidence chain without applying
infrastructure or contacting a runtime. Every fixture is a captured receipt.
Gooo binds their identities and preserves uncertainty boundaries.

## State separation

Terraform declaration, plan, and state are independent evidence. A plan does
not prove apply; state does not prove current cloud reality; deployment output
does not prove runtime health. OpenAPI validity does not prove implementation.

The complete fixture closes twelve fixed cells. If state is absent,
TERRAFORM_STATE is `UNKNOWN / DIRECT_MISSING`. DEPLOYMENT_OUTPUT and
RUNTIME_DRIFT_REGRESSION become `UNKNOWN / DEPENDENCY_BLOCKED`, preserving the
blocking cell. A deployment artifact mismatch is observed contradiction and is
therefore REFUTED, not UNKNOWN.

## Proof choices

FOUNDATION fixes released compiler identity and declarations. COHERENCE joins
plan, state, source, artifact, deployment, and policy identities. REGRESSION
requires two runtime receipts and a read-only effect observation.

## Non-claims

- Terraform execution and validation: NOT_CLAIMED
- Live cloud state: NOT_CLAIMED
- Live network probe: NOT_CLAIMED
- Publisher signatures: NOT_CLAIMED
- Source-span binding: NOT_AVAILABLE

Future adapters may replace captured fixtures with authenticated tool receipts
without changing the claim-state rules.
