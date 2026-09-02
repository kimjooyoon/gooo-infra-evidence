#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 5 ]; then
  printf 'usage: generate-opentofu-service-contract-bridge.sh ROOT CASE ACTIONS_EVIDENCE OUTPUT_DIR SUBJECT_SHA\n' >&2
  exit 64
fi

root=$1
scenario=$2
actions_evidence=$3
output=$4
subject_sha=$5

base="$root/fixtures/opentofu-service-contract-bridge"
denominator="$root/contracts/opentofu-service-contract-bridge-denominator-v1.json"
lock="$root/contracts/opentofu-service-contract-bridge-release-lock-v1.json"
ontology="$root/contracts/opentofu-service-contract-bridge-mapping-ontology-v1.json"
plan="$base/inputs/plan.json"
state="$base/inputs/state.json"
openapi="$base/inputs/openapi.json"
mapping="$base/inputs/mapping.json"
metadata="$base/inputs/service-metadata.json"
case_file="$base/cases/$scenario/case.json"

case "$scenario" in
  normal|unknown) selected_mapping="$mapping" ;;
  refuted) selected_mapping="$base/cases/refuted/mapping.json" ;;
  *) printf 'unknown bridge scenario: %s\n' "$scenario" >&2; exit 65 ;;
esac

for required in "$denominator" "$lock" "$ontology" "$plan" "$state" "$openapi" "$mapping" "$selected_mapping" "$case_file" "$actions_evidence"; do
  test -f "$required" || { printf 'required bridge input unavailable: %s\n' "$required" >&2; exit 66; }
done

mkdir -p "$output"

digest() {
  printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"
}

verify_locked_hash() {
  local key=$1
  local path=$2
  local expected
  expected=$(jq -r --arg key "$key" '.inputs.files[$key].sha256' "$lock")
  test "$expected" != "null"; test "$expected" != "__${key^^}_SHA256__"
  test "${expected#sha256:}" = "$expected"
  test "$expected" = "$(sha256sum "$base/$path" | awk '{print $1}')"
}

verify_locked_hash plan inputs/plan.json
verify_locked_hash state inputs/state.json
verify_locked_hash openapi inputs/openapi.json
verify_locked_hash mapping inputs/mapping.json
verify_locked_hash refuted_mapping cases/refuted/mapping.json

metadata_present=false
metadata_service_id=null
metadata_digest=
if test -f "$metadata"; then
  verify_locked_hash service_metadata inputs/service-metadata.json
  jq -e '.schema=="gooo/infra-evidence/opentofu-service-contract-bridge/service-metadata/v1" and .metadata_is_optional==true' "$metadata" >/dev/null
  metadata_present=true
  metadata_service_id=$(jq -r '.service_id' "$metadata")
  metadata_digest=$(digest "$metadata")
fi

case_key="${scenario}_case"
case_path=$(jq -r --arg key "$case_key" '.inputs.files[$key].path' "$lock")
case_expected=$(jq -r --arg key "$case_key" '.inputs.files[$key].sha256' "$lock")
test "$case_path" = "cases/$scenario/case.json"
test "$case_expected" = "$(sha256sum "$base/$case_path" | awk '{print $1}')"

jq -e --arg scenario "$scenario" '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/case/v1" and
  .name==$scenario and .expected_mode != null
' "$case_file" >/dev/null

jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge-denominator/v1" and
  .target_cells==12 and (.cells|length)==12 and
  .decision_precedence==["REFUTED","UNKNOWN","CLOSED"] and
  .unknown_coordinate_fields==["stage","step","reason","unknown_class","next_operation","blocked_by"]
' "$denominator" >/dev/null

jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/mapping-ontology/v1" and
  .owner=="GOOO" and .name_similarity_mapping==false and
  (.relation_types|length)==5 and
  .unknown_policy.required_fields==["stage","step","reason","unknown_class","next_operation","blocked_by"]
' "$ontology" >/dev/null

