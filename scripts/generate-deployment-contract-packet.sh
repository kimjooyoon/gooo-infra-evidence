#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 15; then
  echo "usage: generate-deployment-contract-packet.sh GRAPH DENOMINATOR REQUEST INFRA_DIR ADOPTION_DIR READY_RECEIPT MISSING_RECEIPT DRIFT_RECEIPT HANDLER_RECEIPT AUTHORITY_RECEIPT CONTRACT MANIFEST RUNBOOK SUBJECT_SHA SCENARIO" >&2
  exit 2
fi

graph=$1
denominator=$2
request=$3
infra_dir=$4
adoption_dir=$5
ready_receipt=$6
missing_receipt=$7
drift_receipt=$8
handler_receipt=$9
authority_receipt=${10}
contract=${11}
manifest=${12}
runbook=${13}
subject_sha=${14}
scenario=${15}

infra_report="$infra_dir/infra-service-claim.json"
hcl_receipt="$infra_dir/hcl-declaration.json"
service_receipt="$infra_dir/service-symbol.json"
infra_runtime="$infra_dir/runtime-v2.json"
adoption_report="$adoption_dir/report.json"
adoption_runtime="$adoption_dir/runtime.json"
claim_closed="$adoption_dir/receipts/ResolveReleasedClosedClaim.json"
claim_unknown="$adoption_dir/receipts/BindReleasedUnknownClaim.json"
claim_refuted="$adoption_dir/receipts/BindReleasedRefutedClaim.json"

for file in "$graph" "$denominator" "$request" "$infra_report" "$hcl_receipt" "$service_receipt" \
  "$infra_runtime" "$adoption_report" "$adoption_runtime" "$claim_closed" "$claim_unknown" "$claim_refuted" \
  "$ready_receipt" "$missing_receipt" "$drift_receipt" "$handler_receipt" "$authority_receipt"; do
  test -f "$file" || { echo "missing deployment packet input: $file" >&2; exit 2; }
done

case "$scenario" in
  complete|missing-state|artifact-drift|handler-ambiguity|authority-escalation) ;;
  *) echo "unsupported deployment packet scenario: $scenario" >&2; exit 2 ;;
esac

jq -e '
  .schema=="gooo/infra-evidence/deployment-contract-packet-denominator/v1" and
  .candidate_id=="gooo.product.infra-deployment-contract-packet.v1" and
  .total==15 and (.cells|length)==15 and
  ([.proofs[].total]|add)==15 and ([.indicator_classes[].total]|add)==15
' "$denominator" >/dev/null
jq -e --slurpfile denominator "$denominator" '
  . as $graph | .schema_version=="gooo-graph/v1" and
  ([$graph.nodes[]|select(.kind=="Activity")]|length)==15 and
  ([$denominator[0].cells[] as $cell |
    select(([$graph.nodes[]|select(.kind=="Activity" and .name==$cell.activity)]|length)==1)
  ]|length)==15
' "$graph" >/dev/null

validate_request() {
  local execution=$1
  jq -e --argjson execution "$execution" '
    .schema=="gooo/infra-deployment-review-request/v1" and
    .request_id=="checkout-prod-deployment-contract-v1" and .project_id=="checkout://service/v2" and
    .environment=="prod" and .owner=="checkout-service" and .reviewer=="platform-runtime" and
    .expected=={artifact_digest:"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      deployment_target:"prod/checkout",go_handler:"health",openapi_method:"GET",openapi_operation:"getHealth",
      openapi_path:"/health",terraform_resource:"example_service.checkout"} and
    .required_outputs==["deployment-contract.json","deployment-generation-manifest.json","deployment-runbook.md"] and
    .policy=={allowed_refuted_cells:0,required_infra_cells:12,required_runtime_observations:2,required_semantic_edges:6} and
    .authority.terraform_apply_authorized==$execution and
    .authority.deployment_execution_authorized==$execution and
    .authority.network_probe_authorized==false and .authority.repository_writes_authorized==false and
    .authority.cross_project_required_gates==0
  ' "$request" >/dev/null
}

validate_meta_receipt() {
  local file=$1 activity=$2 state=$3 stage=$4 step=$5 reason=$6 unknown_class=$7 next_operation=$8
  jq -e --arg activity "$activity" --arg state "$state" --arg stage "$stage" --arg step "$step" \
    --arg reason "$reason" --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.activity_occurrences==1 and
    .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and .claim.state==$state and
    .claim.stage==(if $stage=="NONE" then null else $stage end) and
    .claim.step==(if $step=="NONE" then null else $step end) and .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and .summary.fields_observed==6 and .summary.fields_total==6 and
    .summary.repository_writes==0 and .authority.source=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .authority.core_mutation_authorized==false
  ' "$file" >/dev/null
}

