#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 11; then
  echo "usage: evaluate-deployment-contract-packet.sh DENOMINATOR NORMAL MANIFEST RUNBOOK MISSING DRIFT HANDLER AUTHORITY RUNTIME OUTPUT SUBJECT_SHA" >&2
  exit 2
fi

denominator=$1
normal=$2
manifest=$3
runbook=$4
missing=$5
drift=$6
handler=$7
authority=$8
runtime=$9
output=${10}
subject_sha=${11}

for file in "$denominator" "$normal" "$manifest" "$runbook" "$missing" "$drift" "$handler" "$authority" "$runtime"; do
  test -f "$file" || { echo "missing deployment conformance input: $file" >&2; exit 2; }
done

jq -e '.schema=="gooo/infra-evidence/deployment-contract-packet-denominator/v1" and .total==15 and (.cells|length)==15 and ([.proofs[].total]|add)==15 and ([.indicator_classes[].total]|add)==15' "$denominator" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/deployment-contract-packet/v1" and .scenario=="complete" and
  .decision=="DEPLOYMENT_CONTRACT_PACKET_GENERATED" and .candidate.state=="GENERATED" and
  .claim.state=="CLOSED" and .claim.reason=="INFRA_DEPLOYMENT_CONTRACT_PACKET_GENERATED" and
  .summary.total_cells==15 and .summary.closed_cells==15 and .summary.unknown_cells==0 and .summary.refuted_cells==0 and
  .summary.release_inputs_observed==3 and .summary.infra_evidence_cells_closed==12 and
  .summary.claim_adoption_cells_closed==12 and .summary.terraform_bindings_observed==1 and
  .summary.openapi_service_bindings_observed==1 and .summary.semantic_edges_observed==6 and
  .summary.deployment_chain_cells_closed==4 and .summary.released_claim_tuples_observed==3 and
  .summary.released_claim_fields_observed==18 and .summary.meta_decision_receipts_observed==5 and
  .summary.meta_decision_fields_observed==30 and .summary.generated_artifacts_observed==3 and
  .summary.publishable_artifacts==3 and .summary.counterexamples_observed==4 and
  .summary.repository_writes==0 and .summary.local_tests_run==0 and .summary.cross_project_required_gates==0 and
  (.claim_tuples|length)==3 and (.decision_receipts|length)==5 and
  ([.proofs[]|select(.closed==5 and .total==5)]|length)==3 and
  ([.indicator_classes[]|select(.closed==5 and .total==5)]|length)==3 and
  .authority.terraform_apply_authorized==false and .authority.deployment_execution_authorized==false and
  .authority.network_probe_authorized==false and .authority.repository_writes_authorized==false
' "$normal" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/deployment-generation-manifest/v1" and
  .decision=="DEPLOYMENT_CONTRACT_PACKET_GENERATED" and (.targets|length)==3 and
  ([.targets[]|select(.state=="BOUND")]|length)==3 and
  .authority.terraform_apply_authorized==false and .authority.deployment_execution_authorized==false
' "$manifest" >/dev/null
jq -e '
  .scenario=="missing-state" and .decision=="DEPLOYMENT_CONTRACT_PACKET_UNKNOWN" and
  .claim.state=="UNKNOWN" and .claim.stage=="INFRA_STATE" and .claim.step=="BIND_TERRAFORM_STATE" and
  .claim.reason=="TERRAFORM_STATE_UNAVAILABLE" and .claim.unknown_class=="DIRECT_MISSING" and
  .claim.next_operation=="PROVIDE_TERRAFORM_STATE_RECEIPT" and
  .summary.closed_cells==11 and .summary.unknown_cells==4 and .summary.refuted_cells==0 and
  .summary.infra_evidence_cells_closed==9 and .summary.terraform_bindings_observed==0 and
  .summary.deployment_chain_cells_closed==2 and .summary.publishable_artifacts==0 and
  ([.cells[]|select(.state=="UNKNOWN" and .unknown_class=="DEPENDENCY_BLOCKED")]|length)==3
' "$missing" >/dev/null
jq -e '
  .scenario=="artifact-drift" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
  .claim.stage=="DEPLOYMENT" and .claim.reason=="ARTIFACT_IDENTITY_MISMATCH" and
  .claim.next_operation=="RESTORE_DEPLOYMENT_ARTIFACT_IDENTITY" and
  .summary.closed_cells==12 and .summary.refuted_cells==3 and .summary.infra_evidence_cells_closed==10 and
  .summary.deployment_chain_cells_closed==3 and .summary.publishable_artifacts==0
