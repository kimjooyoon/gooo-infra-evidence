#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "usage: evaluate-opentofu-receipt-v1.sh LOCK VERSION_JSON RELEASE_RECEIPT BINARY_ARCHIVE CASE_ID OUTPUT" >&2
  exit 2
fi

lock=$1
version_json=$2
release_receipt=$3
binary_archive=$4
case_id=$5
output=$6

digest_or_null() {
  if [ -s "$1" ]; then
    sha256sum "$1" | awk '{print $1}'
  else
    printf 'null\n'
  fi
}

emit_unknown() {
  local reason=$1
  local next_operation=$2
  jq -S -n --arg case_id "$case_id" --arg reason "$reason" --arg next "$next_operation" \
    --arg version_digest "$(digest_or_null "$version_json")" --arg binary_digest "$(digest_or_null "$binary_archive")" \
    '{schema:"gooo/infra-evidence/opentofu-receipt-v1-case/v1",case_id:$case_id,decision:"FAIL_CLOSED",resolution:"LOWER_RESOLUTION",
      claims:[
        {state:"UNKNOWN",stage:"OPENTOFU_RECEIPT",step:"READ_IMMUTABLE_INPUTS",reason:$reason,unknown_class:"DIRECT_MISSING",next_operation:$next,blocked_by:[]},
        {state:"UNKNOWN",stage:"AUTHORITY",step:"CLOSE_OPENTOFU_ADOPTION",reason:"OPENTOFU_RECEIPT_DEPENDENCY_BLOCKED",unknown_class:"DEPENDENCY_BLOCKED",next_operation:$next,blocked_by:["cell:RECEIPT_PUBLICATION"]}
      ],evidence:{version_json_digest:(if $version_digest=="null" then null else $version_digest end),binary_digest:(if $binary_digest=="null" then null else $binary_digest end)}}' > "$output"
}

emit_refuted() {
  local reason=$1
  jq -S -n --arg case_id "$case_id" --arg reason "$reason" \
    --arg version_digest "$(digest_or_null "$version_json")" --arg binary_digest "$(digest_or_null "$binary_archive")" \
    '{schema:"gooo/infra-evidence/opentofu-receipt-v1-case/v1",case_id:$case_id,decision:"FAIL_CLOSED",resolution:"EXACT",
      claims:[{state:"REFUTED",stage:"OPENTOFU_RECEIPT",step:"VERIFY_IMMUTABLE_RECEIPT",reason:$reason,unknown_class:null,next_operation:null,blocked_by:[]}],
      evidence:{version_json_digest:(if $version_digest=="null" then null else $version_digest end),binary_digest:(if $binary_digest=="null" then null else $binary_digest end)}}' > "$output"
}

if [ ! -s "$version_json" ]; then
  emit_unknown "OPENTOFU_VERSION_JSON_MISSING" "EXECUTE_OPENTOFU_VERSION_JSON"
  exit 0
fi
if [ ! -s "$release_receipt" ]; then
  emit_unknown "OPENTOFU_RELEASE_RECEIPT_MISSING" "PROVIDE_IMMUTABLE_OPENTOFU_JSON_RECEIPT"
  exit 0
fi
if [ ! -s "$binary_archive" ]; then
  emit_unknown "OPENTOFU_BINARY_ARCHIVE_MISSING" "RESTORE_PINNED_OPENTOFU_BINARY"
  exit 0
fi
if ! jq -e 'type=="object" and (.terraform_version|type=="string") and (.platform|type=="string")' "$version_json" >/dev/null 2>&1; then
  emit_refuted "MALFORMED_OPENTOFU_VERSION_JSON"
  exit 0
fi
if ! jq -e 'type=="object"' "$release_receipt" >/dev/null 2>&1; then
  emit_refuted "MALFORMED_OPENTOFU_RELEASE_RECEIPT"
  exit 0
fi

