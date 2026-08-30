#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: conform-opentofu-receipt-transformation-v1.sh PUBLISH_DIR DENOMINATOR PRODUCER_DIR OUTPUT" >&2
  exit 2
fi

publish=$1
denominator=$2
producer=$3
output=$4

test "$(jq -r '.schema' "$denominator")" = "gooo/infra-evidence/opentofu-receipt-v1-transformation-denominator/v1"
test "$(jq -r '.target_cells' "$denominator")" = 12
test "$(jq '[.cells[].activity]|unique|length' "$denominator")" = 12
test "$(jq '[.cells[]|select(.proof_choice=="FOUNDATION")]|length' "$denominator")" = 4
test "$(jq '[.cells[]|select(.proof_choice=="COHERENCE")]|length' "$denominator")" = 4
test "$(jq '[.cells[]|select(.proof_choice=="REGRESSION")]|length' "$denominator")" = 4
test "$(jq '[.cells[]|select(.indicator_class=="DRIVER")]|length' "$denominator")" = 4
test "$(jq '[.cells[]|select(.indicator_class=="OUTCOME")]|length' "$denominator")" = 4
test "$(jq '[.cells[]|select(.indicator_class=="GUARDRAIL")]|length' "$denominator")" = 4

test "$(find "$producer" -type f | wc -l | tr -d ' ')" = 59
test "$(find "$publish/consumer" -type f | wc -l | tr -d ' ')" = 11
test "$(find "$publish/cases" -type f | wc -l | tr -d ' ')" = 5
test "$(find "$publish" -maxdepth 1 -type f | wc -l | tr -d ' ')" = 2
test "$(find "$publish" -type f | wc -l | tr -d ' ')" = 77

for scenario in normal-a normal-b missing-pattern unauthorized-operation refuted-over-unknown; do
  receipt="$producer/conform-$scenario.json"
  test -s "$receipt"
  jq -e --arg scenario "$scenario" '
    .schema=="gooo/evidence-generator/transformation-conformance/v1" and
    .decision=="CONFORMANT" and .scenario==$scenario and
    .subject_sha=="c60dfed9c082d91b9b20e3f465b3a7f2c0f522a0" and
    .manifest.total==8 and .manifest.verified==8 and .effect.internal_replay_equal==true and
    .effect.before.total==12 and .effect.after.total==12 and
    (.effect.before.closed+.effect.before.unknown+.effect.before.refuted)==12 and
    (.effect.after.closed+.effect.after.unknown+.effect.after.refuted)==12
  ' "$receipt" >/dev/null
done

for scenario in normal-a normal-b missing-pattern unauthorized-operation refuted-over-unknown; do
  manifest="$producer/$scenario/manifest.json"
  test -s "$manifest"
  while IFS=$'\t' read -r path expected; do
    test "$(sha256sum "$producer/$scenario/$path" | awk '{print $1}')" = "$expected"
  done < <(jq -r '.files[]|[.path,.sha256]|@tsv' "$manifest")
done

test "$(jq -r '.schema' "$publish/consumer/syntax.json")" = "gooo/diagnostics/v1"
test "$(jq -r '.status' "$publish/consumer/syntax.json")" = ok
test "$(jq -r '.schema' "$publish/consumer/semantic.json")" = "gooo/diagnostics/v1"
test "$(jq -r '.status' "$publish/consumer/semantic.json")" = ok
jq -e '
  .schema_version=="gooo-graph/v1" and
  ([.nodes[]|select(.kind=="Activity")]|length)==12 and
  ([.nodes[]|select(.kind=="Activity")|.name]|unique|length)==12 and
  ([.nodes[]|select(.kind=="Entity")]|length)==13
' "$publish/consumer/graph.json" >/dev/null
jq -e '
  length==12 and all(.[];.decision=="CLOSED" and .occurrences==1 and .claim.state=="CLOSED") and
  ([.[].activity]|unique|length)==12
