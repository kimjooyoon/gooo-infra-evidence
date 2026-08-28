#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 9; then
  echo "usage: evaluate-claim-resolution-adoption.sh ROOT RECEIPTS INFRA_ACTIONS NORMAL_REPORT TOOLCHAIN RUNTIME OUTPUT HEAD_SHA PHASE" >&2
  exit 64
fi

root=$(cd "$1" && pwd)
receipts=$2
infra_actions=$3
normal_report=$4
toolchain=$5
runtime=$6
output=$7
head_sha=$8
phase=$9
denominator="$root/contracts/claim-resolution-adoption-denominator-v1.json"
lock="$root/contracts/claim-resolution-adoption-release-lock-v1.json"
source="$root/examples/claim-resolution-adoption/main.gooo"

for required in "$denominator" "$lock" "$source" "$normal_report" "$toolchain" "$runtime"; do
  test -f "$required" || { echo "missing required input: $required" >&2; exit 66; }
done

jq -e '.target_cells==12 and (.cells|length)==12 and ([.cells[].ordinal]|unique|length)==12 and
  ([.cells[].activity]|unique|length)==12 and ([.proof_totals[].total]|add)==12 and ([.indicator_totals[].total]|add)==12' "$denominator" >/dev/null
jq -e '.schema=="gooo/infra-evidence/claim-resolution-adoption-release-lock/v1" and .core.tag=="v0.3.0-dev" and .infra.tag=="v0.5.0-dev"' "$lock" >/dev/null
test "$(grep -c '^activity ' "$source")" -eq 12
grep -Fq 'gooo.primitive.claim-resolution-tuple.v1' "$source"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

json_or_null() {
  if test -f "$1" && jq -e . "$1" >/dev/null 2>&1; then
    cp "$1" "$2"
  else
    printf 'null\n' > "$2"
  fi
}

: > "$work/receipt-map.ndjson"
while IFS= read -r activity; do
  json_or_null "$receipts/$activity.json" "$work/$activity.json"
  jq -cn --arg key "$activity" --slurpfile value "$work/$activity.json" '{key:$key,value:$value[0]}' >> "$work/receipt-map.ndjson"
done < <(jq -r '.cells[].activity' "$denominator")
jq -s 'from_entries' "$work/receipt-map.ndjson" > "$work/receipts.json"

json_or_null "$receipts/ReplayClaimResolution.replay.json" "$work/replay.json"
json_or_null "$infra_actions/context-hcl.json" "$work/unknown.json"
json_or_null "$infra_actions/deployment-drift.json" "$work/refuted.json"

: > "$work/source-lines.ndjson"
while IFS= read -r -d '' file; do
  relative=${file#"$root/"}
  lines=$(wc -l < "$file" | tr -d ' ')
  case "$file" in
    *.go) language=Go ;;
    *.gooo) language=Gooo ;;
    *) continue ;;
  esac
  jq -cn --arg path "$relative" --arg language "$language" --argjson lines "$lines" \
    '{path:$path,language:$language,lines:$lines}' >> "$work/source-lines.ndjson"
done < <(find "$root" -type f -not -path "$root/.git/*" \( -name '*.go' -o -name '*.gooo' \) -print0 | sort -z)