validate_released_claim() {
  local file=$1 activity=$2 state=$3 reason=$4 unknown_class=$5 next_operation=$6
  jq -e --arg activity "$activity" --arg state "$state" --arg reason "$reason" \
    --arg unknown_class "$unknown_class" --arg next_operation "$next_operation" '
    .schema=="gooo/claim-resolution/v1" and .decision=="CLAIM_RESOLUTION_OBSERVED" and
    .subject.activity==$activity and .subject.binding=="GOOO_ACTIVITY_VALUE_PROGRAM" and
    .claim.state==$state and .claim.reason==$reason and
    .claim.unknown_class==(if $unknown_class=="NONE" then null else $unknown_class end) and
    .claim.next_operation==$next_operation and .summary.fields_observed==6 and .summary.fields_total==6
  ' "$file" >/dev/null
}

validate_meta_receipt "$ready_receipt" ResolveDeploymentPacketReady CLOSED NONE NONE INFRA_DEPLOYMENT_CONTRACT_PACKET_GENERATED NONE NONE
validate_meta_receipt "$missing_receipt" PreserveMissingStateUnknown UNKNOWN INFRA_STATE BIND_TERRAFORM_STATE TERRAFORM_STATE_UNAVAILABLE DIRECT_MISSING PROVIDE_TERRAFORM_STATE_RECEIPT
validate_meta_receipt "$drift_receipt" RefuteArtifactIdentityDrift REFUTED DEPLOYMENT BIND_DEPLOYMENT_OUTPUT ARTIFACT_IDENTITY_MISMATCH NONE RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY
validate_meta_receipt "$handler_receipt" RefuteHandlerAmbiguity REFUTED SERVICE_SYMBOL BIND_OPENAPI_OPERATION_TO_GO_HANDLER GO_HANDLER_REGISTRATION_CARDINALITY_MISMATCH NONE RESTORE_UNIQUE_METHOD_PATH_REGISTRATION
validate_meta_receipt "$authority_receipt" RefuteExecutionAuthority REFUTED AUTHORITY BIND_DEPLOYMENT_PACKET_AUTHORITY EXECUTION_AUTHORITY_ESCALATED NONE REMOVE_APPLY_AND_DEPLOY_AUTHORITY

jq -e '
  .schema=="gooo/infra-evidence/hcl-declaration-receipt/v1" and .decision=="CLOSED" and
  .binding.resource_address=="example_service.checkout" and .binding.target=="prod/checkout" and
  .binding.image_digest=="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" and
  .authority.parser_module=="github.com/hashicorp/hcl/v2" and .authority.parser_version=="v2.24.0" and
  .authority.terraform_execution=="NOT_USED" and .authority.source_mutation=="NONE"
' "$hcl_receipt" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/service-symbol-receipt/v1" and .decision=="CLOSED" and
  .binding.openapi_method=="GET" and .binding.openapi_path=="/health" and
  .binding.openapi_operation=="getHealth" and .binding.service_handler=="health" and
  .authority.go_syntax=="go/parser" and .authority.network=="NOT_USED" and .authority.source_mutation=="NONE"
' "$service_receipt" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/runtime-observation/v2" and .release_identity_observed==true and
  .go_toolchain.version=="go1.27.0" and .performance.graph_peak_rss_kib==11000 and
  .performance.graph_wall_ms==111 and .performance.hcl_parser_peak_rss_kib==8472 and
  .performance.hcl_parser_wall_ms==3 and .repository.writes==0
' "$infra_runtime" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/claim-resolution-adoption-report/v1" and
  .decision=="ADOPTION_EVIDENCE_CLOSED" and .summary.closed==12 and .summary.total==12 and
  .adoption.activities_bound==12 and .adoption.released_scenarios==3 and
  .adoption.released_claim_fields==18 and .adoption.core_claim_fields==18 and
  .adoption.invalid_tuples_rejected==2 and .authority.cross_project_required_gates==0 and
  .authority.local_test_executions==0 and .authority.repository_writes==0