' "$publish/consumer/resolved-activities.json" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-consumer-bindings/v1" and
  .verified==true and .binding_cells==12 and .producer_activity_count==12 and
  .consumer_activity_count==12 and (.bindings|length)==12 and
  ([.bindings[].producer_activity]|unique|length)==12 and
  ([.bindings[].consumer_activity]|unique|length)==12 and
  .target_mapping.producer_cell_id=="UNKNOWN_TRACE" and
  .target_mapping.consumer_cell_id=="OPENTOFU_RECEIPT_UNKNOWN_TRACE"
' "$publish/consumer/activity-bindings.json" >/dev/null

pair_before="$publish/consumer/before.json"
pair_after="$publish/consumer/after.json"
pair_tmp=$(mktemp -d /tmp/gooo-opentofu-receipt-pair.XXXXXX)
trap 'rm -rf "$pair_tmp"' EXIT
jq -e --argjson cells 12 '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-semantic-unit/v1" and
  (.cells|length)==$cells and ([.cells[].id]|unique|length)==$cells
' "$pair_before" >/dev/null
jq -e --argjson cells 12 '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-semantic-unit/v1" and
  (.cells|length)==$cells and ([.cells[].id]|unique|length)==$cells
' "$pair_after" >/dev/null
target=OPENTOFU_RECEIPT_UNKNOWN_TRACE
jq -e --arg target "$target" '
  ([.cells[]|select(.id==$target)]|length)==1 and
  ([.cells[]|select(.id==$target)][0]|.state=="UNKNOWN" and
    ([.stage,.step,.reason,.unknown_class,.next_operation,.blocked_by]|map(select(.!=null))|length)==6)
' "$pair_before" >/dev/null
jq -e --arg target "$target" '
  ([.cells[]|select(.id==$target)]|length)==1 and
  ([.cells[]|select(.id==$target)][0]|.state=="CLOSED" and .unknown_class==null and .next_operation=="NONE")
' "$pair_after" >/dev/null
jq -S --arg target "$target" 'del(.id) | .cells |= map(select(.id != $target))' "$pair_before" > "$pair_tmp/before-unrelated.json"
jq -S --arg target "$target" 'del(.id) | .cells |= map(select(.id != $target))' "$pair_after" > "$pair_tmp/after-unrelated.json"
test "$(sha256sum "$pair_tmp/before-unrelated.json" | awk '{print $1}')" = "$(sha256sum "$pair_tmp/after-unrelated.json" | awk '{print $1}')"
before_closed=$(jq '[.cells[]|select(.state=="CLOSED")]|length' "$pair_before")
before_unknown=$(jq '[.cells[]|select(.state=="UNKNOWN")]|length' "$pair_before")
before_refuted=$(jq '[.cells[]|select(.state=="REFUTED")]|length' "$pair_before")
after_closed=$(jq '[.cells[]|select(.state=="CLOSED")]|length' "$pair_after")
after_unknown=$(jq '[.cells[]|select(.state=="UNKNOWN")]|length' "$pair_after")
after_refuted=$(jq '[.cells[]|select(.state=="REFUTED")]|length' "$pair_after")
test $((before_closed+before_unknown+before_refuted)) -eq 12
test $((after_closed+after_unknown+after_refuted)) -eq 12

jq -e '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-case/v1" and
  .summary.total==12 and (.summary.closed+.summary.unknown+.summary.refuted)==12 and
  .claim.state=="CLOSED" and .decision=="CLOSED"
' "$publish/cases/normal.json" >/dev/null
jq -e --argjson coordinates 6 '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-case/v1" and
  .summary.total==12 and (.summary.closed+.summary.unknown+.summary.refuted)==12 and
  .summary.unknown==1 and .summary.refuted==0 and .claim.state=="UNKNOWN" and
  ([.claim.stage,.claim.step,.claim.reason,.claim.unknown_class,.claim.next_operation,.claim.blocked_by]|map(select(.!=null))|length)==$coordinates
' "$publish/cases/unknown-missing-evidence.json" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-case/v1" and
  .summary.total==12 and (.summary.closed+.summary.unknown+.summary.refuted)==12 and
  .summary.refuted>0 and .summary.unknown==0 and .claim.state=="REFUTED" and
  .effect.digest_valid==true and .effect.transition_count==0 and .authority_escalation==true
