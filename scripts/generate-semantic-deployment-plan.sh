#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 9 ]; then
  echo "usage: generate-semantic-deployment-plan.sh GOOO PLAN MISSING UNSUPPORTED AMBIGUOUS CYCLE CONTRACT PRIOR_REPORT OUTPUT_DIR" >&2
  exit 64
fi

gooo=$1
plan=$2
missing=$3
unsupported=$4
ambiguous=$5
cycle=$6
contract=$7
prior=$8
output=$9

for required in "$gooo" "$plan" "$missing" "$unsupported" "$ambiguous" "$cycle" "$contract" "$prior"; do
  if [ ! -f "$required" ]; then
    echo "required input unavailable: $required" >&2
    exit 66
  fi
done

mkdir -p "$output/evidence"
closed_receipt="$output/evidence/closed.json"
missing_receipt="$output/evidence/missing-producer.json"
unsupported_receipt="$output/evidence/unsupported-kind.json"
ambiguous_receipt="$output/evidence/ambiguous-producer.json"
cycle_receipt="$output/evidence/cycle.json"

report_failure() {
  status=$?
  if [ "$status" -ne 0 ]; then
    echo "semantic deployment plan generation failed with status $status" >&2
    for receipt in "$closed_receipt" "$missing_receipt" "$unsupported_receipt" "$ambiguous_receipt" "$cycle_receipt"; do
      if [ -s "$receipt" ]; then
        echo "=== $receipt ===" >&2
        cat "$receipt" >&2
      fi
    done
  fi
}
trap report_failure EXIT

"$gooo" claim dependencies "$plan" --json > "$closed_receipt"

run_nonclosed() {
  source_file=$1
  receipt_file=$2
  set +e
  "$gooo" claim dependencies "$source_file" --json > "$receipt_file"
  command_status=$?
  set -e
  if [ "$command_status" -eq 0 ]; then
    echo "non-closed fixture was accepted: $source_file" >&2
    exit 65
  fi
}

run_nonclosed "$missing" "$missing_receipt"
run_nonclosed "$unsupported" "$unsupported_receipt"
run_nonclosed "$ambiguous" "$ambiguous_receipt"
run_nonclosed "$cycle" "$cycle_receipt"

jq -e --slurpfile contract "$contract" '
  .schema=="gooo/claim-dependency-causality/v1" and
  .candidate_id==$contract[0].primitive.id and
  .decision=="CLAIM_DEPENDENCY_OBSERVED" and
  .resolution.state=="CLOSED" and
  .resolution.reason=="CLAIM_DEPENDENCY_CAUSALITY_OBSERVED" and
  .summary.activities_total==$contract[0].normal.activities and
  .summary.activities_observed==$contract[0].normal.activities and
  .summary.recoverable_roots==$contract[0].normal.recoverable_roots and
  .summary.typed_declarations==$contract[0].normal.typed_declarations and
  .summary.dependency_inputs==$contract[0].normal.dependency_inputs and
  .summary.typed_edges==$contract[0].normal.dependencies and
  .summary.edge_kinds_observed==$contract[0].normal.edge_kinds and
  .summary.unresolved_inputs==0 and .summary.cyclic_activities==0 and .summary.repository_writes==0 and
  .kind_counts==$contract[0].normal.kind_counts and
  ([.nodes[].activity]==$contract[0].activity_order) and
  (.nodes|length)==6 and (.edges|length)==8 and (.gaps|length)==0 and
  (.indicators|length)==8 and
  all(.indicators[]; if .comparator=="EQ" then .value==.target elif .comparator=="GTE" then .value>=.target elif .comparator=="LTE" then .value<=.target else false end) and
  .authority.semantic_truth_claimed==false and .authority.state_propagation_authorized==false and
  .authority.core_mutation_authorized==false and .authority.automatic_merge_allowed==false and .authority.repository_writes==0
' "$closed_receipt" >/dev/null

