#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 5; then
  echo "usage: export-interchange.sh ROOT SUBJECT_SHA SPECIFICATION_REPORT PROFILE OUTPUT" >&2
  exit 64
fi
root=$(cd "$1" && pwd)
subject_sha=$2
spec_report=$3
profile=$4
output=$5
lock="$root/contracts/interchange-adoption-release-lock-v1.json"

test -f "$lock" && test -f "$spec_report" && test -f "$profile"
test "${#subject_sha}" -eq 40 && case "$subject_sha" in *[!0-9a-f]*) exit 65;; esac
jq -e '
  .schema=="gooo/infra-evidence/interchange-adoption-profile/v1" and .domain=="infra-evidence" and
  (.project.id|type)=="string" and (.project.repository|type)=="string" and (.project.release_tag|type)=="string" and
  (.project.source_path|type)=="string" and .relation.state=="MATCH" and
  (.relation.left.kind|type)=="string" and (.relation.left.id|type)=="string" and
  (.relation.right.kind|type)=="string" and (.relation.right.id|type)=="string"
' "$profile" >/dev/null
source_path=$(jq -r '.project.source_path' "$profile")
case "$source_path" in /*|../*|*/../*) echo "source path escapes repository" >&2; exit 65;; esac
test -d "$root/$source_path"
spec_digest=$(sha256sum "$spec_report" | awk '{print $1}')
test "$spec_digest" = "$(jq -r '.interchange.report_asset.sha256' "$lock")"
source_digest=$(find "$root/$source_path" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
mkdir -p "$output"
test -z "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"

jq -S -n --slurpfile profile "$profile" --arg subject_sha "$subject_sha" --arg source_digest "$source_digest" '
  $profile[0] as $p |
  {schema:"gooo/interchange/project/v1",project_id:$p.project.id,domain:$p.domain,fixture_id:$p.fixture_id,
   release:{repository:$p.project.repository,tag:$p.project.release_tag,target_commit_sha:$subject_sha,source_asset_sha256:$source_digest},
   relation_count:1,unknown_count:0}' > "$output/project.json"

jq -S -c -n --slurpfile profile "$profile" --arg spec_digest "$spec_digest" '
  $profile[0].relation as $r |
  {schema:"gooo/interchange/relation/v1",id:$r.id,kind:$r.kind,state:$r.state,left:$r.left,right:$r.right,
   evidence:{expected_sha256:$spec_digest,observed_sha256:$spec_digest},stage:$r.stage,step:$r.step,reason:$r.reason,
   unknown_class:$r.unknown_class,next_operation:$r.next_operation}' > "$output/relations.ndjson"
: > "$output/unknowns.ndjson"
jq -S -n --arg fixture_id "$(jq -r '.fixture_id' "$profile")" '
  {schema:"gooo/interchange/conformance/v1",fixture_id:$fixture_id,required_files:5,
   required_local_checks:["EXACT_FILE_SET","PROJECT_IDENTITY","RELATION_ANCHORS","UNKNOWN_TUPLE","SHA256_CHECKSUMS","DETERMINISTIC_REPLAY"],external_required_gates:0}' > "$output/conformance.json"
(cd "$output" && sha256sum project.json relations.ndjson unknowns.ndjson conformance.json > checksums.txt)
