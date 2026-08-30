#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: conform-opentofu-receipt-v1.sh PUBLISH_DIR DENOMINATOR OUTPUT" >&2
  exit 2
fi

publish=$1
denominator=$2
output=$3
expected_before_manifest='["opentofu-adoption-receipt.json","opentofu-release-receipt.json","opentofu-report.md","opentofu-version-first.json","opentofu-version-replay.json"]'
actual=$(find "$publish" -maxdepth 1 -type f -printf '%f\n' | sort | jq -R -s 'split("\n")|map(select(length>0))')
test "$actual" = "$expected_before_manifest"
cmp "$publish/opentofu-version-first.json" "$publish/opentofu-version-replay.json"
jq -e '.schema=="gooo/infra-evidence/opentofu-release-receipt/v1" and .receipt_state=="OBSERVED" and .iac_engine=="OPENTOFU" and .engine_inferred_from_json_key==false and .command_argv==["tofu","version","-json"]' "$publish/opentofu-release-receipt.json" >/dev/null
jq -e --argjson cells "$(jq '.target_cells' "$denominator")" --argjson expected "$(jq '.expected' "$denominator")" '
  .schema=="gooo/infra-evidence/opentofu-receipt-v1-adoption/v1" and
  .decision=="OPENTOFU_RECEIPT_V1_CLOSED" and .resolution=="EXACT" and
  .summary.total==$cells and .summary.closed==$cells and .summary.unknown==0 and .summary.refuted==0 and
  (.cells|length)==$cells and ([.cells[].id]|unique|length)==$cells and ([.cells[].activity]|unique|length)==$cells and
  all(.cells[];.state=="CLOSED" and (.evidence_digest|test("^[0-9a-f]{64}$"))) and
  (.proofs|length)==3 and all(.proofs[];.closed==.total and .total==4) and
  (.indicators|length)==3 and all(.indicators[];.closed==.total and .total==4) and
  .summary.normal_paths==$expected.normal_paths and .summary.unknown_paths==$expected.unknown_paths and .summary.refuted_paths==$expected.refuted_paths and
  .summary.unknown_claims==$expected.unknown_claims and
  .cases.normal.decision=="CLOSED" and .cases.unknown.decision=="FAIL_CLOSED" and .cases.unknown.resolution=="LOWER_RESOLUTION" and
  ([.cases.unknown.claims[]|select(.state=="UNKNOWN" and .unknown_class=="DIRECT_MISSING")]|length)==1 and
  ([.cases.unknown.claims[]|select(.state=="UNKNOWN" and .unknown_class=="DEPENDENCY_BLOCKED" and .blocked_by==["cell:RECEIPT_PUBLICATION"])]|length)==1 and
  all(.cases.unknown.claims[]; ([.stage,.step,.reason,.unknown_class,.next_operation,.blocked_by]|map(select(.!=null))|length)==$expected.unknown_coordinate_fields_per_claim) and
  (.cases.refuted|length)==$expected.refuted_paths and all(.cases.refuted[];.decision=="FAIL_CLOSED" and .resolution=="EXACT" and .claims[0].state=="REFUTED") and
  .opentofu_adoption==$expected.opentofu_adoption and .released_adoption==$expected.released_adoption and .external_utility==$expected.external_utility and .exact_before_after_improvement==$expected.exact_before_after_improvement and
  .metrics.opentofu_version_executions==2 and .metrics.opentofu_init_executions==0 and .metrics.opentofu_plan_executions==0 and .metrics.opentofu_apply_executions==0 and .metrics.opentofu_test_executions==0 and .metrics.opentofu_build_executions==0 and
  .metrics.ci_build_executions==0 and .metrics.ci_test_executions==0 and .metrics.local_test_executions==0 and .metrics.case_evaluator_executions==4 and
  .metrics.first.wall_ms>=1 and .metrics.replay.wall_ms>=1 and .metrics.first.peak_rss_kib>0 and .metrics.replay.peak_rss_kib>0 and
  .authority.repository_writes==0 and .authority.cross_project_required_gates==0 and .authority.opentofu_runtime_network_access_claimed==false and .authority.opentofu_runtime_network_access_observed==null and
  .inventory.root_readme_excluded==true and (.inventory.regular_files|type=="number") and (.inventory.descendant_directories|type=="number") and (.inventory.go.files|type=="number") and (.inventory.gooo.files|type=="number")
' "$publish/opentofu-adoption-receipt.json" >/dev/null
test -s "$publish/opentofu-report.md"
subject_digest=$(sha256sum "$publish"/opentofu-*.json "$publish/opentofu-report.md" | sha256sum | awk '{print $1}')
jq -S -n --arg subject_digest "$subject_digest" --argjson files 5 \
  '{schema:"gooo/infra-evidence/opentofu-receipt-v1-conformance/v1",decision:"CONFORMANT",resolution:"EXACT",subject_files:$files,subject_digest:$subject_digest,checks:{exact_pre_manifest_file_set:true,version_replay_equal:true,receipt_identity_explicit:true,adoption_denominator_closed:true}}' > "$output"