' "$adoption_report" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/claim-resolution-adoption-runtime/v1" and
  .performance.claim_resolve_peak_rss_kib==10576 and .performance.claim_resolve_wall_ms==24 and
  .process.unique_activities==12 and .process.valid_receipts==10 and .process.invalid_receipts==2 and
  .repository.writes==0 and .authority.cross_project_required_gates==0 and .authority.local_test_executions==0
' "$adoption_runtime" >/dev/null
validate_released_claim "$claim_closed" ResolveReleasedClosedClaim CLOSED INFRA_SERVICE_SYMBOL_EVIDENCE_CHAIN_CLOSED NONE NONE
validate_released_claim "$claim_unknown" BindReleasedUnknownClaim UNKNOWN HCL_RESOURCE_VALUE_UNRESOLVED CONTEXT_MISSING PROVIDE_HCL_EVALUATION_CONTEXT
validate_released_claim "$claim_refuted" BindReleasedRefutedClaim REFUTED ARTIFACT_IDENTITY_MISMATCH NONE RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY

case "$scenario" in
  complete)
    validate_request false
    jq -e '.schema=="gooo/infra-evidence/report/v2" and .decision=="EVIDENCE_CHAIN_CLOSED" and .summary=={closed:12,dependency_blocked:0,direct_missing:0,refuted:0,repository_writes:0,total:12,unknown:0}' "$infra_report" >/dev/null
    resolution=$ready_receipt
    ;;
  missing-state)
    validate_request false
    jq -e '.phase=="missing-state" and .decision=="INCOMPLETE" and .claim.reason=="TERRAFORM_STATE_UNAVAILABLE" and .claim.unknown_class=="DIRECT_MISSING" and .summary.closed==9 and .summary.unknown==3' "$infra_report" >/dev/null
    resolution=$missing_receipt
    ;;
  artifact-drift)
    validate_request false
    jq -e '.phase=="deployment-drift" and .decision=="FAIL_CLOSED" and .claim.reason=="ARTIFACT_IDENTITY_MISMATCH" and .summary.closed==10 and .summary.refuted==2' "$infra_report" >/dev/null
    resolution=$drift_receipt
    ;;
  handler-ambiguity)
    validate_request false
    jq -e '.phase=="ambiguous-handler" and .decision=="FAIL_CLOSED" and .claim.reason=="GO_HANDLER_REGISTRATION_CARDINALITY_MISMATCH" and .summary.closed==8 and .summary.refuted==4' "$infra_report" >/dev/null
    resolution=$handler_receipt
    ;;
  authority-escalation)
    validate_request true
    jq -e '.schema=="gooo/infra-evidence/report/v2" and .decision=="EVIDENCE_CHAIN_CLOSED" and .summary.closed==12' "$infra_report" >/dev/null
    resolution=$authority_receipt
    ;;
esac

