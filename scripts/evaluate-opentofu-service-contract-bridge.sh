#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 10 ]; then
  printf 'usage: evaluate-opentofu-service-contract-bridge.sh ROOT ACTIONS_EVIDENCE ACTIVITY_BINDING RELEASE_EVIDENCE NORMAL UNKNOWN REFUTED REPLAY_A REPLAY_B OUTPUT\n' >&2
  exit 64
fi

root=$1
actions_evidence=$2
activity_binding=$3
release_evidence=$4
normal=$5
unknown=$6
refuted=$7
replay_a=$8
replay_b=$9
output=${10}
denominator="$root/contracts/opentofu-service-contract-bridge-denominator-v1.json"
ontology="$root/contracts/opentofu-service-contract-bridge-mapping-ontology-v1.json"

for required in "$denominator" "$ontology" "$actions_evidence" "$activity_binding" "$release_evidence" \
  "$normal/bundle.json" "$normal/mapping-ontology.json" "$normal/relations.ndjson" "$normal/causal-frontier.json" "$normal/counterexamples.json" "$normal/actions-evidence.json" "$normal/report.md" "$normal/manifest.json" \
  "$unknown/bundle.json" "$unknown/mapping-ontology.json" "$unknown/relations.ndjson" "$unknown/causal-frontier.json" "$unknown/counterexamples.json" "$unknown/actions-evidence.json" "$unknown/report.md" "$unknown/manifest.json" \
  "$refuted/bundle.json" "$refuted/mapping-ontology.json" "$refuted/relations.ndjson" "$refuted/causal-frontier.json" "$refuted/counterexamples.json" "$refuted/actions-evidence.json" "$refuted/report.md" "$refuted/manifest.json"; do
  test -f "$required" || { printf 'required bridge evidence unavailable: %s\n' "$required" >&2; exit 66; }
done

jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge-denominator/v1" and
  .target_cells==12 and (.cells|length)==12 and
  (.proof_totals|map(.total)|add)==12 and (.indicator_totals|map(.total)|add)==12 and
  .proof_totals==[{proof_choice:"FOUNDATION",total:4},{proof_choice:"COHERENCE",total:4},{proof_choice:"REGRESSION",total:4}] and
  .indicator_totals==[{indicator_class:"DRIVER",total:4},{indicator_class:"OUTCOME",total:4},{indicator_class:"GUARDRAIL",total:4}]
' "$denominator" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/mapping-ontology/v1" and
  .owner=="GOOO" and .authority_scope=="MAPPING_ONLY" and
  .name_similarity_mapping==false and .identity_policy=="EXACT_TYPED_IDENTITY_REQUIRED" and
  .decision_precedence==["REFUTED","UNKNOWN","CLOSED"] and (.relation_types|length)==5 and
  .unknown_policy.no_inference_from_names==true and .refuted_policy.identity_conflict_is_refuted==true
' "$ontology" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/actions-evidence/v2" and
  .go_version=="go1.27.0" and .authority.repository_writes==0 and
  .authority.local_test_executions==0 and .authority.cross_project_required_gates==0 and
  .authority.opentofu_binary_executions==1 and .authority.opentofu_version_executions==1 and .authority.opentofu_init_executions==0 and
  .authority.opentofu_plan_executions==0 and .authority.opentofu_apply_executions==0 and
  .authority.opentofu_test_executions==0 and .authority.opentofu_provider_accesses==0 and
  .authority.opentofu_remote_state_writes==0 and .authority.opentofu_cloud_accesses==0 and
  .authority.network_side_effects==0 and .authority.network_writes==0 and .authority.sibling_checkouts==0 and .authority.same_pr_evidence_cycles==0 and
  all([.phases.gooo_graph,.phases.activity_resolution,.phases.opentofu_identity][]; .execution_state=="EXECUTED" and .cache_state=="NOT_REUSED" and (.wall_ms|type)=="number" and (.peak_rss_kib|type)=="number" and .wall_ms>=0 and .peak_rss_kib>0 and .executed_count>0 and .reused_count==0 and .skipped_count==0) and
  all([.phases.build,.phases.test][]; .execution_state=="NOT_EXECUTED" and .cache_state=="NOT_APPLICABLE" and .wall_ms==null and .peak_rss_kib==null and .executed_count==0 and .reused_count==0 and .skipped_count==0) and
  .inventory.root_readme_excluded==true and all(.inventory.per_file[]; .path!="README.md")