' "$publish/cases/refuted-digest-valid-laundering.json" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-case/v1" and
  .summary.total==12 and (.summary.closed+.summary.unknown+.summary.refuted)==12 and
  .summary.refuted>0 and .summary.unknown>0 and .claim.state=="REFUTED" and
  .precedence.refuted_over_unknown==true and .precedence.selected_state=="REFUTED"
' "$publish/cases/refuted-over-unknown.json" >/dev/null
jq -e '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-case/v1" and
  .summary.total==12 and (.summary.closed+.summary.unknown+.summary.refuted)==12 and
  .summary.closed==12 and .summary.unknown==0 and .summary.refuted==0 and .claim.state=="CLOSED"
' "$publish/cases/normal-replay.json" >/dev/null

jq -e --argjson files 79 --argjson pair_closed 1 --argjson pair_unknown -1 '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-transformation-adoption/v1" and
  .decision=="OPENTOFU_RECEIPT_TRANSFORMATION_CONSUMER_CLOSED" and .resolution=="EXACT" and
  .summary.total==12 and .summary.closed==12 and .summary.unknown==0 and .summary.refuted==0 and
  .summary.normal_paths==1 and .summary.normal_replay_runs==2 and .summary.unknown_paths==1 and .summary.refuted_paths==2 and
  .summary.case_state_totals.normal=={total:12,closed:12,unknown:0,refuted:0} and
  .summary.case_state_totals.unknown=={total:12,closed:11,unknown:1,refuted:0} and
  .summary.case_state_totals.refuted_digest_valid_laundering=={total:12,closed:6,unknown:0,refuted:6} and
  .summary.case_state_totals.refuted_over_unknown=={total:12,closed:4,unknown:2,refuted:6} and
  .semantic_effect.target_cell_transitions==$pair_closed and
  .semantic_effect.delta.closed==$pair_closed and .semantic_effect.delta.unknown==$pair_unknown and
  .semantic_effect.unrelated_cell_changes==0 and .semantic_effect.unrelated_digests_equal==true and
  .metrics.artifact_files==$files and .metrics.repository_writes==0 and .metrics.local_test_executions==0 and
  .metrics.opentofu.init_executions==0 and .metrics.opentofu.validate_executions==0 and .metrics.opentofu.plan_executions==0 and
  .metrics.go.build_executions==0 and .metrics.go.test_executions==0 and
  .metrics.producer_conformance_receipt_reuse.observed==5 and .metrics.producer_conformance_receipt_reuse.total==5 and
  .metrics.producer_conformance_receipt_reuse.state=="CLOSED" and
  .metrics.released_test_receipt_reuse.observed==0 and .metrics.released_test_receipt_reuse.total==1 and
  .metrics.released_test_receipt_reuse.state=="UNKNOWN" and
  .adoption.consumer.observed==1 and .adoption.consumer.total==1 and .adoption.consumer.state=="CLOSED" and
  .adoption.language_generalization.observed==0 and .adoption.language_generalization.total==1 and .adoption.language_generalization.state=="UNKNOWN" and
  .adoption.external_user_utility.observed==0 and .adoption.external_user_utility.total==1 and .adoption.external_user_utility.state=="UNKNOWN" and
  .adoption.exact_before_after_improvement.observed==1 and .adoption.exact_before_after_improvement.total==1 and .adoption.exact_before_after_improvement.state=="CLOSED"
' "$publish/opentofu-receipt-v1-adoption.json" >/dev/null
test -s "$publish/opentofu-receipt-v1-report.md"

subject_digest=$(cd "$publish" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
subject_files=$(find "$publish" -type f | wc -l | tr -d ' ')
jq -S -n --arg digest "$subject_digest" --argjson files "$subject_files" --argjson producer 5 \
  '{schema:"gooo/infra-evidence/opentofu-receipt-v1-transformation-conformance/v1",decision:"CONFORMANT",resolution:"EXACT",subject_files:$files,subject_digest:$digest,producer_conformance_receipts_reused:$producer,checks:{producer_release_digest_verified:true,producer_manifests_verified:true,released_graph_and_checks_bound:true,consumer_activity_cardinality_exact:true,semantic_pair_exact:true,case_state_totals_exact:true,refuted_precedence_verified:true,read_only_authority_verified:true}}' > "$output"