digest() { printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"; }

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile request "$request" --slurpfile infra "$infra_report" \
  --slurpfile hcl "$hcl_receipt" --slurpfile service "$service_receipt" \
  --slurpfile adoption "$adoption_report" --slurpfile claim_closed "$claim_closed" \
  --slurpfile claim_unknown "$claim_unknown" --slurpfile claim_refuted "$claim_refuted" \
  --slurpfile resolution "$resolution" --slurpfile ready "$ready_receipt" --slurpfile missing "$missing_receipt" \
  --slurpfile drift "$drift_receipt" --slurpfile handler "$handler_receipt" --slurpfile authority "$authority_receipt" \
  --arg scenario "$scenario" --arg subject_sha "$subject_sha" --arg graph_digest "$(digest "$graph")" \
  --arg denominator_digest "$(digest "$denominator")" --arg request_digest "$(digest "$request")" \
  --arg infra_digest "$(digest "$infra_report")" --arg hcl_digest "$(digest "$hcl_receipt")" \
  --arg service_digest "$(digest "$service_receipt")" --arg adoption_digest "$(digest "$adoption_report")" \
  --arg claim_closed_digest "$(digest "$claim_closed")" --arg claim_unknown_digest "$(digest "$claim_unknown")" \
  --arg claim_refuted_digest "$(digest "$claim_refuted")" '
  $denominator[0] as $d | $request[0] as $request | $infra[0] as $infra |
  [$claim_closed[0],$claim_unknown[0],$claim_refuted[0] |
    {activity:.subject.activity,claim:.claim,fields_observed:.summary.fields_observed,binding:.subject.binding}
  ] | sort_by(.activity) as $claim_tuples |
  [$ready[0],$missing[0],$drift[0],$handler[0],$authority[0] |
    {activity:.subject.activity,claim:.claim,fields_observed:.summary.fields_observed,binding:.subject.binding}
  ] | sort_by(.activity) as $decision_receipts |
  [$d.cells[] | .id as $cell_id |
    {id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
      reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]} |
    if $scenario=="missing-state" and $cell_id=="TERRAFORM_BINDING_PROJECTED" then
      .+{state:"UNKNOWN",stage:"INFRA_STATE",step:"BIND_TERRAFORM_STATE",reason:"TERRAFORM_STATE_UNAVAILABLE",
        unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_TERRAFORM_STATE_RECEIPT",blocked_by:["terraform-state"]}
    elif $scenario=="missing-state" and (["ARTIFACT_DEPLOYMENT_CHAIN","GENERATED_PACKET_ARTIFACTS","PACKET_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"UNKNOWN",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_EVIDENCE_UNAVAILABLE",
        unknown_class:"DEPENDENCY_BLOCKED",next_operation:"PROVIDE_TERRAFORM_STATE_RECEIPT",
        blocked_by:["TERRAFORM_BINDING_PROJECTED"]}
    elif $scenario=="artifact-drift" and $cell_id=="ARTIFACT_DEPLOYMENT_CHAIN" then
      .+{state:"REFUTED",stage:"DEPLOYMENT",step:"BIND_DEPLOYMENT_OUTPUT",reason:"ARTIFACT_IDENTITY_MISMATCH",
        next_operation:"RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY",blocked_by:["deployment-receipt"]}
    elif $scenario=="artifact-drift" and (["GENERATED_PACKET_ARTIFACTS","PACKET_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY",blocked_by:["ARTIFACT_DEPLOYMENT_CHAIN"]}
    elif $scenario=="handler-ambiguity" and $cell_id=="OPENAPI_SERVICE_BINDING" then
      .+{state:"REFUTED",stage:"SERVICE_SYMBOL",step:"BIND_OPENAPI_OPERATION_TO_GO_HANDLER",
        reason:"GO_HANDLER_REGISTRATION_CARDINALITY_MISMATCH",next_operation:"RESTORE_UNIQUE_METHOD_PATH_REGISTRATION",
        blocked_by:["service-symbol-receipt"]}
    elif $scenario=="handler-ambiguity" and (["ARTIFACT_DEPLOYMENT_CHAIN","GENERATED_PACKET_ARTIFACTS","PACKET_READY_DECISION"]|index($cell_id))!=null then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:.activity,reason:"DEPENDENCY_REFUTED",
        next_operation:"RESTORE_UNIQUE_METHOD_PATH_REGISTRATION",blocked_by:["OPENAPI_SERVICE_BINDING"]}
    elif $scenario=="authority-escalation" and $cell_id=="PACKET_AUTHORITY_BOUND" then
      .+{state:"REFUTED",stage:"AUTHORITY",step:"BIND_DEPLOYMENT_PACKET_AUTHORITY",
        reason:"EXECUTION_AUTHORITY_ESCALATED",next_operation:"REMOVE_APPLY_AND_DEPLOY_AUTHORITY",
        blocked_by:["deployment-review-request.json"]}
    elif $scenario=="authority-escalation" and $cell_id=="PACKET_READY_DECISION" then
      .+{state:"REFUTED",stage:"DEPENDENCY",step:"RESOLVE_DEPLOYMENT_PACKET_READY",reason:"DEPENDENCY_REFUTED",
        next_operation:"REMOVE_APPLY_AND_DEPLOY_AUTHORITY",blocked_by:["PACKET_AUTHORITY_BOUND"]}
    else . end
  ] as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (if $scenario=="missing-state" then 0 else 1 end) as $terraform_binding |
  (if $scenario=="handler-ambiguity" then 0 else 1 end) as $service_binding |
  (if $scenario=="complete" or $scenario=="authority-escalation" then 4
    elif $scenario=="artifact-drift" then 3 else 2 end) as $chain_cells |
  (if $scenario=="complete" then 3 else 0 end) as $publishable |
  (if $scenario=="missing-state" then ["terraform-state"]
    elif $scenario=="artifact-drift" then ["deployment-receipt"]
    elif $scenario=="handler-ambiguity" then ["service-symbol-receipt"]
    elif $scenario=="authority-escalation" then ["deployment-review-request.json"] else [] end) as $blocked_by |
  {
    schema:"gooo/infra-evidence/deployment-contract-packet/v1",scenario:$scenario,subject_sha:$subject_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "DEPLOYMENT_CONTRACT_PACKET_UNKNOWN" else "DEPLOYMENT_CONTRACT_PACKET_GENERATED" end),
    candidate:{id:$d.candidate_id,state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "GENERATED" end)},
    claim:($resolution[0].claim+{blocked_by:$blocked_by}),
    request:{id:$request.request_id,project_id:$request.project_id,environment:$request.environment,
      owner:$request.owner,reviewer:$request.reviewer},
    summary:{total_cells:15,closed_cells:$closed,unknown_cells:$unknown_count,refuted_cells:$refuted_count,
      release_inputs_total:3,release_inputs_observed:3,infra_evidence_cells_total:12,
      infra_evidence_cells_closed:$infra.summary.closed,infra_evidence_cells_unknown:$infra.summary.unknown,
      infra_evidence_cells_refuted:$infra.summary.refuted,claim_adoption_cells_total:12,claim_adoption_cells_closed:12,
      terraform_bindings_total:1,terraform_bindings_observed:$terraform_binding,
      openapi_service_bindings_total:1,openapi_service_bindings_observed:$service_binding,
      semantic_edges_total:6,semantic_edges_observed:(if $scenario=="handler-ambiguity" then 5 else 6 end),
      deployment_chain_cells_total:4,deployment_chain_cells_closed:$chain_cells,
      released_claim_tuples_total:3,released_claim_tuples_observed:3,released_claim_fields_total:18,released_claim_fields_observed:18,
      meta_decision_receipts_total:5,meta_decision_receipts_observed:5,meta_decision_fields_total:30,meta_decision_fields_observed:30,
      generated_artifacts_total:3,generated_artifacts_observed:3,publishable_artifacts:$publishable,
      counterexamples_total:4,counterexamples_observed:4,repository_writes:0,local_tests_run:0,cross_project_required_gates:0},
    bindings:{terraform:{resource_address:$hcl[0].binding.resource_address,target:$hcl[0].binding.target,
        artifact_digest:$hcl[0].binding.image_digest,state:(if $terraform_binding==1 then "BOUND" else "UNKNOWN" end)},
      service:{method:$service[0].binding.openapi_method,path:$service[0].binding.openapi_path,
        operation:$service[0].binding.openapi_operation,handler:$service[0].binding.service_handler,
        state:(if $service_binding==1 then "BOUND" else "REFUTED" end)}},
    claim_tuples:$claim_tuples,decision_receipts:$decision_receipts,
    authority:{meta_source:"examples/deployment-contract-packet/main.gooo",resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",
      terraform_apply_authorized:$request.authority.terraform_apply_authorized,
      deployment_execution_authorized:$request.authority.deployment_execution_authorized,
      network_probe_authorized:$request.authority.network_probe_authorized,
      repository_writes_authorized:$request.authority.repository_writes_authorized,
      cross_project_required_gates:$request.authority.cross_project_required_gates,
      central_orchestration_authorized:false},
    evidence:{graph_digest:$graph_digest,denominator_digest:$denominator_digest,request_digest:$request_digest,
      infra_digest:$infra_digest,hcl_digest:$hcl_digest,service_digest:$service_digest,
      adoption_digest:$adoption_digest,claim_closed_digest:$claim_closed_digest,
      claim_unknown_digest:$claim_unknown_digest,claim_refuted_digest:$claim_refuted_digest},
    cells:$cells,
    proofs:[$d.proofs[] as $proof|{choice:$proof.choice,total:$proof.total,
      closed:([$cells[]|select(.proof_choice==$proof.choice and .state=="CLOSED")]|length)}],
    indicator_classes:[$d.indicator_classes[] as $class|{class:$class.class,total:$class.total,
      closed:([$cells[]|select(.indicator_class==$class.class and .state=="CLOSED")]|length)}],
    indicators:[
      {id:"gooo.metric.infra-packet.evidence-cells.v1",class:"DRIVER",value:$infra.summary.closed,total:12,unit:"cells",activity:"ObserveInfraEvidenceRelease"},
      {id:"gooo.metric.infra-packet.terraform-bindings.v1",class:"OUTCOME",value:$terraform_binding,total:1,unit:"bindings",activity:"ProjectTerraformDeploymentBinding"},
      {id:"gooo.metric.infra-packet.openapi-service-bindings.v1",class:"OUTCOME",value:$service_binding,total:1,unit:"bindings",activity:"ProjectOpenAPIServiceBinding"},
      {id:"gooo.metric.infra-packet.deployment-chain.v1",class:"OUTCOME",value:$chain_cells,total:4,unit:"cells",activity:"ProjectArtifactDeploymentChain"},
      {id:"gooo.metric.infra-packet.claim-tuples.v1",class:"OUTCOME",value:3,total:3,unit:"tuples",activity:"ObserveClaimAdoptionRelease"},
      {id:"gooo.metric.infra-packet.generated-artifacts.v1",class:"OUTCOME",value:3,total:3,unit:"artifacts",activity:"GenerateDeploymentPacketArtifacts"},
      {id:"gooo.metric.infra-packet.publishable-artifacts.v1",class:"GUARDRAIL",value:$publishable,total:3,unit:"artifacts",activity:"ResolveDeploymentPacketReady"},
      {id:"gooo.metric.infra-packet.repository-writes.v1",class:"GUARDRAIL",value:0,total:0,unit:"writes",activity:"ObserveDeploymentPacketRuntime"}
    ]
  }