' "$actions_evidence" >/dev/null
printf 'bridge evaluator: actions evidence accepted\n'

jq -e --slurpfile actions "$actions_evidence" '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/release-evidence/v2" and .identity_verified==true and
  .identity.iac_engine=="OPENTOFU" and .identity.version=="1.12.6" and
  .identity.release_repository=="opentofu/opentofu" and .identity.release_tag=="v1.12.6" and
  .identity.archive_sha256==$actions[0].iac_engine_identity.archive_sha256 and
  .identity.binary_sha256==$actions[0].iac_engine_identity.binary_sha256 and
  .identity.receipt_sha256==$actions[0].iac_engine_identity.receipt.sha256 and
  .identity.receipt_command==$actions[0].iac_engine_identity.receipt.command and
  .identity.receipt_phase.execution_state=="EXECUTED" and .identity.receipt_phase.cache_state=="NOT_REUSED" and
  .identity.receipt_phase.executed_count==1 and .identity.receipt_phase.reused_count==0 and .identity.receipt_phase.skipped_count==0 and
  .authority.source_checkouts==0 and .authority.opentofu_binary_executions==1 and .authority.opentofu_version_executions==1 and
  .authority.opentofu_init_executions==0 and .authority.opentofu_plan_executions==0 and .authority.opentofu_apply_executions==0 and
  .authority.opentofu_test_executions==0 and .authority.provider_accesses==0 and .authority.remote_state_writes==0 and .authority.cloud_accesses==0 and .authority.network_side_effects==0
' "$release_evidence" >/dev/null
test "$(jq -r '.release_evidence.digest' "$actions_evidence")" = "sha256:$(sha256sum "$release_evidence" | awk '{print $1}')"
printf 'bridge evaluator: immutable OpenTofu release/binary/receipt identity accepted\n'

jq -e '
  .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/activity-cell-binding/v1" and .exact==true and
  .denominator_total==12 and .graph_activity_total==12 and .resolution_total==12 and
  .resolution_phase.execution_state=="EXECUTED" and .resolution_phase.cache_state=="NOT_REUSED" and
  .resolution_phase.executed_count==12 and .resolution_phase.reused_count==0 and .resolution_phase.skipped_count==0 and
  .resolution_phase.wall_ms>=0 and .resolution_phase.peak_rss_kib>0
' "$activity_binding" >/dev/null
test "$(jq -r '.activity_cell_binding.digest' "$actions_evidence")" = "sha256:$(sha256sum "$activity_binding" | awk '{print $1}')"
printf 'bridge evaluator: exact activity-to-cell binding accepted\n'

check_manifest() {
  local directory=$1
  jq -e '
    .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/manifest/v1" and
    (.files|length)==7 and .manifest_covers=="all listed files except manifest.json"
  ' "$directory/manifest.json" >/dev/null
  while IFS=$'\t' read -r file expected; do
    test "$expected" = "$(sha256sum "$directory/$file" | awk '{print $1}')"
  done < <(jq -r '.files[]|[.path,.sha256]|@tsv' "$directory/manifest.json")
  printf 'bridge evaluator: manifest accepted %s\n' "$directory"
}