' "$drift" >/dev/null
jq -e '
  .scenario=="handler-ambiguity" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
  .claim.stage=="SERVICE_SYMBOL" and .claim.reason=="GO_HANDLER_REGISTRATION_CARDINALITY_MISMATCH" and
  .claim.next_operation=="RESTORE_UNIQUE_METHOD_PATH_REGISTRATION" and
  .summary.closed_cells==11 and .summary.refuted_cells==4 and .summary.infra_evidence_cells_closed==8 and
  .summary.openapi_service_bindings_observed==0 and .summary.semantic_edges_observed==5 and
  .summary.deployment_chain_cells_closed==2 and .summary.publishable_artifacts==0
' "$handler" >/dev/null
jq -e '
  .scenario=="authority-escalation" and .decision=="FAIL_CLOSED" and .claim.state=="REFUTED" and
  .claim.stage=="AUTHORITY" and .claim.reason=="EXECUTION_AUTHORITY_ESCALATED" and
  .claim.next_operation=="REMOVE_APPLY_AND_DEPLOY_AUTHORITY" and
  .summary.closed_cells==13 and .summary.refuted_cells==2 and .summary.publishable_artifacts==0 and
  .authority.terraform_apply_authorized==true and .authority.deployment_execution_authorized==true
' "$authority" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/deployment-contract-packet-runtime/v1" and .go_version=="go1.27.0" and
  .go_fix_module_roots>=0 and .release_locks_observed==3 and .decision_receipts_equal==5 and
  .replay_comparisons_equal==3 and .peak_rss_kib>0 and .wall_ms>=0 and
  .inventory.root_readme_excluded==true and
  (.inventory.per_file|length)==(.inventory.go.files+.inventory.gooo.files) and
  .repository_writes==0 and .local_tests_run==0 and .cross_project_required_gates==0
' "$runtime" >/dev/null

grep -Fq '# Gooo Infrastructure Deployment Contract' "$runbook"
grep -Fq -- '- Decision: `DEPLOYMENT_CONTRACT_PACKET_GENERATED`' "$runbook"
grep -Fq -- '- Publishable artifacts: 3/3' "$runbook"
grep -Fq '## Terraform binding' "$runbook"
grep -Fq '## OpenAPI to service binding' "$runbook"
grep -Fq '## Deployment evidence chain' "$runbook"
grep -Fq '## Resolution coordinates' "$runbook"
grep -Fq '## Authority' "$runbook"