repository_files=$(find "$root" -type f -not -path "$root/.git/*" | wc -l | tr -d ' ')
descendant_directories=$(find "$root" -mindepth 1 -type d -not -path "$root/.git" -not -path "$root/.git/*" | wc -l | tr -d ' ')
jq -s --argjson repository_files "$repository_files" --argjson descendant_directories "$descendant_directories" '
  . as $files |
  {repository_files:$repository_files,descendant_directories:$descendant_directories,root_readme_readiness:"EXCLUDED",
   go:{files:([$files[]|select(.language=="Go")]|length),lines:([$files[]|select(.language=="Go")|.lines]|add//0)},
   gooo:{files:([$files[]|select(.language=="Gooo")]|length),lines:([$files[]|select(.language=="Gooo")|.lines]|add//0)},
   per_file:$files}' "$work/source-lines.ndjson" > "$work/inventory.json"

jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile lock "$lock" --slurpfile receipts "$work/receipts.json" \
  --slurpfile closed "$normal_report" --slurpfile unknown "$work/unknown.json" --slurpfile refuted "$work/refuted.json" \
  --slurpfile replay "$work/replay.json" --slurpfile toolchain "$toolchain" --slurpfile runtime "$runtime" \
  --slurpfile inventory "$work/inventory.json" --rawfile source "$source" --arg head_sha "$head_sha" --arg phase "$phase" '
  def has_six($claim):
    ($claim|type)=="object" and ($claim|has("state")) and ($claim|has("stage")) and ($claim|has("step")) and
    ($claim|has("reason")) and ($claim|has("unknown_class")) and ($claim|has("next_operation"));
  def field_count($claim):
    if ($claim|type)!="object" then 0 else
      [($claim|has("state")),($claim|has("stage")),($claim|has("step")),($claim|has("reason")),
       ($claim|has("unknown_class")),($claim|has("next_operation"))] | map(select(.==true)) | length
    end;
  def normalize($claim):
    {state:$claim.state,stage:($claim.stage//"NONE"),step:($claim.step//"NONE"),reason:$claim.reason,
     unknown_class:(if (($claim.unknown_class//"")=="") then "NONE" else $claim.unknown_class end),next_operation:$claim.next_operation};
  def receipt($activity): $receipts[0][$activity];
  def bound($activity):
    (receipt($activity)) as $r |
    $r!=null and $r.schema=="gooo/claim-resolution/v1" and $r.candidate_id=="gooo.primitive.claim-resolution-tuple.v1" and
    $r.subject.activity==$activity and $r.subject.activity_occurrences==1 and $r.summary.fields_observed==6 and $r.summary.fields_total==6;
  def observed($activity): bound($activity) and receipt($activity).decision=="CLAIM_RESOLUTION_OBSERVED";
  def rejected($activity;$reason): bound($activity) and receipt($activity).decision=="FAIL_CLOSED" and receipt($activity).claim.reason==$reason;
  def same_claim($activity;$claim): observed($activity) and has_six($claim) and (normalize(receipt($activity).claim)==normalize($claim));
  ($closed[0].claim//null) as $closed_claim |
  ($unknown[0].claim//null) as $unknown_claim |
  ($refuted[0].claim//null) as $refuted_claim |
  ((field_count($closed_claim))+(field_count($unknown_claim))+(field_count($refuted_claim))) as $released_fields |
  ((field_count(receipt("ResolveReleasedClosedClaim").claim))+
   (field_count(receipt("PreserveReleasedUnknownClaim").claim))+
   (field_count(receipt("PreserveReleasedRefutedClaim").claim))) as $core_fields |
  ([same_claim("ResolveReleasedClosedClaim";$closed_claim),same_claim("PreserveReleasedUnknownClaim";$unknown_claim),
    same_claim("PreserveReleasedRefutedClaim";$refuted_claim)]|map(select(.==true))|length) as $scenario_matches |
  ([rejected("RejectIncompleteUnknownTuple";"UNKNOWN_TUPLE_INCOMPLETE"),
    rejected("RejectUnknownParentDecision";"CLAIM_STATE_UNKNOWN")]|map(select(.==true))|length) as $invalid_rejections |
  ([$denominator[0].cells[].activity|select(bound(.))]|length) as $activities_bound |
  {
    ObserveReleasedInfraEvidence:(observed("ObserveReleasedInfraEvidence") and $runtime[0].infra_release_observed==true),
    ObserveReleasedClaimPrimitive:(observed("ObserveReleasedClaimPrimitive") and $runtime[0].core_release_observed==true),
    BindReleasedClosedClaim:same_claim("BindReleasedClosedClaim";$closed_claim),
    ResolveReleasedClosedClaim:same_claim("ResolveReleasedClosedClaim";$closed_claim),
    BindReleasedUnknownClaim:same_claim("BindReleasedUnknownClaim";$unknown_claim),
    PreserveReleasedUnknownClaim:same_claim("PreserveReleasedUnknownClaim";$unknown_claim),
    BindReleasedRefutedClaim:same_claim("BindReleasedRefutedClaim";$refuted_claim),
    PreserveReleasedRefutedClaim:same_claim("PreserveReleasedRefutedClaim";$refuted_claim),
    RejectIncompleteUnknownTuple:rejected("RejectIncompleteUnknownTuple";"UNKNOWN_TUPLE_INCOMPLETE"),
    RejectUnknownParentDecision:rejected("RejectUnknownParentDecision";"CLAIM_STATE_UNKNOWN"),
    ReplayClaimResolution:(observed("ReplayClaimResolution") and $replay[0]!=null and $replay[0]==receipt("ReplayClaimResolution")),
    ObserveReadOnlyEffect:(observed("ObserveReadOnlyEffect") and $runtime[0].repository.writes==0 and
      $runtime[0].authority.cross_project_required_gates==0 and $runtime[0].authority.generator_authority==false and
      $runtime[0].authority.local_test_executions==0 and $runtime[0].authority.go_fix_module_roots==0 and
      $toolchain[0].version=="go1.27.0" and $toolchain[0].fix_changes==0)
  } as $facts |
  def upstream_missing($activity):
    (($activity=="BindReleasedClosedClaim" or $activity=="ResolveReleasedClosedClaim") and $closed_claim==null) or
    (($activity=="BindReleasedUnknownClaim" or $activity=="PreserveReleasedUnknownClaim") and $unknown_claim==null) or
    (($activity=="BindReleasedRefutedClaim" or $activity=="PreserveReleasedRefutedClaim") and $refuted_claim==null);
  def evaluate($cell):
    ($cell.activity) as $activity |
    if receipt($activity)==null then
      $cell + {state:"UNKNOWN",stage:"CORE_RECEIPT",step:"OBSERVE_CLAIM_RESOLUTION_RECEIPT",reason:"CORE_CLAIM_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_CORE_CLAIM_RESOLUTION_RECEIPT"}
    elif upstream_missing($activity) then
      $cell + {state:"UNKNOWN",reason:$cell.unknown_reason,unknown_class:"DIRECT_MISSING"}
    elif $facts[$activity]==true then
      $cell + {state:"CLOSED",reason:$cell.closed_reason,unknown_class:null,next_operation:"NONE"}
    else
      $cell + {state:"REFUTED",reason:$cell.refuted_reason,unknown_class:null}
    end;
  ($denominator[0].cells|map(evaluate(.))) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed_count |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown_count |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted_count |
  (([$cells[]|select(.state=="REFUTED")]|first)//([$cells[]|select(.state=="UNKNOWN")]|first)) as $first_nonclosed |
  {
    schema:"gooo/infra-evidence/claim-resolution-adoption-report/v1",phase:$phase,subject_sha:$head_sha,
    decision:(if $refuted_count>0 then "FAIL_CLOSED" elif $unknown_count>0 then "INCOMPLETE" else "ADOPTION_EVIDENCE_CLOSED" end),
    claim:{state:(if $refuted_count>0 then "REFUTED" elif $unknown_count>0 then "UNKNOWN" else "CLOSED" end),
      stage:($first_nonclosed.stage//null),step:($first_nonclosed.step//null),
      reason:($first_nonclosed.reason//"INFRA_CLAIM_RESOLUTION_ADOPTION_CLOSED"),
      unknown_class:($first_nonclosed.unknown_class//null),next_operation:($first_nonclosed.next_operation//"NONE")},
    summary:{total:12,closed:$closed_count,unknown:$unknown_count,refuted:$refuted_count,
      direct_missing:([$cells[]|select(.unknown_class=="DIRECT_MISSING")]|length),dependency_blocked:0},
    adoption:{candidate_id:"gooo.primitive.claim-resolution-tuple.v1",direct_mappings:1,direct_mapping_total:1,
      independent_consumers:1,released_scenarios:$scenario_matches,released_scenario_total:3,
      released_claim_fields:$released_fields,released_claim_field_total:18,core_claim_fields:$core_fields,core_claim_field_total:18,
      invalid_tuples_rejected:$invalid_rejections,invalid_tuple_total:2,activities_bound:$activities_bound,activity_total:12,
      release_locks_observed:([$runtime[0].core_release_observed,$runtime[0].infra_release_observed]|map(select(.==true))|length),release_lock_total:2},
    authority:{evidence:"PINNED_IMMUTABLE_RELEASE_ASSETS",core_mutation_authorized:false,generator_authority:$runtime[0].authority.generator_authority,
      cross_project_required_gates:$runtime[0].authority.cross_project_required_gates,local_test_executions:$runtime[0].authority.local_test_executions,
      go_fix_module_roots:$runtime[0].authority.go_fix_module_roots,root_readme_readiness:"EXCLUDED",repository_writes:$runtime[0].repository.writes,
      terraform_execution:"NOT_CLAIMED",live_cloud_state:"NOT_CLAIMED",deployment_execution:"NOT_CLAIMED",live_network_probe:"NOT_CLAIMED"},
    performance:$runtime[0].performance,toolchain:$toolchain[0],inventory:$inventory[0],cells:$cells,
    proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
    indicator_classes:(["DRIVER","OUTCOME","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
    indicators:[
      {id:"gooo.metric.infra-claim-adoption.direct-mappings.v1",class:"OUTCOME",activity:"ResolveReleasedClosedClaim",value:1,total:1,unit:"mappings"},
      {id:"gooo.metric.infra-claim-adoption.scenario-equivalence.v1",class:"OUTCOME",activity:"ReplayClaimResolution",value:$scenario_matches,total:3,unit:"scenarios"},
      {id:"gooo.metric.infra-claim-adoption.released-claim-fields.v1",class:"DRIVER",activity:"BindReleasedUnknownClaim",value:$released_fields,total:18,unit:"fields"},
      {id:"gooo.metric.infra-claim-adoption.core-claim-fields.v1",class:"DRIVER",activity:"PreserveReleasedUnknownClaim",value:$core_fields,total:18,unit:"fields"},
      {id:"gooo.metric.infra-claim-adoption.invalid-tuples-rejected.v1",class:"GUARDRAIL",activity:"RejectUnknownParentDecision",value:$invalid_rejections,total:2,unit:"tuples"},
      {id:"gooo.metric.infra-claim-adoption.meta-activities.v1",class:"DRIVER",activity:"ObserveReleasedClaimPrimitive",value:$activities_bound,total:12,unit:"activities"},
      {id:"gooo.metric.infra-claim-adoption.repository-writes.v1",class:"GUARDRAIL",activity:"ObserveReadOnlyEffect",value:$runtime[0].repository.writes,total:0,unit:"writes"},
      {id:"gooo.metric.infra-claim-adoption.claim-resolve-peak-rss.v1",class:"DRIVER",activity:"ResolveReleasedClosedClaim",value:$runtime[0].performance.claim_resolve_peak_rss_kib,unit:"KiB"},
      {id:"gooo.metric.infra-claim-adoption.claim-resolve-wall-time.v1",class:"DRIVER",activity:"ResolveReleasedClosedClaim",value:$runtime[0].performance.claim_resolve_wall_ms,unit:"ms"},
      {id:"gooo.metric.infra-claim-adoption.go-lines.v1",class:"DRIVER",activity:"ObserveReleasedInfraEvidence",value:$inventory[0].go.lines,unit:"lines"},
      {id:"gooo.metric.infra-claim-adoption.gooo-lines.v1",class:"DRIVER",activity:"ObserveReleasedClaimPrimitive",value:$inventory[0].gooo.lines,unit:"lines"}
    ]
  }' > "$output"