check_bundle() {
  local directory=$1 scenario=$2 decision=$3 closed=$4 unknown=$5 refuted=$6 relations=$7 frontier=$8
  jq -e \
    --arg scenario "$scenario" --arg decision "$decision" \
    --argjson closed "$closed" --argjson unknown "$unknown" --argjson refuted "$refuted" \
    --argjson relations "$relations" --argjson frontier "$frontier" --slurpfile d "$denominator" --slurpfile actions "$actions_evidence" '
    .schema=="gooo/infra-evidence/opentofu-service-contract-bridge/bundle/v1" and
    .scenario==$scenario and .decision==$decision and
    .denominator.total==12 and .denominator.decision_precedence==["REFUTED","UNKNOWN","CLOSED"] and .denominator.closed==$closed and .denominator.unknown==$unknown and .denominator.refuted==$refuted and
    .summary.total_cells==12 and .summary.closed_cells==$closed and .summary.unknown_cells==$unknown and .summary.refuted_cells==$refuted and
    .summary.repository_writes==0 and .summary.local_test_executions==0 and .summary.cross_project_required_gates==0 and
    .summary.opentofu_binary_executions==1 and .summary.opentofu_version_executions==1 and .summary.provider_accesses==0 and .summary.remote_state_writes==0 and .summary.cloud_accesses==0 and .summary.network_side_effects==0 and .summary.sibling_checkouts==0 and .summary.same_pr_evidence_cycles==0 and
    .summary.relations_observed==$relations and .summary.causal_frontier_observed==$frontier and .summary.counterexamples_observed==3 and
    (.cells|length)==12 and ([.cells[]|select(.state=="CLOSED")]|length)==$closed and
    ([.cells[]|select(.state=="UNKNOWN")]|length)==$unknown and ([.cells[]|select(.state=="REFUTED")]|length)==$refuted and
    all(.cells[]; if .state=="UNKNOWN" then
      (.stage!=null and .step!=null and .reason!=null and .unknown_class!=null and .next_operation!=null and (.blocked_by|type)=="array")
      elif .state=="REFUTED" then (.stage!=null and .step!=null and .reason!=null and .unknown_class==null and .next_operation!=null and (.blocked_by|type)=="array")
      else (.unknown_class==null and .next_operation=="NONE" and (.blocked_by|length)==0) end) and
    ([.cells[]|select(.state=="UNKNOWN")|[.stage,.step,.reason,.unknown_class,.next_operation,.blocked_by]]|all(length==6)) and
    .ontology.owner=="GOOO" and .inputs.opentofu_plan.engine=="OPENTOFU" and .inputs.opentofu_plan.representation=="PLAN" and .inputs.opentofu_plan.engine_identity_source=="VERIFIED_RELEASE_BINARY_AND_VERSION_RECEIPT" and
    .inputs.opentofu_state.engine=="OPENTOFU" and .inputs.opentofu_state.engine_identity_source=="VERIFIED_RELEASE_BINARY_AND_VERSION_RECEIPT" and
    .inputs.openapi.representation=="DOCUMENT" and .inputs.mapping.authority=="GOOO_OWNED_EXPLICIT_MAPPING" and
    .iac_engine_identity.iac_engine=="OPENTOFU" and .iac_engine_identity.version=="1.12.6" and
    .iac_engine_identity.release_repository=="opentofu/opentofu" and .iac_engine_identity.release_tag=="v1.12.6" and
    (.iac_engine_identity.archive_sha256|length)==64 and (.iac_engine_identity.binary_sha256|length)==64 and
    .iac_engine_identity.receipt.kind=="VERSION_JSON" and (.iac_engine_identity.receipt.sha256|test("^[0-9a-f]{64}$")) and
    .iac_engine_identity==$actions[0].iac_engine_identity and
    .activity_cell_binding.exact==true and .activity_cell_binding.denominator_total==12 and .activity_cell_binding.graph_activity_total==12 and .activity_cell_binding.resolution_total==12 and .activity_cell_binding.comparisons==12 and
    .prior_evidence_reuse.policy=="REUSE_ONLY_ON_EXACT_SUBJECT_SOURCE_TOOLCHAIN_COMMAND_INPUT_IDENTITY" and .prior_evidence_reuse.prior_evidence_used==false and .prior_evidence_reuse.reused_count==0 and
    .authority.repository_writes==0 and .authority.local_test_executions==0 and .authority.cross_project_required_gates==0 and
    .authority.opentofu_binary_executions==1 and .authority.opentofu_version_executions==1 and .authority.opentofu_apply_authorized==false and .authority.provider_install_authorized==false and .authority.remote_state_write_authorized==false and .authority.network_side_effects==0 and .authority.network_writes==0 and .authority.sibling_checkouts==0 and .authority.same_pr_evidence_cycles==0 and
    .improvement.state=="UNKNOWN" and .improvement.before_closed==null and .improvement.after_closed==null and
    .external_utility.observed==0 and .external_utility.total==1 and .external_utility.state=="UNKNOWN" and
    .denominator.proof_totals==$d[0].proof_totals and .denominator.indicator_totals==$d[0].indicator_totals
  ' "$directory/bundle.json" >/dev/null
  test "$(wc -l < "$directory/relations.ndjson" | tr -d ' ')" = "$relations"
  test "$(jq 'length' "$directory/causal-frontier.json")" = "$frontier"
  cmp -s "$directory/mapping-ontology.json" <(jq -S . "$ontology")
  grep -Fq '# OpenTofu service-contract bridge dossier' "$directory/report.md"
  grep -Fq '## Exact mapping' "$directory/report.md"
  grep -Fq '## Causal frontier' "$directory/report.md"
  grep -Fq '## Counterexamples' "$directory/report.md"
  grep -Fq '## Actions evidence' "$directory/report.md"
  grep -Fq '## Non-claims' "$directory/report.md"
  if grep -Eiq 'score|percentage|%' "$directory/report.md"; then
    printf 'aggregate score or percentage appeared in report: %s\n' "$directory/report.md" >&2
    exit 67
  fi
  printf 'bridge evaluator: bundle accepted %s\n' "$directory"
}