jq -e '
  .format_version=="1.0" and .terraform_version=="1.12.6" and
  .errored==false and (.resource_changes|length)==1 and
  .resource_changes[0].address=="aws_lambda_function.checkout" and
  .resource_changes[0].provider_name=="registry.opentofu.org/hashicorp/aws" and
  .resource_changes[0].change.actions==["create"] and
  .configuration.root_module.resources[0].address=="aws_lambda_function.checkout"
' "$plan" >/dev/null

jq -e '
  .format_version=="1.0" and .terraform_version=="1.12.6" and
  .values.root_module.resources[0].address=="aws_lambda_function.checkout" and
  .values.root_module.resources[0].provider_name=="registry.opentofu.org/hashicorp/aws"
' "$state" >/dev/null

jq -e '
  .openapi=="3.0.3" and .paths["/checkout"].post.operationId=="createCheckout" and
  .paths["/checkout"].post["x-gooo-claim-id"]=="checkout.create"
' "$openapi" >/dev/null

jq -e '.schema=="gooo/infra-evidence/opentofu-service-contract-bridge/mapping/v1" and .authority=="GOOO_OWNED_EXPLICIT_MAPPING"' "$selected_mapping" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge-release-lock/v1" and
  .core.repository=="kimjooyoon/meta-ontology-go" and
  .opentofu.repository=="opentofu/opentofu" and .opentofu.iac_engine=="OPENTOFU" and
  .authority.repository_writes==0 and .authority.cross_project_required_gates==0 and
  .authority.opentofu_binary_executions==0 and .authority.opentofu_apply_executions==0
' "$lock" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/actions-evidence/v1" and
  .go_version=="go1.27.0" and .build.executions==0 and .test.executions==0 and
  .build.wall_ms==null and .build.peak_rss_kib==null and .build.cache_hit==null and
  .test.wall_ms==null and .test.peak_rss_kib==null and .test.cache_hit==null and
  .authority.repository_writes==0 and .authority.local_test_executions==0 and
  .authority.cross_project_required_gates==0 and
  .authority.opentofu_binary_executions==0
' "$actions_evidence" >/dev/null

if jq -e --slurpfile p "$plan" --slurpfile a "$openapi" '
    (.resource_to_operation|length)==1 and
    ([.resource_to_operation[].resource_identity.address]|unique|length)==1 and
    .resource_to_operation[0].resource_identity == {
      address:$p[0].resource_changes[0].address,
      mode:$p[0].resource_changes[0].mode,
      type:$p[0].resource_changes[0].type,
      name:$p[0].resource_changes[0].name,
      provider_name:$p[0].resource_changes[0].provider_name
    } and
    .resource_to_operation[0].operation_identity == {
      method:"POST",path:"/checkout",operation_id:$a[0].paths["/checkout"].post.operationId
    } and .resource_to_operation[0].relation=="PROVISIONS" and
    .resource_to_operation[0].mapping_basis=="EXPLICIT_TYPED_IDENTITY" and
    (.operation_to_claim|length)==1 and
    .operation_to_claim[0].operation_identity == .resource_to_operation[0].operation_identity and
    .operation_to_claim[0].claim_identity.claim_id==$a[0].paths["/checkout"].post["x-gooo-claim-id"] and
    .operation_to_claim[0].claim_identity.claim_kind=="SERVICE_BEHAVIOR" and
    .operation_to_claim[0].relation=="ASSERTS" and
    (.claim_evidence|length)==3 and
    all(.claim_evidence[]; .claim_id=="checkout.create")
  ' "$selected_mapping" >/dev/null; then
  mapping_ok=true
else
  mapping_ok=false
fi

if [ "$scenario" = normal ] && jq -e --slurpfile p "$plan" '
  .format_version==$p[0].format_version and
  .values.root_module.resources[0].address==$p[0].resource_changes[0].address and
  .values.root_module.resources[0].type==$p[0].resource_changes[0].type and
  .values.root_module.resources[0].name==$p[0].resource_changes[0].name and
  .values.root_module.resources[0].values.function_name==$p[0].resource_changes[0].change.after.function_name and
  .values.root_module.resources[0].values.handler==$p[0].resource_changes[0].change.after.handler and
  .values.root_module.resources[0].values.runtime==$p[0].resource_changes[0].change.after.runtime
