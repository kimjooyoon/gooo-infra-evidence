#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 6; then
  echo "usage: evaluate.sh ROOT CANDIDATE RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 2
fi

root=$1
candidate=$2
runtime=$3
output=$4
head_sha=$5
phase=$6
denominator="$root/contracts/infra-evidence-denominator-v1.json"
project="$candidate/project.json"

for file in "$denominator" "$project" "$runtime"; do test -f "$file" || { echo "missing required input: $file" >&2; exit 2; }; done

digest_file() { sha256sum "$1" | awk '{print "sha256:" $1}'; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
json_or_null() { if test -f "$1" && jq -e . "$1" >/dev/null 2>&1; then cp "$1" "$2"; else printf 'null\n' > "$2"; fi; }

path_for() { jq -r --arg key "$1" '.paths[$key]' "$project"; }
terraform_declaration=$(path_for terraform_declaration)
terraform_plan=$(path_for terraform_plan)
terraform_state=$(path_for terraform_state)
openapi=$(path_for openapi)
service_source=$(path_for service_source)
build_receipt=$(path_for build_receipt)
deployment_receipt=$(path_for deployment_receipt)
policy_receipt=$(path_for policy_receipt)
runtime_one=$(jq -r '.paths.runtime_observations[0]' "$project")
runtime_two=$(jq -r '.paths.runtime_observations[1]' "$project")

for pair in \
  "plan:$terraform_plan" "state:$terraform_state" "openapi:$openapi" "build:$build_receipt" \
  "deployment:$deployment_receipt" "policy:$policy_receipt" "runtime1:$runtime_one" "runtime2:$runtime_two"; do
  key=${pair%%:*}; path=${pair#*:}; json_or_null "$candidate/$path" "$work/$key.json"
done

test -s "$candidate/$terraform_declaration" && terraform_declaration_available=true || terraform_declaration_available=false
if test "$terraform_declaration_available" = true && grep -Fq "$(jq -r .artifact_digest "$project")" "$candidate/$terraform_declaration"; then terraform_declaration_matches=true; else terraform_declaration_matches=false; fi
test -s "$candidate/$service_source" && service_source_available=true || service_source_available=false
if test "$service_source_available" = true; then service_source_digest=$(digest_file "$candidate/$service_source"); else service_source_digest=""; fi

digest_or_empty() { if test -f "$1"; then digest_file "$1"; else printf ''; fi; }

jq -n \
  --slurpfile denominator "$denominator" --slurpfile project "$project" --slurpfile runtime "$runtime" \
  --slurpfile plan "$work/plan.json" --slurpfile state "$work/state.json" --slurpfile openapi "$work/openapi.json" \
  --slurpfile build "$work/build.json" --slurpfile deployment "$work/deployment.json" --slurpfile policy "$work/policy.json" \
  --slurpfile runtime1 "$work/runtime1.json" --slurpfile runtime2 "$work/runtime2.json" \
  --arg head_sha "$head_sha" --arg phase "$phase" --arg service_source_digest "$service_source_digest" \
  --arg terraform_declaration_digest "$(digest_or_empty "$candidate/$terraform_declaration")" \
  --arg terraform_plan_digest "$(digest_or_empty "$candidate/$terraform_plan")" \
  --arg terraform_state_digest "$(digest_or_empty "$candidate/$terraform_state")" \
  --arg openapi_digest "$(digest_or_empty "$candidate/$openapi")" \
  --arg build_receipt_digest "$(digest_or_empty "$candidate/$build_receipt")" \
  --arg deployment_receipt_digest "$(digest_or_empty "$candidate/$deployment_receipt")" \
  --arg policy_receipt_digest "$(digest_or_empty "$candidate/$policy_receipt")" \
  --arg runtime1_digest "$(digest_or_empty "$candidate/$runtime_one")" --arg runtime2_digest "$(digest_or_empty "$candidate/$runtime_two")" \
  --argjson terraform_declaration_available "$terraform_declaration_available" --argjson terraform_declaration_matches "$terraform_declaration_matches" \
  --argjson service_source_available "$service_source_available" '
  def raw_digest: type=="string" and test("^[0-9a-f]{64}$");
  def expected_activities: [$denominator[0].cells[].activity]|sort;
  def actual_activities: [$runtime[0].graph.nodes[]?|select(.kind=="Activity")|.name]|sort;
  def activity_count: (expected_activities-(expected_activities-actual_activities))|length;
  def cli_count: ([
    ($runtime[0].release_identity_observed==true and $runtime[0].version.schema_version=="gooo-version/v1" and $runtime[0].version.version=="0.1.0-dev"),
    ($runtime[0].syntax_check.schema_version=="gooo/diagnostics/v1" and $runtime[0].syntax_check.status=="ok"),
    ($runtime[0].semantic_check.schema_version=="gooo/diagnostics/v1" and $runtime[0].semantic_check.status=="ok" and ($runtime[0].semantic_check.semantic_hash|raw_digest)),
    ($runtime[0].graph.schema_version=="gooo-graph/v1" and actual_activities==expected_activities)
  ]|map(select(.==true))|length);
  def plan_ok: $plan[0]!=null and $plan[0].format_version=="1.2" and $plan[0].errored==false and
    ([$plan[0].resource_changes[]|select(.address==$project[0].resource_address and .change.after.image_digest==$project[0].artifact_digest)]|length)==1;
  def state_status:
    if $state[0]==null then "UNKNOWN"
    elif ([$state[0].values.root_module.resources[]|select(.address==$project[0].resource_address and .values.id==$project[0].remote_id and .values.image_digest==$project[0].artifact_digest)]|length)==1 then "CLOSED"
    else "REFUTED" end;
  def openapi_ok: $openapi[0]!=null and $openapi[0].openapi=="3.1.0" and
    ([$openapi[0].paths[][]|select(.operationId==$project[0].openapi_operation)]|length)==1;
  def provenance_ok: $service_source_available and $build[0]!=null and $build[0].schema=="gooo/build-receipt/v1" and
    ([$build[0].materials[]|select(.path==$project[0].paths.service_source and .digest_policy=="EVALUATOR_SHA256_REQUIRED")]|length)==1 and
    ([$build[0].products[]|select(.digest==$project[0].artifact_digest)]|length)==1;
  def deployment_status:
    if state_status=="UNKNOWN" then "DEPENDENCY_BLOCKED"
    elif state_status=="REFUTED" then "DEPENDENCY_REFUTED"
    elif $deployment[0]==null then "UNKNOWN"
    elif $deployment[0].target==$project[0].deployment_target and $deployment[0].deployment_id==$project[0].remote_id and
      $deployment[0].artifact_digest==$project[0].artifact_digest and $deployment[0].generation==$deployment[0].observed_generation then "CLOSED"
    else "REFUTED" end;
  def policy_ok: $policy[0]!=null and $policy[0].policy_id==$project[0].policy_id and $policy[0].enforcement=="mandatory" and
    $policy[0].decision=="allow" and $policy[0].input.resource_address==$project[0].resource_address and
    $policy[0].input.target==$project[0].deployment_target and $policy[0].input.artifact_digest==$project[0].artifact_digest;
  def runtime_status:
    if state_status=="UNKNOWN" then "DEPENDENCY_BLOCKED"
    elif state_status=="REFUTED" or deployment_status=="REFUTED" or deployment_status=="DEPENDENCY_REFUTED" then "DEPENDENCY_REFUTED"
    elif $runtime1[0]==null or $runtime2[0]==null then "UNKNOWN"
    elif $runtime1[0].sequence==1 and $runtime2[0].sequence==2 and
      $runtime1[0].deployment_id==$project[0].remote_id and $runtime2[0].deployment_id==$project[0].remote_id and
      $runtime1[0].artifact_digest==$project[0].artifact_digest and $runtime2[0].artifact_digest==$project[0].artifact_digest and
      $runtime1[0].operation_id==$project[0].openapi_operation and $runtime2[0].operation_id==$project[0].openapi_operation and
      $runtime1[0].http_status==200 and $runtime2[0].http_status==200 and
      $runtime1[0].response.status=="ok" and $runtime2[0].response.status=="ok" then "CLOSED"
    else "REFUTED" end;
  def closed($c): $c+{state:"CLOSED",resolution:"EXACT",reason:$c.closed_reason,next_operation:"NONE",unknown_class:null,blocked_by:[]};
  def unknown($c;$reason;$next;$class;$blocked): $c+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",reason:$reason,next_operation:$next,unknown_class:$class,blocked_by:$blocked};
  def refuted($c;$reason;$next;$blocked): $c+{state:"REFUTED",resolution:"EXACT",reason:$reason,next_operation:$next,unknown_class:null,blocked_by:$blocked};
  def decide($c):
    if $c.id=="RELEASED_GOOO_IDENTITY" then if cli_count==4 then closed($c) else refuted($c;"RELEASED_GOOO_IDENTITY_MISMATCH";"RESTORE_PINNED_GOOO_RELEASE";[]) end
    elif $c.id=="GOOO_SOURCE_AUTHORITY" then if $project[0].schema=="gooo/infra-evidence/project/v1" then closed($c) else refuted($c;"INFRA_PROJECT_MANIFEST_INVALID";"RESTORE_INFRA_PROJECT_MANIFEST";[]) end
    elif $c.id=="GOOO_GRAPH_BINDING" then if activity_count==12 then closed($c) else refuted($c;"GOOO_INFRA_ACTIVITY_BINDING_MISMATCH";"RESTORE_GOOO_INFRA_ACTIVITIES";[]) end
    elif $c.id=="TERRAFORM_DECLARATION" then if $terraform_declaration_available and $terraform_declaration_matches then closed($c) else unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) end
    elif $c.id=="TERRAFORM_PLAN" then if plan_ok then closed($c) elif $plan[0]==null then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"TERRAFORM_PLAN_BINDING_MISMATCH";"RESTORE_TERRAFORM_PLAN_RECEIPT";[]) end
    elif $c.id=="TERRAFORM_STATE" then if state_status=="CLOSED" then closed($c) elif state_status=="UNKNOWN" then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"TERRAFORM_STATE_BINDING_MISMATCH";"RESTORE_TERRAFORM_STATE_RECEIPT";[]) end
    elif $c.id=="OPENAPI_CONTRACT" then if openapi_ok then closed($c) elif $openapi[0]==null then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"OPENAPI_OPERATION_MISMATCH";"RESTORE_OPENAPI_CONTRACT";[]) end
    elif $c.id=="SERVICE_ARTIFACT_PROVENANCE" then if provenance_ok then closed($c) elif $build[0]==null or ($service_source_available|not) then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"SERVICE_ARTIFACT_PROVENANCE_MISMATCH";"RESTORE_BUILD_RECEIPT";[]) end
    elif $c.id=="DEPLOYMENT_OUTPUT" then if deployment_status=="CLOSED" then closed($c) elif deployment_status=="DEPENDENCY_BLOCKED" then unknown($c;"DEPENDENCY_BLOCKED";"RESOLVE_TERRAFORM_STATE";"DEPENDENCY_BLOCKED";["TERRAFORM_STATE"]) elif deployment_status=="UNKNOWN" then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) elif deployment_status=="DEPENDENCY_REFUTED" then refuted($c;"DEPENDENCY_REFUTED";"RESOLVE_TERRAFORM_STATE";["TERRAFORM_STATE"]) else refuted($c;"ARTIFACT_IDENTITY_MISMATCH";"RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY";[]) end
    elif $c.id=="POLICY_DECISION" then if policy_ok then closed($c) elif $policy[0]==null then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"POLICY_DECISION_BINDING_MISMATCH";"RESTORE_POLICY_RECEIPT";[]) end
    elif $c.id=="RUNTIME_DRIFT_REGRESSION" then if runtime_status=="CLOSED" then closed($c) elif runtime_status=="DEPENDENCY_BLOCKED" then unknown($c;"DEPENDENCY_BLOCKED";"RESOLVE_TERRAFORM_STATE";"DEPENDENCY_BLOCKED";["TERRAFORM_STATE"]) elif runtime_status=="UNKNOWN" then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) elif runtime_status=="DEPENDENCY_REFUTED" then refuted($c;"DEPENDENCY_REFUTED";"RESTORE_DEPLOYMENT_IDENTITY";["DEPLOYMENT_OUTPUT"]) else refuted($c;"RUNTIME_ARTIFACT_DRIFT";"RESTORE_RUNTIME_ARTIFACT_IDENTITY";[]) end
    elif $c.id=="READ_ONLY_EFFECT" then if $runtime[0].repository.writes==0 and $runtime[0].repository.before_digest==$runtime[0].repository.after_digest then closed($c) elif $runtime[0].repository.writes==null then unknown($c;$c.unknown_reason;$c.next_operation;"DIRECT_MISSING";[]) else refuted($c;"REPOSITORY_WRITE_EFFECT_OBSERVED";"REMOVE_INPUT_REPOSITORY_WRITES";[]) end
    else unknown($c;"UNRECOGNIZED_CELL";"IMPLEMENT_EXPLICIT_CELL_DECISION";"DIRECT_MISSING";[]) end;
  ($denominator[0].cells|map(decide(.)|del(.closed_reason,.unknown_reason))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  ([$cells[]|select(.state=="REFUTED")][0]//null) as $first_refuted |
  ([$cells[]|select(.state=="UNKNOWN")][0]//null) as $first_unknown |
  {
    schema:"gooo/infra-evidence/report/v1",phase:$phase,subject_sha:$head_sha,service:$project[0].id,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "INCOMPLETE" else "EVIDENCE_CHAIN_CLOSED" end),
    claim:{id:"checkout://claim/infra-service-evidence",state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:(if $refuted_count>0 then $first_refuted.stage elif $unknown_count>0 then $first_unknown.stage else null end),step:(if $refuted_count>0 then $first_refuted.step elif $unknown_count>0 then $first_unknown.step else null end),
      reason:(if $refuted_count>0 then $first_refuted.reason elif $unknown_count>0 then $first_unknown.reason else "INFRA_SERVICE_EVIDENCE_CHAIN_CLOSED" end),
      next_operation:(if $refuted_count>0 then $first_refuted.next_operation elif $unknown_count>0 then $first_unknown.next_operation else "NONE" end),
      unknown_class:(if $unknown_count>0 and $refuted_count==0 then $first_unknown.unknown_class else null end),blocked_by:(if $refuted_count>0 then $first_refuted.blocked_by elif $unknown_count>0 then $first_unknown.blocked_by else [] end)},
    summary:{total:12,closed:$closed_count,unknown:$unknown_count,refuted:$refuted_count,direct_missing:([$cells[]|select(.unknown_class=="DIRECT_MISSING")]|length),dependency_blocked:([$cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length),repository_writes:$runtime[0].repository.writes},
    identities:{resource_address:$project[0].resource_address,remote_id:$project[0].remote_id,artifact_digest:$project[0].artifact_digest,deployment_target:$project[0].deployment_target,openapi_operation:$project[0].openapi_operation,service_source_digest:$service_source_digest},
    evidence_digests:{terraform_declaration:$terraform_declaration_digest,terraform_plan:$terraform_plan_digest,terraform_state:$terraform_state_digest,openapi:$openapi_digest,build_receipt:$build_receipt_digest,deployment_receipt:$deployment_receipt_digest,policy_receipt:$policy_receipt_digest,runtime_observation_1:$runtime1_digest,runtime_observation_2:$runtime2_digest},
    authority:{binding:"RELEASED_GOOO_GRAPH_ACTIVITY_SET",activity_bindings:activity_count,activity_total:12,terraform_execution:"NOT_CLAIMED",live_cloud_state:"NOT_CLAIMED",live_network_probe:"NOT_CLAIMED",publisher_signatures:"NOT_CLAIMED",source_spans:"NOT_AVAILABLE"},
    performance:$runtime[0].performance,cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $proof|{choice:$proof,closed:([$cells[]|select(.proof_choice==$proof and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$proof)]|length)})),
    indicators:[
      {id:"gooo.metric.infra-evidence.readiness.v1",value:$closed_count,total:12,unit:"cells",state:(if $closed_count==12 then "SATISFIED" else "GAP" end),activity:"ObserveRuntimeDrift"},
      {id:"gooo.metric.infra-evidence.cli-receipts.v1",value:cli_count,total:4,unit:"receipts",state:(if cli_count==4 then "SATISFIED" else "GAP" end),activity:"ObserveReleasedGoooIdentity"},
      {id:"gooo.metric.infra-evidence.activity-bindings.v1",value:activity_count,total:12,unit:"activities",state:(if activity_count==12 then "SATISFIED" else "GAP" end),activity:"BindInfraActivities"},
      {id:"gooo.metric.infra-evidence.plan-resources.v1",value:(if plan_ok then 1 else 0 end),total:1,unit:"resources",state:(if plan_ok then "SATISFIED" else "GAP" end),activity:"BindTerraformPlan"},
      {id:"gooo.metric.infra-evidence.state-bindings.v1",value:(if state_status=="CLOSED" then 1 else 0 end),total:1,unit:"bindings",state:(if state_status=="CLOSED" then "SATISFIED" elif state_status=="UNKNOWN" then "UNKNOWN" else "REFUTED" end),activity:"BindTerraformState"},
      {id:"gooo.metric.infra-evidence.openapi-operations.v1",value:(if openapi_ok then 1 else 0 end),total:1,unit:"operations",state:(if openapi_ok then "SATISFIED" else "GAP" end),activity:"ObserveOpenAPIContract"},
      {id:"gooo.metric.infra-evidence.provenance-edges.v1",value:([plan_ok,(state_status=="CLOSED"),provenance_ok,(deployment_status=="CLOSED"),(runtime_status=="CLOSED")]|map(select(.==true))|length),total:5,unit:"edges",state:(if plan_ok and state_status=="CLOSED" and provenance_ok and deployment_status=="CLOSED" and runtime_status=="CLOSED" then "SATISFIED" else "GAP" end),activity:"BindServiceArtifactProvenance"},
      {id:"gooo.metric.infra-evidence.policy-decisions.v1",value:(if policy_ok then 1 else 0 end),total:1,unit:"decisions",state:(if policy_ok then "SATISFIED" else "GAP" end),activity:"BindPolicyDecision"},
      {id:"gooo.metric.infra-evidence.runtime-observations.v1",value:(if runtime_status=="CLOSED" then 2 else 0 end),total:2,unit:"observations",state:(if runtime_status=="CLOSED" then "SATISFIED" elif runtime_status=="DEPENDENCY_BLOCKED" then "UNKNOWN" else "GAP" end),activity:"ObserveRuntimeDrift"},
      {id:"gooo.metric.infra-evidence.direct-missing.v1",value:([$cells[]|select(.unknown_class=="DIRECT_MISSING")]|length),total:12,unit:"cells",state:(if any($cells[];.unknown_class=="DIRECT_MISSING") then "GAP" else "SATISFIED" end),activity:"BindTerraformState"},
      {id:"gooo.metric.infra-evidence.dependency-blocked.v1",value:([$cells[]|select(.unknown_class=="DEPENDENCY_BLOCKED")]|length),total:12,unit:"cells",state:(if any($cells[];.unknown_class=="DEPENDENCY_BLOCKED") then "GAP" else "SATISFIED" end),activity:"BindDeploymentOutput"},
      {id:"gooo.metric.infra-evidence.graph-peak-rss.v1",value:$runtime[0].performance.graph_peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"ObserveReleasedGoooIdentity"},
      {id:"gooo.metric.infra-evidence.repository-writes.v1",value:$runtime[0].repository.writes,total:1,unit:"writes",state:(if $runtime[0].repository.writes==0 then "SATISFIED" else "REFUTED" end),activity:"ObserveReadOnlyEffect"}
    ]
  }' > "$output"