check_manifest "$normal"
check_manifest "$unknown"
check_manifest "$refuted"
check_bundle "$normal" normal CLOSED 12 0 0 5 0
check_bundle "$unknown" unknown UNKNOWN 9 3 0 4 2
check_bundle "$refuted" refuted FAIL_CLOSED 8 1 3 0 1

for directory in "$normal" "$unknown" "$refuted"; do
  cmp -s "$directory/actions-evidence.json" "$actions_evidence"
  test "$(jq -r '.actions_evidence.digest' "$directory/bundle.json")" = "sha256:$(sha256sum "$directory/actions-evidence.json" | awk '{print $1}')"
  test "$(jq -r '.evidence.iac_engine_identity_digest' "$directory/bundle.json")" = "sha256:$(jq -cS '.iac_engine_identity' "$directory/bundle.json" | sha256sum | awk '{print $1}')"
  test "$(jq -r '.activity_cell_binding.digest' "$directory/bundle.json")" = "$(jq -r '.activity_cell_binding.digest' "$actions_evidence")"
done

for file in bundle.json mapping-ontology.json relations.ndjson causal-frontier.json counterexamples.json actions-evidence.json report.md manifest.json; do
  cmp -s "$replay_a/$file" "$replay_b/$file"
  cmp -s "$normal/$file" "$replay_a/$file"
done
printf 'bridge evaluator: replay accepted\n'

subject_sha=$(jq -r '.subject_sha' "$normal/bundle.json")
jq -S -n \
  --arg subject_sha "$subject_sha" --slurpfile normal "$normal/bundle.json" --slurpfile unknown "$unknown/bundle.json" \
  --slurpfile refuted "$refuted/bundle.json" --slurpfile actions "$actions_evidence" \
  '{schema:"gooo/infra-evidence/opentofu-service-contract-bridge/evaluation/v1",decision:"CONFORMANT",subject_sha:$subject_sha,
    fixed_denominator:{total:12,precedence:["REFUTED","UNKNOWN","CLOSED"],cases:[
      {scenario:"normal",closed:$normal[0].denominator.closed,unknown:$normal[0].denominator.unknown,refuted:$normal[0].denominator.refuted},
      {scenario:"unknown",closed:$unknown[0].denominator.closed,unknown:$unknown[0].denominator.unknown,refuted:$unknown[0].denominator.refuted},
      {scenario:"refuted",closed:$refuted[0].denominator.closed,unknown:$refuted[0].denominator.unknown,refuted:$refuted[0].denominator.refuted}]},
    proof_totals:$normal[0].denominator.proof_totals,indicator_totals:$normal[0].denominator.indicator_totals,
    replay:{state:"CLOSED",comparisons:8,byte_identical:true},release_lock:$normal[0].release_lock,
    actions_evidence:{go_version:$actions[0].go_version,inventory:$actions[0].inventory,phases:$actions[0].phases,build:$actions[0].build,test:$actions[0].test,authority:$actions[0].authority},
    iac_engine_identity:$actions[0].iac_engine_identity,activity_cell_binding:$actions[0].activity_cell_binding,prior_evidence_reuse:$actions[0].prior_evidence_reuse,
    improvement:{before_closed:null,after_closed:null,state:"UNKNOWN",reason:"EXACT_MATCHED_INTEGER_PAIR_MISSING"},
    external_utility:{observed:0,total:1,state:"UNKNOWN",reason:"NO_EXTERNAL_USER_RECEIPT"},incidents:[],
    authority:{repository_writes:0,local_test_executions:0,cross_project_required_gates:0,opentofu_binary_executions:1,opentofu_version_executions:1,opentofu_init_executions:0,opentofu_plan_executions:0,opentofu_apply_executions:0,opentofu_test_executions:0,provider_accesses:0,remote_state_writes:0,cloud_accesses:0,network_side_effects:0,network_writes:0,sibling_checkouts:0,same_pr_evidence_cycles:0,operational_refuted_executions:0}}' > "$output"