digest() { printf 'sha256:%s' "$(sha256sum "$1" | awk '{print $1}')"; }
jq -S -n \
  --slurpfile denominator "$denominator" --slurpfile normal "$normal" --slurpfile runtime "$runtime" \
  --arg subject_sha "$subject_sha" --arg denominator_digest "$(digest "$denominator")" \
  --arg normal_digest "$(digest "$normal")" --arg manifest_digest "$(digest "$manifest")" \
  --arg runbook_digest "$(digest "$runbook")" --arg missing_digest "$(digest "$missing")" \
  --arg drift_digest "$(digest "$drift")" --arg handler_digest "$(digest "$handler")" \
  --arg authority_digest "$(digest "$authority")" --arg runtime_digest "$(digest "$runtime")" '
  $denominator[0] as $d | $runtime[0] as $runtime |
  [$d.cells[]|{id,activity,proof_choice,indicator_class,state:"CLOSED",stage:null,step:null,
    reason:.closed_reason,unknown_class:null,next_operation:"NONE",blocked_by:[]}] as $cells |
  {
    schema:"gooo/infra-evidence/deployment-contract-packet-conformance/v1",subject_sha:$subject_sha,
    decision:"INFRA_DEPLOYMENT_CONTRACT_PACKET_CONFORMANT",
    candidate:{id:$d.candidate_id,state:"IMPLEMENTED",implementation_status:"INDEPENDENT_USER_PATH_OBSERVED"},
    claim:{state:"CLOSED",stage:null,step:null,reason:"INFRA_DEPLOYMENT_CONTRACT_PACKET_CONFORMANT",
      unknown_class:null,next_operation:"PUBLISH_IMMUTABLE_INFRA_DEPLOYMENT_PACKET_RELEASE",blocked_by:[]},
    summary:{total_cells:15,closed_cells:15,unknown_cells:0,refuted_cells:0,
      release_inputs_total:3,release_inputs_observed:3,infra_evidence_cells_total:12,infra_evidence_cells_observed:12,
      claim_adoption_cells_total:12,claim_adoption_cells_observed:12,terraform_bindings_total:1,terraform_bindings_observed:1,
      openapi_service_bindings_total:1,openapi_service_bindings_observed:1,semantic_edges_total:6,semantic_edges_observed:6,
      deployment_chain_cells_total:4,deployment_chain_cells_observed:4,released_claim_tuples_total:3,released_claim_tuples_observed:3,
      released_claim_fields_total:18,released_claim_fields_observed:18,meta_decision_receipts_total:5,
      meta_decision_receipts_observed:5,meta_decision_fields_total:30,meta_decision_fields_observed:30,
      generated_artifacts_total:3,generated_artifacts_observed:3,counterexamples_total:4,counterexamples_observed:4,
      replay_comparisons_total:3,replay_comparisons_equal:$runtime.replay_comparisons_equal,
      repository_writes:$runtime.repository_writes,local_tests_run:$runtime.local_tests_run,
      cross_project_required_gates:$runtime.cross_project_required_gates},
    inventory:$runtime.inventory,performance:{peak_rss_kib:$runtime.peak_rss_kib,wall_ms:$runtime.wall_ms},
    cells:$cells,proofs:[$d.proofs[]|{choice,total,closed:.total}],
    indicator_classes:[$d.indicator_classes[]|{class,total,closed:.total}],
    indicators:[
      {id:"gooo.metric.infra-packet.release-inputs.v1",class:"DRIVER",value:3,total:3,unit:"releases",activity:"ObserveInfraEvidenceRelease"},
      {id:"gooo.metric.infra-packet.evidence-cells.v1",class:"DRIVER",value:12,total:12,unit:"cells",activity:"ObserveInfraEvidenceRelease"},
      {id:"gooo.metric.infra-packet.claim-adoption-cells.v1",class:"DRIVER",value:12,total:12,unit:"cells",activity:"ObserveClaimAdoptionRelease"},
      {id:"gooo.metric.infra-packet.terraform-bindings.v1",class:"OUTCOME",value:1,total:1,unit:"bindings",activity:"ProjectTerraformDeploymentBinding"},
      {id:"gooo.metric.infra-packet.openapi-service-bindings.v1",class:"OUTCOME",value:1,total:1,unit:"bindings",activity:"ProjectOpenAPIServiceBinding"},
      {id:"gooo.metric.infra-packet.semantic-edges.v1",class:"OUTCOME",value:6,total:6,unit:"edges",activity:"ProjectArtifactDeploymentChain"},
      {id:"gooo.metric.infra-packet.claim-tuples.v1",class:"OUTCOME",value:3,total:3,unit:"tuples",activity:"ObserveClaimAdoptionRelease"},
      {id:"gooo.metric.infra-packet.generated-artifacts.v1",class:"OUTCOME",value:3,total:3,unit:"artifacts",activity:"GenerateDeploymentPacketArtifacts"},
      {id:"gooo.metric.infra-packet.counterexamples.v1",class:"GUARDRAIL",value:4,total:4,unit:"scenarios",activity:"PreserveMissingStateUnknown"},
      {id:"gooo.metric.infra-packet.replay.v1",class:"GUARDRAIL",value:$runtime.replay_comparisons_equal,total:3,unit:"comparisons",activity:"ObserveDeploymentPacketRuntime"},
      {id:"gooo.metric.infra-packet.repository-writes.v1",class:"GUARDRAIL",value:$runtime.repository_writes,total:0,unit:"writes",activity:"ObserveDeploymentPacketRuntime"},
      {id:"gooo.metric.infra-packet.peak-rss.v1",class:"GUARDRAIL",value:$runtime.peak_rss_kib,unit:"KiB",activity:"ObserveDeploymentPacketRuntime"},
      {id:"gooo.metric.infra-packet.wall-time.v1",class:"GUARDRAIL",value:$runtime.wall_ms,unit:"ms",activity:"ObserveDeploymentPacketRuntime"}
    ],
    authority:{meta_source:"examples/deployment-contract-packet/main.gooo",resolution_source:"GOOO_ACTIVITY_VALUE_PROGRAM",
      terraform_apply_authorized:false,deployment_execution_authorized:false,network_probe_authorized:false,
      repository_writes_authorized:false,central_orchestration_authorized:false},
    evidence:{denominator_digest:$denominator_digest,normal_digest:$normal_digest,manifest_digest:$manifest_digest,
      runbook_digest:$runbook_digest,missing_digest:$missing_digest,drift_digest:$drift_digest,
      handler_digest:$handler_digest,authority_digest:$authority_digest,runtime_digest:$runtime_digest}
  }
' > "$output"