jq -e --slurpfile contract "$contract" '
  .schema==$contract[0].prior_release.schema and
  .subject_sha==$contract[0].prior_release.target_commit_sha and
  .decision==$contract[0].prior_release.decision and
  .claim.state=="CLOSED" and
  .summary.closed_cells==$contract[0].prior_release.summary.contract_cells and
  .summary.total_cells==$contract[0].prior_release.summary.contract_cells and
  .summary.generated_artifacts_observed==$contract[0].prior_release.summary.generated_artifacts and
  .summary.generated_artifacts_total==$contract[0].prior_release.summary.generated_artifacts and
  .summary.semantic_edges_observed==$contract[0].prior_release.summary.semantic_edges and
  .summary.semantic_edges_total==$contract[0].prior_release.summary.semantic_edges and
  .summary.openapi_service_bindings_observed==$contract[0].prior_release.summary.openapi_bindings and
  .summary.openapi_service_bindings_total==$contract[0].prior_release.summary.openapi_bindings and
  .summary.terraform_bindings_observed==$contract[0].prior_release.summary.terraform_bindings and
  .summary.terraform_bindings_total==$contract[0].prior_release.summary.terraform_bindings and
  .summary.deployment_chain_cells_closed==$contract[0].prior_release.summary.deployment_chain_cells and
  .summary.deployment_chain_cells_total==$contract[0].prior_release.summary.deployment_chain_cells and
  .summary.repository_writes==0 and .summary.local_tests_run==0 and .summary.cross_project_required_gates==0 and
  .authority.deployment_execution_authorized==false and .authority.terraform_apply_authorized==false and
  .authority.network_probe_authorized==false and .authority.repository_writes_authorized==false
' "$prior" >/dev/null

jq -e --slurpfile contract "$contract" '
  .decision==$contract[0].unknown.decision and .resolution.state==$contract[0].unknown.state and
  .resolution.stage==$contract[0].unknown.stage and .resolution.step==$contract[0].unknown.step and
  .resolution.reason==$contract[0].unknown.reason and .resolution.unknown_class==$contract[0].unknown.unknown_class and
  .resolution.next_operation==$contract[0].unknown.next_operation and
  (.resolution.blocked_by|length)==$contract[0].unknown.blocked_by and .summary.unresolved_inputs==1
' "$missing_receipt" >/dev/null

jq -e '.decision=="FAIL_CLOSED" and .resolution.state=="REFUTED" and .resolution.reason=="CLAIM_DEPENDENCY_EDGE_KIND_UNSUPPORTED"' "$unsupported_receipt" >/dev/null
jq -e '.decision=="FAIL_CLOSED" and .resolution.state=="REFUTED" and .resolution.reason=="CLAIM_OUTPUT_PRODUCER_AMBIGUOUS"' "$ambiguous_receipt" >/dev/null
jq -e '.decision=="FAIL_CLOSED" and .resolution.state=="REFUTED" and .resolution.reason=="CLAIM_DEPENDENCY_CYCLE_DETECTED"' "$cycle_receipt" >/dev/null

source_sha=$(sha256sum "$plan" | awk '{print $1}')

jq -S -n \
  --slurpfile contract "$contract" \
  --slurpfile prior "$prior" \
  --slurpfile closed "$closed_receipt" \
  --slurpfile missing "$missing_receipt" \
  --slurpfile unsupported "$unsupported_receipt" \
  --slurpfile ambiguous "$ambiguous_receipt" \
  --slurpfile cycle "$cycle_receipt" \
  --arg source_sha "$source_sha" '
  {
    schema:"gooo/infra-evidence/semantic-deployment-plan/v1",
    decision:"DEPLOYMENT_PLAN_GENERATED",
    deployment:{
      id:$contract[0].deployment.id,
      name:$contract[0].deployment.name,
      source_path:$contract[0].deployment.source_path,
      source_sha256:$source_sha
    },
    primitive:$contract[0].primitive,
    prior_contract:{
      repository:$contract[0].prior_release.repository,
      tag:$contract[0].prior_release.tag,
      subject_sha:$prior[0].subject_sha,
      decision:$prior[0].decision,
      summary:{
        contract_cells:$prior[0].summary.closed_cells,
        generated_artifacts:$prior[0].summary.generated_artifacts_observed,
        semantic_edges:$prior[0].summary.semantic_edges_observed,
        openapi_bindings:$prior[0].summary.openapi_service_bindings_observed,
        terraform_bindings:$prior[0].summary.terraform_bindings_observed,
        deployment_chain_cells:$prior[0].summary.deployment_chain_cells_closed
      }
    },
    semantics:{scope:"STRUCTURAL_DEPLOYMENT_DEPENDENCY_ONLY",conformance_state:$closed[0].resolution.state,conformance_reason:$closed[0].resolution.reason},
    summary:{
      activities:$closed[0].summary.activities_observed,
      recoverable_roots:$closed[0].summary.recoverable_roots,
      dependencies:$closed[0].summary.typed_edges,
      dependency_kinds:$closed[0].summary.edge_kinds_observed,
      generated_artifacts:2,
      unknown_coordinates:$contract[0].unknown.coordinates,
      refuted_boundaries:($contract[0].refutations|length)
    },
    kind_counts:$closed[0].kind_counts,
    steps:[$closed[0].nodes[]|{ordinal,activity,output_entity,role,label,proof_choice,value_program_digest}],
    dependencies:[$closed[0].edges[]|{ordinal,id,kind,label,from_activity,to_activity,via_entity}],
    recovery:{
      decision:$missing[0].decision,state:$missing[0].resolution.state,stage:$missing[0].resolution.stage,
      step:$missing[0].resolution.step,reason:$missing[0].resolution.reason,
      unknown_class:$missing[0].resolution.unknown_class,next_operation:$missing[0].resolution.next_operation,
      blocked_by:$missing[0].resolution.blocked_by
    },
    refutation_boundaries:[
      {case:"unsupported-kind",reason:$unsupported[0].resolution.reason,state:$unsupported[0].resolution.state},
      {case:"ambiguous-producer",reason:$ambiguous[0].resolution.reason,state:$ambiguous[0].resolution.state},
      {case:"cycle",reason:$cycle[0].resolution.reason,state:$cycle[0].resolution.state}
    ],
    utility:$contract[0].utility,
    non_claims:$contract[0].non_claims,
    authority:{
      repository_mutation_authorized:false,automatic_repair_authorized:false,automatic_merge_allowed:false,
      deployment_execution_authorized:false,terraform_apply_authorized:false,network_probe_authorized:false,
      semantic_truth_claimed:false,state_propagation_authorized:false,cross_project_authority:false,repository_writes:0
    }
  }
