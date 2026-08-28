#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 8; then
  echo "usage: evaluate-released-domain-envelope-v2.sh ROOT DENOM CORE_RECEIPTS FACTS BUNDLE CONFORMER_REPORT OUTPUT PHASE" >&2
  exit 64
fi

root=$1
denom=$2
core_receipts=$3
facts=$4
bundle=$5
conformer_report=$6
output=$7
phase=$8

for required in "$root" "$denom" "$core_receipts" "$facts" "$bundle/project.json" "$bundle/conformance.json" "$bundle/evidence.ndjson" "$bundle/relations.ndjson" "$bundle/resolutions.ndjson" "$bundle/unknowns.ndjson" "$bundle/replay.json" "$bundle/checksums.txt" "$conformer_report"; do
  test -e "$required" || { echo "required evidence unavailable: $required" >&2; exit 66; }
done
case "$root" in
  /*) ;;
  *) echo "repository root must be absolute" >&2; exit 66 ;;
esac
case "$(realpath "$output")" in
  "$(realpath "$root")"|"$(realpath "$root")"/*)
    echo "evaluation output must not be inside the repository" >&2
    exit 66
    ;;
esac

jq -S -n \
  --slurpfile denominator "$denom" \
  --slurpfile core "$core_receipts" \
  --slurpfile facts "$facts" \
  --slurpfile project "$bundle/project.json" \
  --slurpfile conformance "$conformer_report" \
  --arg subject_sha "$(jq -r '.subject_sha // empty' "$facts")" \
  --arg phase "$phase" '
  $denominator[0] as $d |
  $facts[0] as $f |
  ($core[0] | map({key:.selector.name,value:.}) | from_entries) as $receipt_by |

  def text: type=="string" and length>0;
  def valid_unknown($r):
    $r.decision=="UNKNOWN" and $r.occurrences==0 and
    $r.claim.state=="UNKNOWN" and $r.claim.reason=="ACTIVITY_NOT_FOUND" and
    ($r.claim.stage|text) and ($r.claim.step|text) and ($r.claim.reason|text) and
    ($r.claim.unknown_class|text) and ($r.claim.next_operation|text) and
    ($r.claim.next_operation!="NONE") and ($r.claim.blocked_by|type)=="array";
  def core_state($activity):
    ($receipt_by[$activity]//null) as $r |
    if $r==null then
      {state:"UNKNOWN",decision:"UNKNOWN",occurrences:0,stage:"RESOLUTION",step:"RESOLVE_ACTIVITY_CARDINALITY",
       reason:"CORE_ACTIVITY_RESOLUTION_RECEIPT_UNAVAILABLE",unknown_class:"DIRECT_MISSING",
       next_operation:"PROVIDE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    elif $r.decision=="CLOSED" and $r.occurrences==1 and $r.claim.state=="CLOSED" and
         $r.claim.reason=="ACTIVITY_UNIQUELY_RESOLVED" then
      {state:"CLOSED",decision:"CLOSED",occurrences:$r.occurrences,stage:null,step:null,reason:"ACTIVITY_UNIQUELY_RESOLVED",
       unknown_class:null,next_operation:"NONE",blocked_by:[]}
    elif valid_unknown($r) then
      {state:"UNKNOWN",decision:"UNKNOWN",occurrences:$r.occurrences,stage:$r.claim.stage,step:$r.claim.step,
       reason:$r.claim.reason,unknown_class:$r.claim.unknown_class,next_operation:$r.claim.next_operation,
       blocked_by:$r.claim.blocked_by}
    elif $r.decision=="UNKNOWN" then
      {state:"REFUTED",decision:$r.decision,occurrences:($r.occurrences//null),stage:"RESOLUTION",
       step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"MALFORMED_CORE_UNKNOWN",unknown_class:null,
       next_operation:"RESTORE_VALID_CORE_UNKNOWN_RECEIPT",blocked_by:[]}
    else
      {state:"REFUTED",decision:($r.decision//"UNAVAILABLE"),occurrences:($r.occurrences//null),stage:"RESOLUTION",
       step:"RESOLVE_ACTIVITY_CARDINALITY",reason:"UNRECOGNIZED_CORE_ACTIVITY_RESOLUTION_DECISION",unknown_class:null,
       next_operation:"RESTORE_CORE_ACTIVITY_RESOLUTION_RECEIPT",blocked_by:[]}
    end;

  def fact($id):
    if $id=="CORE_RELEASE" then $f.core_release.verified
    elif $id=="INTERCHANGE_SPEC_RELEASE" then $f.interchange_spec_release.verified
    elif $id=="INFRA_RELEASE" then $f.infra_release.verified
    elif $id=="META_ACTIVITY_AUTHORITY" then
      $f.meta_activity_authority.activities_observed==$d.target_cells and
      $f.meta_activity_authority.resolutions_observed==$d.target_cells
    elif $id=="INFRA_DEPENDENCY_SOURCE" then
      $f.infra_dependency_source.relations_observed==$d.expected.relations and
      $f.infra_dependency_source.prior_openapi_bindings==$d.expected.prior_infra.openapi_bindings and
      $f.infra_dependency_source.prior_terraform_bindings==$d.expected.prior_infra.terraform_bindings and
      $f.infra_dependency_source.prior_deployment_chain_cells==$d.expected.prior_infra.deployment_chain_cells
    elif $id=="PRODUCT_PROJECTION" then $f.product_projection.observed==true
    elif $id=="EIGHT_FILE_ENVELOPE" then
      $f.envelope.files==$d.expected.envelope_files and
      $f.envelope.relations==$d.expected.relations and
      $f.envelope.evidence==$d.expected.evidence and
      $f.envelope.resolutions==$d.expected.resolutions
    elif $id=="READ_ONLY_CONFORMANCE" then
      $f.conformer.decision=="CONFORMANT" and
      $f.conformer.closed==$d.expected.local_checks and $f.conformer.total==$d.expected.local_checks
    elif $id=="UNKNOWN_CAUSALITY" then
      if $f.unknown_causality==null then ($phase|startswith("unknown") or $phase|startswith("refuted"))
      else $f.unknown_causality.reports_observed >= $d.expected.unknown_paths_min and
        $f.unknown_causality.coordinates_observed==$d.expected.unknown_coordinates and
        $f.unknown_causality.direct_missing_observed>=1 and
        $f.unknown_causality.dependency_blocked_observed>=1
      end
    elif $id=="DETERMINISTIC_REPLAY" then
      $f.replay.source_satisfied==$d.expected.source_replay and
      $f.replay.file_satisfied==$d.expected.file_replay
    elif $id=="REFUTED_COUNTEREXAMPLES" then
      if $f.refuted_counterexamples==null then ($phase|startswith("unknown") or $phase|startswith("refuted"))
      else $f.refuted_counterexamples.reports_observed >= $d.expected.refuted_paths_min and
        $f.refuted_counterexamples.malformed_unknown_state=="REFUTED" and
        $f.refuted_counterexamples.fixed_point_state=="REFUTED"
      end
    elif $id=="AUTHORITY_BOUNDARY" then
      $f.authority.repository_writes==0 and $f.authority.local_tests==0 and
      $f.authority.cross_project_required_gates==0 and
      $f.authority.kit_source_checkout==0 and $f.authority.conformer_copy==0 and
      ($f.authority.forbidden_authority_escalations|length)==0
    else null end;

  def direct($cell):
    (core_state($cell.activity)) as $cr |
    if $cr.state=="REFUTED" then
      ($cell + {state:"REFUTED",resolution:"EXACT",stage:$cr.stage,step:$cr.step,reason:$cr.reason,
        unknown_class:null,next_operation:$cr.next_operation,blocked_by:$cr.blocked_by,core_resolution:$cr})
    elif $cr.state=="UNKNOWN" then
      ($cell + {state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cr.stage,step:$cr.step,reason:$cr.reason,
        unknown_class:$cr.unknown_class,next_operation:$cr.next_operation,blocked_by:$cr.blocked_by,core_resolution:$cr})
    elif fact($cell.id)==true then
      ($cell + {state:"CLOSED",resolution:"EXACT",stage:null,step:null,reason:$cell.closed_reason,
        unknown_class:null,next_operation:"NONE",blocked_by:[],core_resolution:$cr})
    elif fact($cell.id)==false then
      ($cell + {state:"REFUTED",resolution:"EXACT",stage:$cell.stage,step:$cell.step,reason:$cell.refuted_reason,
        unknown_class:null,next_operation:$cell.next_operation,blocked_by:[],core_resolution:$cr})
    else
      ($cell + {state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cell.stage,step:$cell.step,reason:$cell.unknown_reason,
        unknown_class:"OBSERVATION_MISSING",next_operation:$cell.next_operation,blocked_by:[],core_resolution:$cr})
    end;

  def frontier($dependencies):
    ([$dependencies[] | if (.blocked_by|length)>0 then .blocked_by[] else .id end] | unique | sort);

  (reduce $d.cells[] as $cell ([ ];
    . as $prior |
    (direct($cell)) as $candidate |
    ([$prior[] | . as $p | select(($cell.depends_on | index($p.id)) != null)]) as $dependencies |
    ([$dependencies[] | select(.state=="REFUTED")]) as $refuted_dependencies |
    ([$dependencies[] | select(.state=="UNKNOWN")]) as $unknown_dependencies |
    if $candidate.state=="REFUTED" then .+[$candidate]
    elif ($refuted_dependencies|length)>0 then
      .+[$candidate + {state:"REFUTED",resolution:"EXACT",stage:$cell.stage,step:$cell.step,
        reason:"DEPENDENCY_REFUTED",unknown_class:null,next_operation:"RESOLVE_REFUTED_PREDECESSORS",
        blocked_by:frontier($refuted_dependencies)}]
    elif $candidate.state=="UNKNOWN" then .+[$candidate]
    elif ($unknown_dependencies|length)>0 then
      .+[$candidate + {state:"UNKNOWN",resolution:"PREREQUISITE_CLASS",stage:$cell.stage,step:$cell.step,
        reason:"DEPENDENCY_BLOCKED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:"RESOLVE_UNKNOWN_FRONTIER",
        blocked_by:frontier($unknown_dependencies)}]
    else .+[$candidate] end)) as $cells |
  ([$cells[]|select(.state=="CLOSED")]|length) as $closed |
  ([$cells[]|select(.state=="UNKNOWN")]|length) as $unknown |
  ([$cells[]|select(.state=="REFUTED")]|length) as $refuted |
  ([$cells[]|select(.state!="CLOSED")][0]//null) as $first |
  {schema:"gooo/infra-evidence/released-domain-envelope-v2-adoption-report/v1",subject_sha:$subject_sha,phase:$phase,
   decision:(if $refuted>0 then "FAIL_CLOSED" elif $unknown>0 then "INCOMPLETE" else "ADOPTION_CANDIDATE_CONFORMANT" end),
   claim:(if $first==null then
      {state:"CLOSED",stage:null,step:null,reason:"INFRA_RELEASED_DOMAIN_ENVELOPE_CONFORMANT",unknown_class:null,next_operation:"MERGE_INFRA_ADOPTION_PR",blocked_by:[]}
    else {state:$first.state,stage:$first.stage,step:$first.step,reason:$first.reason,unknown_class:$first.unknown_class,
      next_operation:$first.next_operation,blocked_by:$first.blocked_by} end),
   summary:{total:$d.target_cells,closed:$closed,unknown:$unknown,refuted:$refuted,
     relations_observed:$f.envelope.relations,evidence_observed:$f.envelope.evidence,resolutions_observed:$f.envelope.resolutions,
     envelope_files:$f.envelope.files,kit_checks:$f.conformer.closed,kit_checks_total:$f.conformer.total,
     prior_semantic_dependencies:$f.infra_dependency_source.relations_observed,
     prior_openapi_bindings:$f.infra_dependency_source.prior_openapi_bindings,
     prior_terraform_bindings:$f.infra_dependency_source.prior_terraform_bindings,
     prior_deployment_chain_cells:$f.infra_dependency_source.prior_deployment_chain_cells,
     normal_paths:$f.paths.normal,unknown_paths:$f.paths.unknown,refuted_paths:$f.paths.refuted,
     unknown_coordinates:$f.unknown_causality.coordinates_observed,source_replay:$f.replay.source_satisfied,file_replay:$f.replay.file_satisfied},
   adoption:{released_domain:{observed:$d.expected.released_adoption.observed,total:$d.expected.released_adoption.total,state:"UNKNOWN",reason:"RELEASE_NOT_PUBLISHED"},external_utility:$f.utility},
   authority:$f.authority,artifacts:$f.artifacts,metrics:$f.metrics,
   proofs:([$d.proof_totals[]|.proof_choice] | map(. as $choice|{choice:$choice,closed:([$cells[]|select(.proof_choice==$choice and .state=="CLOSED")]|length),total:([$cells[]|select(.proof_choice==$choice)]|length)})),
   indicator_classes:([$d.indicator_totals[]|.indicator_class] | map(. as $class|{class:$class,closed:([$cells[]|select(.indicator_class==$class and .state=="CLOSED")]|length),total:([$cells[]|select(.indicator_class==$class)]|length)})),
   cells:($cells|map(del(.closed_reason,.unknown_reason,.refuted_reason,.depends_on)))
  }
' > "$output"