' "$state" >/dev/null; then
  state_ok=true
else
  state_ok=false
fi

if jq -e --slurpfile p "$plan" '
  (.configuration.root_module.resources|length)==1 and
  .configuration.root_module.resources[0].address==$p[0].resource_changes[0].address and
  .configuration.root_module.resources[0].expressions.function_name.constant_value=="checkout" and
  .configuration.root_module.resources[0].expressions.handler.constant_value=="main.Handler" and
  .configuration.root_module.resources[0].expressions.runtime.constant_value=="provided.al2023"
' "$plan" >/dev/null; then
  configuration_ok=true
else
  configuration_ok=false
fi

plan_digest=$(digest "$plan")
state_digest=$(digest "$state")
openapi_digest=$(digest "$openapi")
mapping_digest=$(digest "$selected_mapping")
lock_digest=$(digest "$lock")
ontology_digest=$(digest "$ontology")
actions_digest=$(digest "$actions_evidence")

if [ "$mapping_ok" = true ]; then
  mapping_state=CLOSED
else
  mapping_state=REFUTED
fi

jq -S . "$ontology" > "$output/mapping-ontology.json"

jq -S -n \
  --slurpfile p "$plan" \
  --slurpfile a "$openapi" \
  --slurpfile m "$selected_mapping" \
  --arg plan_digest "$plan_digest" \
  --arg state_digest "$state_digest" \
  --arg openapi_digest "$openapi_digest" \
  --arg mapping_digest "$mapping_digest" \
  --arg scenario "$scenario" \
  --argjson state_present "$(if [ "$state_ok" = true ]; then printf true; else printf false; fi)" \
  --argjson mapping_ok "$mapping_ok" \
  --argjson state_ok "$state_ok" \
  --argjson plan_ok true \
  --argjson openapi_ok true \
  --argjson config_ok "$configuration_ok" '
  ($p[0].resource_changes[0]) as $resource |
  ($a[0].paths["/checkout"].post) as $operation |
  ($m[0].operation_to_claim[0].claim_identity.claim_id // "checkout.create") as $claim |
  (if $mapping_ok then
    [
      {id:("relation:resource:"+$resource.address),subject:("resource:"+$resource.provider_name+":"+$resource.address),predicate:"PROVISIONS",object:("service-operation:POST:/checkout:"+$operation.operationId),basis:"EXPLICIT_TYPED_IDENTITY",source:{mapping_digest:$mapping_digest}},
      {id:("relation:operation:"+$operation.operationId+":claim:"+$claim),subject:("service-operation:POST:/checkout:"+$operation.operationId),predicate:"ASSERTS",object:("claim:"+$claim),basis:"EXPLICIT_TYPED_IDENTITY",source:{mapping_digest:$mapping_digest}},
      {id:("relation:claim:"+$claim+":plan"),subject:("claim:"+$claim),predicate:"SUPPORTED_BY",object:("evidence:opentofu:plan:"+$plan_digest),basis:"EXACT_JSON_POINTER_AND_DIGEST",source:{representation:"PLAN",json_pointer:"/resource_changes/0/change/after",digest:$plan_digest}},
      (if $state_present then {id:("relation:claim:"+$claim+":state"),subject:("claim:"+$claim),predicate:"SUPPORTED_BY",object:("evidence:opentofu:state:"+$state_digest),basis:"EXACT_JSON_POINTER_AND_DIGEST",source:{representation:"STATE",json_pointer:"/values/root_module/resources/0",digest:$state_digest}} else empty end),
      {id:("relation:claim:"+$claim+":openapi"),subject:("claim:"+$claim),predicate:"DECLARED_BY",object:("evidence:openapi:"+$openapi_digest),basis:"EXACT_OPERATION_ID_AND_DIGEST",source:{representation:"DOCUMENT",json_pointer:"/paths/~1checkout/post",digest:$openapi_digest}}
    ]
  else [] end)
' > "$output/relations-array.json"
jq -S -c '.[]' "$output/relations-array.json" > "$output/relations.ndjson"

jq -S -n \
  --arg scenario "$scenario" \
  --arg state_ok "$state_ok" \
  --arg mapping_ok "$mapping_ok" \
  --argjson state_present "$(if [ "$state_ok" = true ]; then printf true; else printf false; fi)" \
  --arg state_reason "OPENTOFU_STATE_UNAVAILABLE" \
  --arg mapping_reason "EXPLICIT_MAPPING_CONFLICT" '
  [
    {case:"missing-state",state:"UNKNOWN",stage:"OPENTOFU_STATE",step:"OBSERVE_OPENTOFU_STATE_JSON",reason:$state_reason,unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_IMMUTABLE_OPENTOFU_STATE_JSON",blocked_by:[]},
    {case:"dependency-blocked-relations",state:"UNKNOWN",stage:"RELATIONS",step:"PROJECT_RESOURCE_OPERATION_RELATIONS",reason:"OPENTOFU_STATE_DEPENDENCY_UNRESOLVED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"PROVIDE_IMMUTABLE_OPENTOFU_STATE_JSON",blocked_by:["OPENTOFU_STATE"]},
    {case:"conflicting-mapping",state:"REFUTED",stage:"MAPPING",step:"BIND_EXPLICIT_RESOURCE_OPERATION_MAPPING",reason:$mapping_reason,unknown_class:null,next_operation:"RESTORE_SINGLE_EXPLICIT_MAPPING",blocked_by:[]},
    {case:"refuted-over-unknown",state:"REFUTED",stage:"DECISION",step:"APPLY_DECISION_PRECEDENCE",reason:"REFUTED_PRECEDES_UNKNOWN",unknown_class:null,next_operation:"REMOVE_REFUTED_CONFLICT_BEFORE_RETRY",blocked_by:["EXPLICIT_MAPPING"]}
  ] | if $scenario=="normal" then [] elif $scenario=="unknown" then .[0:2] else .[0:1] end
' > "$output/causal-frontier.json"

jq -S -n \
  --arg scenario "$scenario" \
  --arg mapping_state "$mapping_state" \
  --arg mapping_digest "$mapping_digest" \
  --arg state_digest "$state_digest" \
  --arg state_ok "$state_ok" '
  [
    {case:"missing-state",state:"UNKNOWN",reason:"OPENTOFU_STATE_UNAVAILABLE",evidence_identity:$state_digest,decision_precedence:"UNKNOWN"},
    {case:"mapping-conflict",state:"REFUTED",reason:"EXPLICIT_MAPPING_CONFLICT",evidence_identity:$mapping_digest,decision_precedence:"REFUTED"},
    {case:"refuted-over-unknown",state:"REFUTED",reason:"REFUTED_PRECEDES_UNKNOWN",evidence_identity:$mapping_digest,decision_precedence:"REFUTED>UNKNOWN>CLOSED"}
  ] | map(select(if $scenario=="normal" then true elif .case=="missing-state" then true else true end))
' > "$output/counterexamples.json"

jq -S -n \
  --slurpfile d "$denominator" \
  --slurpfile p "$plan" \
  --slurpfile a "$openapi" \
  --slurpfile m "$selected_mapping" \
  --slurpfile lock "$lock" \
  --slurpfile actions "$actions_evidence" \
  --slurpfile frontier "$output/causal-frontier.json" \
  --arg subject_sha "$subject_sha" \
  --arg scenario "$scenario" \
  --arg plan_digest "$plan_digest" \
  --arg state_digest "$state_digest" \
  --arg openapi_digest "$openapi_digest" \
  --arg mapping_digest "$mapping_digest" \
  --arg metadata_digest "$metadata_digest" \
  --arg metadata_service_id "$metadata_service_id" \
  --arg lock_digest "$lock_digest" \
  --arg ontology_digest "$ontology_digest" \
  --arg actions_digest "$actions_digest" \
  --argjson mapping_ok "$mapping_ok" \
  --argjson state_ok "$state_ok" \
  --argjson metadata_present "$metadata_present" \
  --argjson configuration_ok "$configuration_ok" \
  --argjson frontier_count "$(jq 'length' "$output/causal-frontier.json")" '
  def unknown($cell_id):
    if $cell_id=="OPENTOFU_STATE" then
      {state:"UNKNOWN",stage:"OPENTOFU_STATE",step:"OBSERVE_OPENTOFU_STATE_JSON",reason:"OPENTOFU_STATE_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_IMMUTABLE_OPENTOFU_STATE_JSON",blocked_by:[]}
    elif $cell_id=="RESOURCE_OPERATION_RELATIONS" then
      {state:"UNKNOWN",stage:"RELATIONS",step:"PROJECT_RESOURCE_OPERATION_RELATIONS",reason:"OPENTOFU_STATE_DEPENDENCY_UNRESOLVED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"PROVIDE_IMMUTABLE_OPENTOFU_STATE_JSON",blocked_by:["OPENTOFU_STATE"]}
    else
      {state:"UNKNOWN",stage:"CLAIMS",step:"BIND_SERVICE_CLAIM_TO_EVIDENCE",reason:"OPENTOFU_STATE_DEPENDENCY_UNRESOLVED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"PROVIDE_IMMUTABLE_OPENTOFU_STATE_JSON",blocked_by:["OPENTOFU_STATE","RESOURCE_OPERATION_RELATIONS"]}
    end;
  def refuted($cell_id):
    {state:"REFUTED",stage:"MAPPING",step:"BIND_EXPLICIT_RESOURCE_OPERATION_MAPPING",reason:(if $cell_id=="EXPLICIT_MAPPING" then "EXPLICIT_MAPPING_CONFLICT" else "MAPPING_CONFLICT_PROPAGATED" end),unknown_class:null,next_operation:"RESTORE_SINGLE_EXPLICIT_MAPPING",blocked_by:[]};
  ($d[0].cells | map(. as $cell |
    (if $cell.id=="OPENTOFU_STATE" and ($state_ok|not) then unknown($cell.id)
     elif ($cell.id=="EXPLICIT_MAPPING" and ($mapping_ok|not)) then refuted($cell.id)
     elif (($cell.id=="RESOURCE_OPERATION_RELATIONS" or $cell.id=="CLAIM_EVIDENCE_BINDING") and ($mapping_ok|not)) then refuted($cell.id)
     elif ($cell.id=="RESOURCE_OPERATION_RELATIONS" and ($state_ok|not)) then unknown($cell.id)
     elif ($cell.id=="CLAIM_EVIDENCE_BINDING" and (($state_ok|not) or ($mapping_ok|not))) then
       (if ($mapping_ok|not) then refuted($cell.id) else unknown($cell.id) end)
     else {state:"CLOSED",stage:null,step:null,reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}
     end) as $resolution |
    $cell + $resolution
  )) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  (if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "UNKNOWN" else "CLOSED" end) as $decision |
  ((if $refuted>0 then [$cells[]|select(.state=="REFUTED")][0] else [$cells[]|select(.state=="UNKNOWN")][0] end) // {stage:null,step:null,reason:"ALL_BRIDGE_CELLS_CLOSED",unknown_class:null,next_operation:"NONE",blocked_by:[]}) as $first |
  {
    schema:"gooo/infra-evidence/opentofu-service-contract-bridge/bundle/v1",
    subject_sha:$subject_sha,
    scenario:$scenario,
    decision:$decision,
    claim:{state:(if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" else "CLOSED" end),stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,next_operation:$first.next_operation,blocked_by:($first.blocked_by//[])},
    denominator:{id:$d[0].id,total:$d[0].target_cells,closed:$closed,unknown:$unknown,refuted:$refuted,decision_precedence:$d[0].decision_precedence,proof_totals:$d[0].proof_totals,indicator_totals:$d[0].indicator_totals},
    inputs:{opentofu_plan:{representation:"PLAN",source:"tofu show -json",format_version:$p[0].format_version,engine:"OPENTOFU",engine_version:$p[0].terraform_version,digest:$plan_digest},opentofu_state:(if $state_ok then {representation:"STATE",source:"tofu show -json",format_version:"1.0",engine:"OPENTOFU",engine_version:$p[0].terraform_version,digest:$state_digest} else {representation:"STATE",source:"tofu show -json",state:"MISSING",digest:null} end),openapi:{representation:"DOCUMENT",openapi_version:$a[0].openapi,digest:$openapi_digest,operation_id:$a[0].paths["/checkout"].post.operationId},service_metadata:(if $metadata_present then {optional:true,digest:$metadata_digest,service_id:$metadata_service_id} else {optional:true,state:"ABSENT",digest:null,service_id:null} end),mapping:{authority:$m[0].authority,digest:$mapping_digest}},
    ontology:{owner:"GOOO",schema:"gooo/infra-evidence/opentofu-service-contract-bridge/mapping-ontology/v1",source:"examples/opentofu-service-contract-bridge/main.gooo",digest:$ontology_digest},
    relations:{path:"relations.ndjson",observed:(if $mapping_ok then (if $state_ok then 5 else 4 end) else 0 end),basis:"EXACT_TYPED_MAPPING_ONLY"},
    unresolved_causal_frontier:{path:"causal-frontier.json",observed:$frontier_count,required_fields:$d[0].unknown_coordinate_fields},
    counterexamples:{path:"counterexamples.json",observed:3,precedence:$d[0].decision_precedence},
    improvement:$d[0].improvement,
    external_utility:$d[0].external_utility,
    actions_evidence:{path:"actions-evidence.json",digest:$actions_digest,go_version:$actions[0].go_version,repository_writes:$actions[0].authority.repository_writes,local_test_executions:$actions[0].authority.local_test_executions,build:$actions[0].build,test:$actions[0].test},
    release_lock:{path:"contracts/opentofu-service-contract-bridge-release-lock-v1.json",digest:$lock_digest,core:$lock[0].core,opentofu:$lock[0].opentofu},
    summary:{total_cells:12,closed_cells:$closed,unknown_cells:$unknown,refuted_cells:$refuted,repository_writes:0,local_test_executions:0,cross_project_required_gates:0,opentofu_binary_executions:0,provider_accesses:0,remote_state_writes:0,relations_observed:(if $mapping_ok then (if $state_ok then 5 else 4 end) else 0 end),causal_frontier_observed:$frontier_count,counterexamples_observed:3},
    cells:$cells,
    proofs:[$d[0].proof_totals[] as $proof | {choice:$proof.proof_choice,total:$proof.total,closed:([$cells[]|select(.proof_choice==$proof.proof_choice and .state=="CLOSED")]|length)}],
    indicators:[$d[0].indicator_totals[] as $indicator | {class:$indicator.indicator_class,total:$indicator.total,closed:([$cells[]|select(.indicator_class==$indicator.indicator_class and .state=="CLOSED")]|length)}],
    authority:{product_scope:"READ_ONLY_OPENTOFU_SERVICE_CONTRACT_BRIDGE",repository_writes:0,local_test_executions:0,cross_project_required_gates:0,terraform_apply_authorized:false,opentofu_init_authorized:false,opentofu_plan_authorized:false,opentofu_apply_authorized:false,opentofu_test_authorized:false,provider_install_authorized:false,remote_state_write_authorized:false,deployment_execution_authorized:false,service_runtime_probe_authorized:false,repository_edit_authorized:false,automatic_merge_authorized:false,semantic_truth_claimed:false},
    evidence:{plan_digest:$plan_digest,state_digest:(if $state_ok then $state_digest else null end),openapi_digest:$openapi_digest,mapping_digest:$mapping_digest,metadata_digest:$metadata_digest,lock_digest:$lock_digest,ontology_digest:$ontology_digest,actions_digest:$actions_digest}
  }
' > "$output/bundle.json"

cp "$actions_evidence" "$output/actions-evidence.json"

{
  printf '# OpenTofu service-contract bridge dossier\n\n'
  jq -r '"- Scenario: `\(.scenario)`\n- Decision: `\(.decision)`\n- Cells: \(.denominator.closed)/\(.denominator.total) CLOSED; UNKNOWN \(.denominator.unknown); REFUTED \(.denominator.refuted)\n- Relations: \(.relations.observed) exact typed relations\n- OpenTofu plan: `\(.inputs.opentofu_plan.digest)`\n- OpenTofu state: `\(.inputs.opentofu_state.digest // "MISSING")`\n- OpenAPI document: `\(.inputs.openapi.digest)`\n- Mapping authority: `\(.inputs.mapping.authority)`"' "$output/bundle.json"
  printf '\n## Exact mapping\n\n'
  jq -r 'if .relations.observed==0 then "No mapping relations are asserted because the explicit mapping is REFUTED." else "- Resource `aws_lambda_function.checkout` --PROVISIONS--> `POST /checkout` (`createCheckout`)\n- Operation `createCheckout` --ASSERTS--> claim `checkout.create`\n- Claim `checkout.create` is linked to exact OpenTofu plan/state JSON pointers and the exact OpenAPI operation digest." end' "$output/bundle.json"
  printf '\n## Causal frontier\n\n'
  jq -r 'if length==0 then "- none" else .[]|"- \(.state): \(.stage) / \(.step) / \(.reason) / \(.unknown_class // "REFUTED") / next `\(.next_operation)` / blocked by `\(.blocked_by|join(", "))`" end' "$output/causal-frontier.json"
  printf '\n## Counterexamples\n\n'
  jq -r '.[]|"- \(.case): \(.state) / \(.reason) / precedence `\(.decision_precedence)`"' "$output/counterexamples.json"
  printf '\n## Proof and indicator counts\n\n'
  jq -r '"- Proofs: " + ([.proofs[]|"\(.choice) \(.closed)/\(.total)"]|join(", ")) + "\n- Indicators: " + ([.indicators[]|"\(.class) \(.closed)/\(.total)"]|join(", "))' "$output/bundle.json"
  printf '\n## Actions evidence\n\n'
  jq -r '"- Go: \(.go_version)\n- Repository writes: \(.authority.repository_writes)\n- Local test executions: \(.authority.local_test_executions)\n- Go build: \(.build.executions) execution; wall_ms=\(.build.wall_ms // "null"); peak_rss_kib=\(.build.peak_rss_kib // "null"); cache_hit=\(.build.cache_hit // "null"); state=\(.build.state)\n- Go test: \(.test.executions) execution; wall_ms=\(.test.wall_ms // "null"); peak_rss_kib=\(.test.peak_rss_kib // "null"); cache_hit=\(.test.cache_hit // "null"); state=\(.test.state)\n- OpenTofu binary executions: \(.authority.opentofu_binary_executions)"' "$output/actions-evidence.json"
  printf '\n## Non-claims\n\n'
  printf '%s\n' '- This dossier does not claim tofu init, plan, apply, test, provider install, remote state write, deployment, or live service behavior.'
  printf '%s\n' '- External utility is 0/1 UNKNOWN because no independent external user receipt exists.'
  printf '%s\n' '- Improvement is UNKNOWN with null before/after values because no exact matched integer pair exists.'
} > "$output/report.md"

rm "$output/relations-array.json"

manifest_json='[]'
for file in bundle.json mapping-ontology.json relations.ndjson causal-frontier.json counterexamples.json actions-evidence.json report.md; do
  file_digest=$(sha256sum "$output/$file" | awk '{print $1}')
  file_bytes=$(wc -c < "$output/$file" | tr -d ' ')
  manifest_json=$(jq -c --arg path "$file" --arg sha256 "$file_digest" --argjson bytes "$file_bytes" '. + [{path:$path,bytes:$bytes,sha256:$sha256}]' <<< "$manifest_json")
done
jq -S -n \
  --arg scenario "$scenario" \
  --arg subject_sha "$subject_sha" \
  --arg bundle_digest "$(sha256sum "$output/bundle.json" | awk '{print $1}')" \
  --argjson files "$manifest_json" \
  '{schema:"gooo/infra-evidence/opentofu-service-contract-bridge/manifest/v1",scenario:$scenario,subject_sha:$subject_sha,files:$files,bundle_sha256:$bundle_digest,manifest_covers:"all listed files except manifest.json"}' > "$output/manifest.json"
