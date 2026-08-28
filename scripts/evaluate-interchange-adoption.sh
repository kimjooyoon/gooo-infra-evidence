#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 5; then
  echo "usage: evaluate-interchange-adoption.sh ROOT CORE_RECEIPTS FACTS OUTPUT SUBJECT_SHA" >&2
  exit 64
fi
root=$1
core_receipts=$2
facts=$3
output=$4
subject_sha=$5
denominator="$root/contracts/interchange-adoption-denominator-v1.json"
for file in "$denominator" "$core_receipts" "$facts"; do test -f "$file" || exit 65; done

jq -S -n --slurpfile denominator "$denominator" --slurpfile core "$core_receipts" --slurpfile facts "$facts" --arg subject_sha "$subject_sha" '
  $denominator[0] as $d | $facts[0] as $f |
  ($core[0]|map({key:.selector.name,value:.})|from_entries) as $receipt_by |
  def strip: del(.closed_reason,.unknown_reason,.refuted_reason,.restore_operation);
  def normalized_core($cell):
    ($receipt_by[$cell.activity]//null) as $r |
    if $r==null then {decision:"UNKNOWN",state:"UNKNOWN",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",next_operation:"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT",activity_occurrences:0}
    elif $r.decision=="CLOSED" and $r.occurrences==1 and $r.claim.state=="CLOSED" and $r.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" then {decision:"CLOSED",state:"CLOSED",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"FACT_OBSERVED",unknown_class:null,next_operation:"NONE",activity_occurrences:$r.occurrences}
    elif $r.decision=="UNKNOWN" then {decision:$r.decision,state:"UNKNOWN",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:($r.claim.reason//"CORE_ACTIVITY_RESOLUTION_UNKNOWN"),unknown_class:($r.claim.unknown_class//"DIRECT_MISSING"),next_operation:($r.claim.next_operation//"RESOLVE_CORE_ACTIVITY"),activity_occurrences:($r.occurrences//0)}
    else {decision:($r.decision//"UNAVAILABLE"),state:"REFUTED",stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION",unknown_class:null,next_operation:"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT",activity_occurrences:($r.occurrences//0)} end;
  def fact($id):
    if $id=="RELEASED_GOOO_IDENTITY" then $f.core_release_verified
    elif $id=="INTERCHANGE_RELEASE_IDENTITY" then $f.specification.identity_verified
    elif $id=="INFRA_EVIDENCE_AUTHORITY" then $f.domain.authority=="INFRA_EVIDENCE"
    elif $id=="ADOPTION_STATE" then ($f.adoption_state|IN("PR_CANDIDATE","MAIN_MERGED"))
    elif $id=="FIVE_FILE_ENVELOPE" then ($f.contract.required_files==5 and $f.contract.required_local_checks==6 and $f.contract.relation_states==["MATCH","MISMATCH","UNKNOWN"] and ($f.contract.unknown_fields|length)==5)
    elif $id=="ADVISORY_BUNDLE" then $f.bundle.generated_files==5
    elif $id=="SIX_LOCAL_CHECKS" then ($f.bundle.decision=="CONFORMANT" and $f.bundle.closed==6 and $f.bundle.total==6)
    elif $id=="RELATION_MATCH" then $f.bundle.relation_state=="MATCH"
    elif $id=="DETERMINISTIC_REPLAY" then $f.bundle.replay_closed
    elif $id=="UNKNOWN_TUPLE_GUARD" then ($f.adversarial.unknown_tuple.decision=="FAIL_CLOSED" and $f.adversarial.unknown_tuple.refuted==1 and $f.adversarial.unknown_tuple.reason=="UNKNOWN_TUPLE_INCOMPLETE")
    elif $id=="CHECKSUM_DRIFT_GUARD" then ($f.adversarial.checksum_drift.decision=="FAIL_CLOSED" and $f.adversarial.checksum_drift.refuted==1 and $f.adversarial.checksum_drift.reason=="SHA256_CHECKSUM_MISMATCH")
    elif $id=="INDEPENDENT_READ_ONLY_EFFECT" then ($f.runtime.repository.writes==0 and $f.contract.external_required_gates==0 and $f.runtime.local_tests_run==0)
    else null end;
  def direct($cell):
    (normalized_core($cell)) as $cr |
    if $cr.state=="REFUTED" then ($cell|strip)+{state:"REFUTED",resolution:"EXACT",stage:$cr.stage,step:$cr.step,reason:$cr.reason,next_operation:$cr.next_operation,unknown_class:null,blocked_by:[],core_resolution:$cr}
    elif $cr.state=="UNKNOWN" then ($cell|strip)+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cr.stage,step:$cr.step,reason:$cr.reason,next_operation:$cr.next_operation,unknown_class:$cr.unknown_class,blocked_by:[],core_resolution:$cr}
    elif fact($cell.id)==true then ($cell|strip)+{state:"CLOSED",resolution:"EXACT",reason:$cell.closed_reason,next_operation:"NONE",unknown_class:null,blocked_by:[],core_resolution:$cr}
    elif fact($cell.id)==null then ($cell|strip)+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",reason:$cell.unknown_reason,next_operation:$cell.next_operation,unknown_class:"OBSERVATION_MISSING",blocked_by:[],core_resolution:$cr}
    else ($cell|strip)+{state:"REFUTED",resolution:"EXACT",reason:$cell.refuted_reason,next_operation:$cell.restore_operation,unknown_class:null,blocked_by:[],core_resolution:$cr} end;
  (reduce $d.cells[] as $cell ([];
    . as $prior | (direct($cell)) as $candidate |
    ([$prior[]|.id as $id|select(($cell.depends_on|index($id))!=null)|select(.state=="REFUTED")]) as $refuted_dependencies |
    ([$prior[]|.id as $id|select(($cell.depends_on|index($id))!=null)|select(.state=="UNKNOWN")]) as $unknown_dependencies |
    if $candidate.state=="REFUTED" then .+[$candidate]
    elif ($refuted_dependencies|length)>0 then .+[($candidate+{state:"REFUTED",resolution:"EXACT",reason:"DEPENDENCY_REFUTED",next_operation:"RESOLVE_REFUTED_PREDECESSORS",unknown_class:null,blocked_by:[$refuted_dependencies[].id]})]
    elif $candidate.state=="UNKNOWN" then .+[$candidate]
    elif ($unknown_dependencies|length)>0 then .+[($candidate+{state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",reason:"DEPENDENCY_UNKNOWN",next_operation:"RESOLVE_UNKNOWN_PREDECESSORS",unknown_class:"DEPENDENCY",blocked_by:[$unknown_dependencies[].id]})]
    else .+[$candidate] end)) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$cells[]|select(.state!="CLOSED")][0]//null) as $first |
  {schema:"gooo/infra-evidence/interchange-adoption-report/v1",subject_sha:$subject_sha,
   decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "ADOPTION_CONFORMANT" end),
   claim:(if $first==null then {state:"CLOSED",stage:null,step:null,reason:"INTERCHANGE_ADOPTION_CONFORMANT",next_operation:(if $f.adoption_state=="MAIN_MERGED" then "PUBLISH_IMMUTABLE_ADOPTION_RELEASE" else "MERGE_ADOPTION_PR" end),unknown_class:null,blocked_by:[]} else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,next_operation:$first.next_operation,unknown_class:$first.unknown_class,blocked_by:$first.blocked_by} end),
   summary:{total:$d.total,closed:$closed,unknown:$unknown,refuted:$refuted,bundle_files:$f.bundle.generated_files,local_checks_closed:$f.bundle.closed,local_checks_total:$f.bundle.total},
   adoption:{state:$f.adoption_state,released_domain_adoption:{scope:"THIS_RELEASE",observed:(if $f.adoption_state=="MAIN_MERGED" then 1 else 0 end),total:1},portfolio_adoption:{state:"UNKNOWN",observed:null,total:3,stage:"PORTFOLIO",step:"COUNT_RELEASED_DOMAIN_ADOPTIONS",reason:"OTHER_DOMAIN_RELEASES_NOT_OBSERVED",unknown_class:"SCOPE_DEFERRED",next_operation:"OBSERVE_WITH_GOOO_LINK"},connector_implementation:"NOT_STARTED"},
   authority:{root_readme_readiness:$d.root_readme_readiness,cross_project_required_gates:$f.contract.external_required_gates,current_external_branches:0},
   contract:$f.contract,cells:$cells,
   proofs:(["FOUNDATION","COHERENCE","REGRESSION"]|map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
   indicator_classes:(["OUTCOME","DRIVER","GUARDRAIL"]|map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
   indicators:[
     {id:"gooo.metric.infra-evidence.interchange-adoption.v1",value:(if $f.adoption_state=="MAIN_MERGED" then 1 else 0 end),total:1,unit:"this_release",state:"OBSERVED",activity:"ObserveAdoptionState"},
     {id:"gooo.metric.infra-evidence.interchange-files.v1",value:$f.bundle.generated_files,total:5,unit:"files",state:(if $f.bundle.generated_files==5 then "SATISFIED" else "GAP" end),activity:"GenerateAdvisoryBundle"},
     {id:"gooo.metric.infra-evidence.interchange-checks.v1",value:$f.bundle.closed,total:$f.bundle.total,unit:"checks",state:(if $f.bundle.closed==$f.bundle.total then "SATISFIED" else "GAP" end),activity:"ConformSixLocalChecks"},
     {id:"gooo.metric.infra-evidence.interchange-replay.v1",value:(if $f.bundle.replay_closed then 1 else 0 end),total:1,unit:"replays",state:(if $f.bundle.replay_closed then "SATISFIED" else "GAP" end),activity:"ObserveDeterministicReplay"},
     {id:"gooo.metric.infra-evidence.interchange-unknown-guard.v1",value:$f.adversarial.unknown_tuple.refuted,total:1,unit:"refutations",state:(if $f.adversarial.unknown_tuple.refuted==1 then "SATISFIED" else "GAP" end),activity:"PreserveUnknownTuple"},
     {id:"gooo.metric.infra-evidence.interchange-checksum-guard.v1",value:$f.adversarial.checksum_drift.refuted,total:1,unit:"refutations",state:(if $f.adversarial.checksum_drift.refuted==1 then "SATISFIED" else "GAP" end),activity:"RejectChecksumDrift"},
     {id:"gooo.metric.infra-evidence.interchange-repository-writes.v1",value:$f.runtime.repository.writes,total:0,unit:"writes",state:(if $f.runtime.repository.writes==0 then "SATISFIED" else "REFUTED" end),activity:"PreserveIndependentReadOnlyEffect"},
     {id:"gooo.metric.infra-evidence.interchange-external-gates.v1",value:$f.contract.external_required_gates,total:0,unit:"required_gates",state:(if $f.contract.external_required_gates==0 then "SATISFIED" else "REFUTED" end),activity:"PreserveIndependentReadOnlyEffect"},
     {id:"gooo.metric.infra-evidence.interchange-peak-rss.v1",value:$f.runtime.exporter.peak_rss_kib,unit:"KiB",state:"OBSERVED",activity:"GenerateAdvisoryBundle"},
     {id:"gooo.metric.infra-evidence.interchange-wall-time.v1",value:$f.runtime.exporter.wall_ms,unit:"ms",state:"OBSERVED",activity:"GenerateAdvisoryBundle"}
   ],runtime:$f.runtime}' > "$output"