' > "$contract"

jq -S '{
  schema:"gooo/infra-evidence/deployment-generation-manifest/v1",
  scenario,subject_sha,decision,claim,request,
  targets:[
    {kind:"TERRAFORM_RESOURCE",locator:.bindings.terraform.resource_address,target:.bindings.terraform.target,
      artifact_digest:.bindings.terraform.artifact_digest,state:.bindings.terraform.state,operation:"GENERATE_CONFIGURATION_INPUT"},
    {kind:"OPENAPI_SERVICE",locator:(.bindings.service.method+" "+.bindings.service.path),
      operation_id:.bindings.service.operation,handler:.bindings.service.handler,state:.bindings.service.state,
      operation:"GENERATE_SERVICE_BINDING_INPUT"},
    {kind:"ARTIFACT_DEPLOYMENT_CHAIN",locator:.request.project_id,
      closed_cells:.summary.deployment_chain_cells_closed,total_cells:.summary.deployment_chain_cells_total,
      state:(if .summary.deployment_chain_cells_closed==.summary.deployment_chain_cells_total then "BOUND" else .candidate.state end),
      operation:"GENERATE_DEPLOYMENT_REVIEW_INPUT"}
  ],
  authority
}' "$contract" > "$manifest"

{
  echo '# Gooo Infrastructure Deployment Contract'
  echo
  jq -r '"- Decision: `\(.decision)`", "- Claim: `\(.claim.state)` / `\(.claim.reason)`", "- Project: `\(.request.project_id)`", "- Environment: `\(.request.environment)`", "- Publishable artifacts: \(.summary.publishable_artifacts)/3"' "$contract"
  echo
  echo '## Terraform binding'
  jq -r '"- `\(.bindings.terraform.resource_address)` -> `\(.bindings.terraform.target)`", "- artifact: `\(.bindings.terraform.artifact_digest)`", "- state: `\(.bindings.terraform.state)`"' "$contract"
  echo
  echo '## OpenAPI to service binding'
  jq -r '"- `\(.bindings.service.method) \(.bindings.service.path)` / `\(.bindings.service.operation)` -> `\(.bindings.service.handler)`", "- state: `\(.bindings.service.state)`"' "$contract"
  echo
  echo '## Deployment evidence chain'
  jq -r '"- infra evidence cells: \(.summary.infra_evidence_cells_closed)/\(.summary.infra_evidence_cells_total)", "- plan/state/build/deployment: \(.summary.deployment_chain_cells_closed)/\(.summary.deployment_chain_cells_total)", "- claim tuples: \(.summary.released_claim_tuples_observed)/\(.summary.released_claim_tuples_total) / fields \(.summary.released_claim_fields_observed)/\(.summary.released_claim_fields_total)"' "$contract"
  echo
  echo '## Resolution coordinates'
  jq -r '"- stage: `\(.claim.stage // "NONE")`", "- step: `\(.claim.step // "NONE")`", "- unknown class: `\(.claim.unknown_class // "NONE")`", "- next operation: `\(.claim.next_operation)`"' "$contract"
  echo
  echo '## Authority'
  jq -r '"- terraform apply: \(.authority.terraform_apply_authorized)", "- deployment execution: \(.authority.deployment_execution_authorized)", "- network probe: \(.authority.network_probe_authorized)", "- repository writes: \(.authority.repository_writes_authorized)", "- cross-project required gates: \(.authority.cross_project_required_gates)"' "$contract"
} > "$runbook"
