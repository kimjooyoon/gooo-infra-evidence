#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: evaluate-v2.sh ROOT CANDIDATE RUNTIME GRAPH HCL_RECEIPT SYMBOL_RECEIPT OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$1
candidate=$2
runtime=$3
graph=$4
hcl_receipt=$5
symbol_receipt=$6
output=$7
head_sha=$8
phase=$9
denominator="$root/contracts/infra-evidence-denominator-v2.json"
core_lock="$root/contracts/core-v0.2-release-lock-v1.json"
project="$candidate/project-v2.json"

for file in "$denominator" "$core_lock" "$project" "$runtime" "$graph" "$hcl_receipt" "$symbol_receipt"; do
  test -f "$file" || { echo "missing required input: $file" >&2; exit 66; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
json_or_null() { if test -f "$1" && jq -e . "$1" >/dev/null 2>&1; then cp "$1" "$2"; else printf 'null\n' > "$2"; fi; }
digest_or_empty() { if test -f "$1"; then sha256sum "$1" | awk '{print "sha256:" $1}'; else printf ''; fi; }
path_for() { jq -r --arg key "$1" '.paths[$key]' "$project"; }

terraform_declaration=$(path_for terraform_declaration)
terraform_plan=$(path_for terraform_plan)
terraform_state=$(path_for terraform_state)
openapi=$(path_for openapi)
service_source=$(path_for service_source)
build_receipt=$(path_for build_receipt)
deployment_receipt=$(path_for deployment_receipt)
runtime_one=$(jq -r '.paths.runtime_observations[0]' "$project")
runtime_two=$(jq -r '.paths.runtime_observations[1]' "$project")

for pair in "plan:$terraform_plan" "state:$terraform_state" "openapi:$openapi" "build:$build_receipt" "deployment:$deployment_receipt" "runtime1:$runtime_one" "runtime2:$runtime_two"; do
  key=${pair%%:*}
  path=${pair#*:}
  json_or_null "$candidate/$path" "$work/$key.json"
done

test -s "$candidate/$service_source" && service_source_available=true || service_source_available=false
service_source_digest=$(digest_or_empty "$candidate/$service_source")

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile lock "$core_lock" --slurpfile project "$project" \
  --slurpfile runtime "$runtime" --slurpfile graph "$graph" --slurpfile hcl "$hcl_receipt" --slurpfile symbol "$symbol_receipt" \
  --slurpfile plan "$work/plan.json" --slurpfile state "$work/state.json" --slurpfile openapi "$work/openapi.json" \
  --slurpfile build "$work/build.json" --slurpfile deployment "$work/deployment.json" \
  --slurpfile runtime1 "$work/runtime1.json" --slurpfile runtime2 "$work/runtime2.json" \
  --arg head_sha "$head_sha" --arg phase "$phase" --arg service_source_digest "$service_source_digest" \
  --arg terraform_declaration_digest "$(digest_or_empty "$candidate/$terraform_declaration")" \
  --arg hcl_receipt_digest "$(digest_or_empty "$hcl_receipt")" \
  --arg terraform_plan_digest "$(digest_or_empty "$candidate/$terraform_plan")" \
  --arg terraform_state_digest "$(digest_or_empty "$candidate/$terraform_state")" \
  --arg openapi_digest "$(digest_or_empty "$candidate/$openapi")" \
  --arg build_receipt_digest "$(digest_or_empty "$candidate/$build_receipt")" \
  --arg deployment_receipt_digest "$(digest_or_empty "$candidate/$deployment_receipt")" \
  --arg runtime1_digest "$(digest_or_empty "$candidate/$runtime_one")" --arg runtime2_digest "$(digest_or_empty "$candidate/$runtime_two")" \
  --argjson service_source_available "$service_source_available" '
  ($denominator[0]) as $d |
  def raw_sha: type=="string" and test("^[0-9a-f]{64}$");
  def direct_closed($reason): {state:"CLOSED",reason:$reason,next_operation:"NONE",unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def direct_unknown($reason;$next): {state:"UNKNOWN",reason:$reason,next_operation:$next,unknown_class:"DIRECT_MISSING",resolution:"PREREQUISITE_CLASS",blocked_by:[]};
  def direct_refuted($reason;$next): {state:"REFUTED",reason:$reason,next_operation:$next,unknown_class:null,resolution:"EXACT",blocked_by:[]};
  def resolution_for($cell):
    ([$graph[0].activity_resolution_observation.entries[]? | select(.id==$cell.id and .activity==$cell.activity)]) as $entries |
    if ($entries|length)==0 then direct_unknown("CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE";"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
    elif ($entries|length)>1 then direct_refuted("DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT";"REMOVE_DUPLICATE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"BIND_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
    else ($entries[0].receipt) as $receipt |
      if $receipt.schema!="gooo/activity-cardinality-resolution/v1" or $receipt.selector!=$entries[0].selector or
        $receipt.subject.source_digest!=$graph[0].source_digest or $receipt.subject.semantic_digest!=$graph[0].ir.semantic_digest then
        direct_refuted("INVALID_CORE_ACTIVITY_RESOLUTION_RECEIPT";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION_OBSERVATION",step:"VALIDATE_CORE_ACTIVITY_RESOLUTION_RECEIPT"}
      elif $receipt.decision=="CLOSED" and $receipt.claim.state=="CLOSED" and $receipt.occurrences==1 and ($receipt.matches|length)==1 and
        $receipt.claim.stage=="RESOLUTION" and $receipt.claim.step=="RESOLVE_ACTIVITY_CARDINALITY" and
        $receipt.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" and $receipt.claim.next_operation=="USE_RESOLVED_ACTIVITY" and $receipt.claim.proof_choice=="COHERENCE" then
        direct_closed("CORE_ACTIVITY_UNIQUELY_RESOLVED") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      elif $receipt.decision=="UNKNOWN" and $receipt.claim.state=="UNKNOWN" and $receipt.occurrences==0 and ($receipt.matches|length)==0 and
        $receipt.claim.reason=="ACTIVITY_NOT_FOUND" and $receipt.claim.unknown_class=="DIRECT_MISSING" then
        direct_unknown("ACTIVITY_NOT_FOUND";"DECLARE_OR_WIDEN_ACTIVITY_SELECTOR") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      elif $receipt.decision=="REFUTED" and $receipt.claim.state=="REFUTED" and $receipt.occurrences>1 and ($receipt.matches|length)==$receipt.occurrences and
        $receipt.claim.reason=="AMBIGUOUS_ACTIVITY_BINDING" then
        direct_refuted("AMBIGUOUS_ACTIVITY_BINDING";"NARROW_ACTIVITY_SELECTOR") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      else direct_refuted("UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION";"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT") + {stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY"}
      end
    end;
  def core_identity_ok:
    $runtime[0].release_identity_observed==true and $runtime[0].version.version=="0.2.0-dev" and
    $graph[0].activity_resolution_observation.core_release.repository==$lock[0].repository and
    $graph[0].activity_resolution_observation.core_release.tag==$lock[0].tag and
    $graph[0].activity_resolution_observation.core_release.tag_object_sha==$lock[0].tag_object_sha and
    $graph[0].activity_resolution_observation.core_release.target_commit_sha==$lock[0].target_commit_sha and
    $graph[0].activity_resolution_observation.core_release.binary_sha256==$lock[0].assets[0].sha256;
  def graph_ok:
    $graph[0].schema_version=="gooo-graph/v1" and $graph[0].activity_resolution_observation.schema=="gooo/evidence-generator/activity-resolution-observation/v1" and
    $graph[0].activity_resolution_observation.role=="project_graph" and
    $graph[0].activity_resolution_observation.summary=={expected:12,observed:12,closed:12,unknown:0,refuted:0,unique_selectors:12} and
    ([$graph[0].activity_resolution_observation.entries[].id]|sort)==([$d.cells[].id]|sort);
  def hcl_identity_valid:
    $hcl[0].schema=="gooo/infra-evidence/hcl-declaration-receipt/v1" and $hcl[0].subject.project_id==$project[0].id and
    $hcl[0].subject.source_file==$project[0].paths.terraform_declaration and
    $hcl[0].authority.parser_module=="github.com/hashicorp/hcl/v2" and $hcl[0].authority.parser_version=="v2.24.0" and
    $hcl[0].authority.parser_sum=="h1:2QJdZ454DSsYGoaE6QheQZjtKZSUs9Nh2izTWiwQxvE=" and
    $hcl[0].authority.parser_package=="github.com/hashicorp/hcl/v2/hclsyntax" and $hcl[0].authority.parser_api=="hclsyntax.ParseConfig" and
    $hcl[0].authority.terraform_execution=="NOT_USED" and $hcl[0].authority.source_mutation=="NONE";
  def hcl_declaration_ok:
    hcl_identity_valid and $hcl[0].decision=="CLOSED" and $hcl[0].claim.state=="CLOSED" and
    $hcl[0].subject.source_digest==$terraform_declaration_digest and
    $hcl[0].binding.resource_address==$project[0].resource_address and
    $hcl[0].binding.target==$project[0].deployment_target and $hcl[0].binding.image_digest==$project[0].artifact_digest and
    $hcl[0].counts=={image_digest_attribute_occurrences:1,parser_diagnostics:0,resource_block_occurrences:1,target_attribute_occurrences:1} and
    $hcl[0].source_range.start_line>0 and $hcl[0].source_range.end_line>=$hcl[0].source_range.start_line;
  def plan_ok: $plan[0]!=null and $plan[0].format_version=="1.2" and $plan[0].errored==false and
    ([$plan[0].resource_changes[]|select(.address==$project[0].resource_address and .change.after.target==$project[0].deployment_target and .change.after.image_digest==$project[0].artifact_digest)]|length)==1;
  def state_ok: $state[0]!=null and
    ([$state[0].values.root_module.resources[]|select(.address==$project[0].resource_address and .values.id==$project[0].remote_id and .values.target==$project[0].deployment_target and .values.image_digest==$project[0].artifact_digest)]|length)==1;
  def openapi_ok: $openapi[0]!=null and $openapi[0].openapi=="3.1.0" and
    $openapi[0].paths[$project[0].openapi_path][($project[0].openapi_method|ascii_downcase)].operationId==$project[0].openapi_operation and
    ([$openapi[0].paths[][]|select(.operationId==$project[0].openapi_operation)]|length)==1;
  def symbol_valid:
    $symbol[0].schema=="gooo/infra-evidence/service-symbol-receipt/v1" and $symbol[0].subject.project_id==$project[0].id and
    $symbol[0].subject.source_file==$project[0].paths.service_source and $symbol[0].subject.source_digest==$service_source_digest and
    $symbol[0].subject.openapi_file==$project[0].paths.openapi and $symbol[0].subject.openapi_digest==$openapi_digest and
    $symbol[0].binding.openapi_operation==$project[0].openapi_operation and $symbol[0].binding.openapi_path==$project[0].openapi_path and
    $symbol[0].binding.openapi_method==$project[0].openapi_method and $symbol[0].binding.service_handler==$project[0].service_handler;
  def symbol_ok: symbol_valid and $symbol[0].decision=="CLOSED" and $symbol[0].claim.state=="CLOSED" and
    $symbol[0].counts=={openapi_operation_occurrences:1,handler_definition_occurrences:1,handler_signature_occurrences:1,handler_registration_occurrences:1};
  def provenance_ok: $build[0]!=null and $service_source_available and symbol_ok and $build[0].schema=="gooo/build-receipt/v2" and
    ([$build[0].materials[]|select(.path==$project[0].paths.service_source and .digest==$service_source_digest and .handler_symbol==$project[0].service_handler)]|length)==1 and
    ([$build[0].products[]|select(.digest==$project[0].artifact_digest)]|length)==1;
  def deployment_ok: $deployment[0]!=null and $deployment[0].target==$project[0].deployment_target and
    $deployment[0].deployment_id==$project[0].remote_id and $deployment[0].artifact_digest==$project[0].artifact_digest and
    $deployment[0].generation==$deployment[0].observed_generation;
  def runtime_ok: $runtime1[0]!=null and $runtime2[0]!=null and $runtime1[0].sequence==1 and $runtime2[0].sequence==2 and
    $runtime1[0].deployment_id==$project[0].remote_id and $runtime2[0].deployment_id==$project[0].remote_id and
    $runtime1[0].artifact_digest==$project[0].artifact_digest and $runtime2[0].artifact_digest==$project[0].artifact_digest and
    $runtime1[0].operation_id==$project[0].openapi_operation and $runtime2[0].operation_id==$project[0].openapi_operation and
    $runtime1[0].http_status==200 and $runtime2[0].http_status==200 and $runtime1[0].response.status=="ok" and $runtime2[0].response.status=="ok";
  def domain($cell):
    if $cell.id=="RELEASED_GOOO_IDENTITY" then if core_identity_ok then direct_closed($cell.closed_reason) else direct_refuted("CORE_RESOLUTION_RELEASE_IDENTITY_MISMATCH";"RESTORE_COMMON_CORE_RESOLUTION_RELEASE") end
    elif $cell.id=="GOOO_SOURCE_AUTHORITY" then if $project[0].schema=="gooo/infra-evidence/project/v2" then direct_closed($cell.closed_reason) else direct_refuted("INFRA_PROJECT_MANIFEST_INVALID";"RESTORE_INFRA_PROJECT_MANIFEST") end
    elif $cell.id=="GOOO_GRAPH_BINDING" then if graph_ok then direct_closed($cell.closed_reason) else direct_refuted("GOOO_INFRA_ACTIVITY_BINDING_MISMATCH";"RESTORE_GOOO_INFRA_ACTIVITY_RECEIPTS") end
    elif $cell.id=="TERRAFORM_DECLARATION" then if hcl_declaration_ok then direct_closed($cell.closed_reason) elif hcl_identity_valid and $hcl[0].decision=="UNKNOWN" and $hcl[0].claim.state=="UNKNOWN" then direct_unknown($hcl[0].claim.reason;$hcl[0].claim.next_operation)+{stage:$hcl[0].claim.stage,step:$hcl[0].claim.step,unknown_class:$hcl[0].claim.unknown_class} elif hcl_identity_valid and $hcl[0].decision=="REFUTED" and $hcl[0].claim.state=="REFUTED" then direct_refuted($hcl[0].claim.reason;$hcl[0].claim.next_operation)+{stage:$hcl[0].claim.stage,step:$hcl[0].claim.step} else direct_refuted("HCL_DECLARATION_RECEIPT_INVALID";"RESTORE_HCL_DECLARATION_RECEIPT") end
    elif $cell.id=="TERRAFORM_PLAN" then if plan_ok then direct_closed($cell.closed_reason) elif $plan[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("TERRAFORM_PLAN_BINDING_MISMATCH";"RESTORE_TERRAFORM_PLAN_RECEIPT") end
    elif $cell.id=="TERRAFORM_STATE" then if state_ok then direct_closed($cell.closed_reason) elif $state[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("TERRAFORM_STATE_BINDING_MISMATCH";"RESTORE_TERRAFORM_STATE_RECEIPT") end
    elif $cell.id=="OPENAPI_CONTRACT" then if openapi_ok then direct_closed($cell.closed_reason) elif $openapi[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("OPENAPI_OPERATION_MISMATCH";"RESTORE_OPENAPI_CONTRACT") end
    elif $cell.id=="SERVICE_SYMBOL_BINDING" then if symbol_ok then direct_closed($cell.closed_reason) elif $symbol[0].decision=="UNKNOWN" and $symbol[0].claim.state=="UNKNOWN" then direct_unknown($symbol[0].claim.reason;$symbol[0].claim.next_operation) + {stage:$symbol[0].claim.stage,step:$symbol[0].claim.step} elif symbol_valid then direct_refuted($symbol[0].claim.reason;$symbol[0].claim.next_operation) + {stage:$symbol[0].claim.stage,step:$symbol[0].claim.step} else direct_refuted("SERVICE_SYMBOL_RECEIPT_INVALID";"RESTORE_SERVICE_SYMBOL_RECEIPT") end
    elif $cell.id=="SERVICE_ARTIFACT_PROVENANCE" then if provenance_ok then direct_closed($cell.closed_reason) elif $build[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("SERVICE_ARTIFACT_PROVENANCE_MISMATCH";"RESTORE_BUILD_RECEIPT") end
    elif $cell.id=="DEPLOYMENT_OUTPUT" then if deployment_ok then direct_closed($cell.closed_reason) elif $deployment[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("ARTIFACT_IDENTITY_MISMATCH";"RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY") end
    elif $cell.id=="RUNTIME_DRIFT_REGRESSION" then if runtime_ok then direct_closed($cell.closed_reason) elif $runtime1[0]==null or $runtime2[0]==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("RUNTIME_ARTIFACT_DRIFT";"RESTORE_RUNTIME_ARTIFACT_IDENTITY") end
    elif $cell.id=="READ_ONLY_EFFECT" then if $runtime[0].repository.writes==0 and $runtime[0].repository.before_digest==$runtime[0].repository.after_digest then direct_closed($cell.closed_reason) elif $runtime[0].repository.writes==null then direct_unknown($cell.unknown_reason;$cell.next_operation) else direct_refuted("REPOSITORY_WRITE_EFFECT_OBSERVED";"REMOVE_INPUT_REPOSITORY_WRITES") end
    else direct_refuted("UNRECOGNIZED_CELL";"IMPLEMENT_EXPLICIT_CELL_DECISION") end;
  (reduce $d.cells[] as $cell
    ({cells:[],decisions:{}};
      . as $acc |
      ([$cell.depends_on[]? | $acc.decisions[.]]) as $dependencies |
      (resolution_for($cell)) as $resolution |
      (if any($dependencies[]; .state=="REFUTED") then
        {state:"REFUTED",reason:"DEPENDENCY_REFUTED",next_operation:"RESOLVE_REFUTED_PREDECESSORS",unknown_class:null,resolution:"EXACT",blocked_by:[$dependencies[]|select(.state=="REFUTED")|.cell_id]}
      elif any($dependencies[]; .state=="UNKNOWN") then
        {state:"UNKNOWN",reason:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",unknown_class:"DEPENDENCY_BLOCKED",resolution:"PREREQUISITE_CLASS",blocked_by:[$dependencies[]|select(.state=="UNKNOWN")|.cell_id]}
      elif $resolution.state!="CLOSED" then $resolution
      else domain($cell) end) as $decision |
      ($decision + {cell_id:$cell.id,stage:($decision.stage//$cell.stage),step:($decision.step//$cell.step)}) as $bound |
      .cells += [$cell + $bound + {core_resolution:$resolution}] |
      .decisions[$cell.id] = $bound
    )) as $evaluation |
  ([$evaluation.cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$evaluation.cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$evaluation.cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$evaluation.cells[]|select(.unknown_class=="DIRECT_MISSING")]|length) as $direct_missing |
  ([$evaluation.cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length) as $dependency_blocked |
  ([$evaluation.cells[]|select(.state!="CLOSED")][0]//null) as $first_nonclosed |
  ([$evaluation.cells[]|select(.core_resolution.state=="CLOSED")]|length) as $core_receipts |
  ([(hcl_declaration_ok and plan_ok),(plan_ok and state_ok),symbol_ok,provenance_ok,deployment_ok,runtime_ok]|map(select(.==true))|length) as $semantic_edges |
  {
    schema:"gooo/infra-evidence/report/v2",phase:$phase,subject_sha:$head_sha,service:$project[0].id,
    decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "EVIDENCE_CHAIN_CLOSED" end),
    claim:{id:"checkout://claim/infra-service-symbol-evidence/v2",state:(if $refuted>0 then "REFUTED" elif $unknown>0 then "UNKNOWN" else "CLOSED" end),
      stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),reason:($first_nonclosed.reason//"INFRA_SERVICE_SYMBOL_EVIDENCE_CHAIN_CLOSED"),
      next_operation:($first_nonclosed.next_operation//"NONE"),unknown_class:($first_nonclosed.unknown_class//null),blocked_by:($first_nonclosed.blocked_by//[])},
    summary:{total:12,closed:$closed,unknown:$unknown,refuted:$refuted,direct_missing:$direct_missing,dependency_blocked:$dependency_blocked,repository_writes:$runtime[0].repository.writes},
    identities:{resource_address:$project[0].resource_address,remote_id:$project[0].remote_id,artifact_digest:$project[0].artifact_digest,deployment_target:$project[0].deployment_target,
      openapi_operation:$project[0].openapi_operation,openapi_path:$project[0].openapi_path,openapi_method:$project[0].openapi_method,service_handler:$project[0].service_handler,service_source_digest:$service_source_digest},
    evidence_digests:{terraform_declaration:$terraform_declaration_digest,hcl_declaration_receipt:$hcl_receipt_digest,terraform_plan:$terraform_plan_digest,terraform_state:$terraform_state_digest,openapi:$openapi_digest,
      build_receipt:$build_receipt_digest,deployment_receipt:$deployment_receipt_digest,runtime_observation_1:$runtime1_digest,runtime_observation_2:$runtime2_digest},
    authority:{binding:"RELEASED_GOOO_ACTIVITY_RESOLUTION_RECEIPTS",core_activity_receipts:$core_receipts,core_activity_total:12,core_identity_anchors:([$d.cells[]|select(.core_identity_anchor==true)]|length),
      service_symbol_parser:"GO_AST",terraform_declaration_parser:"HASHICORP_HCL_V2",terraform_parser_version:$hcl[0].authority.parser_version,terraform_parser_sum:$hcl[0].authority.parser_sum,terraform_execution:"NOT_CLAIMED",terraform_validation:"HCL_SYNTAX_AND_LITERAL_BINDING_ONLY",live_cloud_state:"NOT_CLAIMED",deployment_execution:"NOT_CLAIMED",live_network_probe:"NOT_CLAIMED"},
    performance:$runtime[0].performance,toolchain:$runtime[0].go_toolchain,cells:$evaluation.cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$evaluation.cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$evaluation.cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["OUTCOME","DRIVER","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$evaluation.cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$evaluation.cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[
      {id:"gooo.metric.infra-evidence.readiness.v2",class:"OUTCOME",value:$closed,total:12,unit:"cells",state:(if $closed==12 then "SATISFIED" else "GAP" end),activity:"ObserveRuntimeDrift"},
      {id:"gooo.metric.infra-evidence.core-activity-receipts.v2",class:"DRIVER",value:$core_receipts,total:12,unit:"receipts",state:(if $core_receipts==12 then "SATISFIED" else "GAP" end),activity:"BindInfraActivities"},
      {id:"gooo.metric.infra-evidence.semantic-edges.v2",class:"OUTCOME",value:$semantic_edges,total:6,unit:"edges",state:(if $semantic_edges==6 then "SATISFIED" else "GAP" end),activity:"BindServiceArtifactProvenance"},
      {id:"gooo.metric.infra-evidence.service-symbol-bindings.v2",class:"GUARDRAIL",value:(if symbol_ok then 1 else 0 end),total:1,unit:"bindings",state:(if symbol_ok then "SATISFIED" elif $symbol[0].decision=="UNKNOWN" then "UNKNOWN" else "REFUTED" end),activity:"BindServiceHandlerSymbol"},
      {id:"gooo.metric.infra-evidence.hcl-resource-bindings.v2",class:"DRIVER",value:(if hcl_declaration_ok then 1 else 0 end),total:1,unit:"bindings",state:(if hcl_declaration_ok then "SATISFIED" elif $hcl[0].decision=="UNKNOWN" then "UNKNOWN" else "REFUTED" end),activity:"ObserveTerraformDeclaration"},
      {id:"gooo.metric.infra-evidence.runtime-observations.v2",class:"OUTCOME",value:(if runtime_ok then 2 else 0 end),total:2,unit:"observations",state:(if runtime_ok then "SATISFIED" else "GAP" end),activity:"ObserveRuntimeDrift"},
      {id:"gooo.metric.infra-evidence.repository-writes.v2",class:"GUARDRAIL",value:$runtime[0].repository.writes,total:0,unit:"writes",state:(if $runtime[0].repository.writes==0 then "SATISFIED" else "REFUTED" end),activity:"ObserveReadOnlyEffect"},
      {id:"gooo.metric.infra-evidence.graph-peak-rss.v2",class:"DRIVER",value:$runtime[0].performance.graph_peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"ObserveReleasedGoooIdentity"},
      {id:"gooo.metric.infra-evidence.graph-wall-time.v2",class:"DRIVER",value:$runtime[0].performance.graph_wall_ms,unit:"ms",state:"OBSERVED",activity:"ObserveReleasedGoooIdentity"},
      {id:"gooo.metric.infra-evidence.hcl-parser-peak-rss.v2",class:"DRIVER",value:$runtime[0].performance.hcl_parser_peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"ObserveTerraformDeclaration"},
      {id:"gooo.metric.infra-evidence.hcl-parser-wall-time.v2",class:"DRIVER",value:$runtime[0].performance.hcl_parser_wall_ms,unit:"ms",state:"OBSERVED",activity:"ObserveTerraformDeclaration"},
      {id:"gooo.metric.infra-evidence.direct-missing.v2",class:"GUARDRAIL",value:$direct_missing,total:12,unit:"cells",state:(if $direct_missing==0 then "SATISFIED" else "GAP" end),activity:"BindServiceHandlerSymbol"},
      {id:"gooo.metric.infra-evidence.dependency-blocked.v2",class:"GUARDRAIL",value:$dependency_blocked,total:12,unit:"cells",state:(if $dependency_blocked==0 then "SATISFIED" else "GAP" end),activity:"BindDeploymentOutput"}
    ]
  }' > "$output"