expected_version=$(jq -r '.opentofu.iac_engine_version' "$lock")
expected_platform=$(jq -r '.opentofu.platform' "$lock")
expected_release_id=$(jq -r '.opentofu.release_id' "$lock")
expected_tag=$(jq -r '.opentofu.tag' "$lock")
expected_target=$(jq -r '.opentofu.target_commit_sha' "$lock")
expected_binary=$(jq -r '.opentofu.assets.linux.sha256' "$lock")
expected_format=$(jq -r '.opentofu.machine_readable_format_version' "$lock")
actual_binary=$(sha256sum "$binary_archive" | awk '{print $1}')
actual_version_digest=$(sha256sum "$version_json" | awk '{print $1}')

if [ "$(jq -r '.schema // ""' "$release_receipt")" != "gooo/infra-evidence/opentofu-release-receipt/v1" ]; then
  emit_refuted "OPENTOFU_RECEIPT_SCHEMA_MISMATCH"
elif [ "$(jq -r '.receipt_state // ""' "$release_receipt")" != "OBSERVED" ]; then
  emit_refuted "OPENTOFU_RECEIPT_STATE_UNRECOGNIZED"
elif [ "$(jq -r '.iac_engine // ""' "$release_receipt")" = "UNKNOWN" ]; then
  emit_refuted "OPENTOFU_ENGINE_UNKNOWN"
elif [ "$(jq -r '.iac_engine // ""' "$release_receipt")" != "OPENTOFU" ]; then
  emit_refuted "OPENTOFU_ENGINE_IDENTITY_MISMATCH"
elif [ "$(jq -r '.engine_inferred_from_json_key' "$release_receipt")" != "false" ]; then
  emit_refuted "OPENTOFU_ENGINE_INFERRED_FROM_COMPATIBILITY_KEY"
elif [ "$(jq -r '.iac_engine_version // ""' "$release_receipt")" != "$expected_version" ] || [ "$(jq -r '.version_json.terraform_version' "$release_receipt")" != "$expected_version" ]; then
  emit_refuted "OPENTOFU_VERSION_MISMATCH"
elif [ "$(jq -r '.version_json.platform' "$release_receipt")" != "$expected_platform" ]; then
  emit_refuted "OPENTOFU_PLATFORM_MISMATCH"
elif [ "$(jq -r '.release.id' "$release_receipt")" != "$expected_release_id" ] || [ "$(jq -r '.release.tag' "$release_receipt")" != "$expected_tag" ] || [ "$(jq -r '.release.target_commit_sha' "$release_receipt")" != "$expected_target" ]; then
  emit_refuted "OPENTOFU_RELEASE_IDENTITY_MISMATCH"
elif [ "$(jq -r '.binary_asset_sha256' "$release_receipt")" != "$expected_binary" ] || [ "$actual_binary" != "$expected_binary" ]; then
  emit_refuted "OPENTOFU_BINARY_DIGEST_MISMATCH"
elif [ "$(jq -r '.version_json_sha256' "$release_receipt")" != "$actual_version_digest" ]; then
  emit_refuted "OPENTOFU_VERSION_JSON_DIGEST_MISMATCH"
elif [ "$(jq -r '.machine_readable_format_version' "$release_receipt")" != "$expected_format" ]; then
  emit_refuted "OPENTOFU_MACHINE_FORMAT_MISMATCH"
else
  jq -S -n --arg case_id "$case_id" --arg version_digest "$actual_version_digest" --arg binary_digest "$actual_binary" \
    '{schema:"gooo/infra-evidence/opentofu-receipt-v1-case/v1",case_id:$case_id,decision:"CLOSED",resolution:"EXACT",
      claims:[{state:"CLOSED",stage:"ADOPTION",step:"VERIFY_IMMUTABLE_OPENTOFU_RECEIPT",reason:"IMMUTABLE_OPENTOFU_RECEIPT_OBSERVED",unknown_class:null,next_operation:null,blocked_by:[]}],
      evidence:{version_json_digest:$version_digest,binary_digest:$binary_digest}}' > "$output"
fi