' > "$output/deployment-plan.json"

{
  echo "# Semantic deployment plan"
  echo
  jq -r '"Deployment: **\(.deployment.name)**  \nDeployment ID: \(.deployment.id)  \nDecision: \(.decision)  \nScope: \(.semantics.scope)"' "$output/deployment-plan.json"
  echo
  echo "## Exact counts"
  echo
  jq -r '"- Activities: \(.summary.activities)/6\n- Dependencies: \(.summary.dependencies)/8\n- Dependency kinds: \(.summary.dependency_kinds)/4\n- Generated artifacts: \(.summary.generated_artifacts)/2\n- UNKNOWN coordinates: \(.summary.unknown_coordinates)/6\n- REFUTED boundaries: \(.summary.refuted_boundaries)/3"' "$output/deployment-plan.json"
  echo
  echo "## Prior released deployment evidence"
  echo
  jq -r '"- Contract cells: \(.prior_contract.summary.contract_cells)/15\n- Generated artifacts: \(.prior_contract.summary.generated_artifacts)/3\n- Semantic edges: \(.prior_contract.summary.semantic_edges)/6\n- OpenAPI bindings: \(.prior_contract.summary.openapi_bindings)/1\n- Terraform bindings: \(.prior_contract.summary.terraform_bindings)/1\n- Deployment chain: \(.prior_contract.summary.deployment_chain_cells)/4"' "$output/deployment-plan.json"
  echo
  echo "## Work steps"
  echo
  jq -r '.steps[] | "- \(.ordinal). \(.activity): \(.label) -> \(.output_entity)"' "$output/deployment-plan.json"
  echo
  echo "## Structural dependencies"
  echo
  jq -r '.dependencies[] | "- \(.id): \(.from_activity) --\(.kind) via \(.via_entity)--> \(.to_activity) [\(.label)]"' "$output/deployment-plan.json"
  echo
  echo "## UNKNOWN recovery"
  echo
  jq -r '"- Stage: \(.recovery.stage)\n- Step: \(.recovery.step)\n- Reason: \(.recovery.reason)\n- Class: \(.recovery.unknown_class)\n- Next operation: \(.recovery.next_operation)\n- Blocked by: \(.recovery.blocked_by | join(", "))"' "$output/deployment-plan.json"
  echo
  echo "## REFUTED boundaries"
  echo
  jq -r '.refutation_boundaries[] | "- \(.case): \(.state) / \(.reason)"' "$output/deployment-plan.json"
  echo
  echo "## External utility"
  echo
  jq -r '"- Evidence: \(.utility.evidenced_external_use_cases)/\(.utility.declared_external_use_cases)\n- State: \(.utility.state)\n- Reason: \(.utility.reason)"' "$output/deployment-plan.json"
  echo
  echo "## Non-claims"
  echo
  jq -r '.non_claims[] | "- \(.)"' "$output/deployment-plan.json"
} > "$output/deployment-plan.md"

