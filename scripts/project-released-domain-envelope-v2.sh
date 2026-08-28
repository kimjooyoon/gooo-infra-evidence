#!/usr/bin/env bash
set -euo pipefail

if test "$#" -ne 7; then
  echo "usage: project-released-domain-envelope-v2.sh ROOT CORE_RECEIPTS INFRA_PLAN INFRA_REPLAY LOCK DENOM OUTPUT" >&2
  exit 64
fi

root=$1
core_receipts=$2
infra_plan=$3
infra_replay=$4
lock=$5
denom=$6
output=$7

for required in "$root" "$core_receipts" "$infra_plan" "$infra_replay" "$lock" "$denom"; do
  test -e "$required" || { echo "required input unavailable: $required" >&2; exit 66; }
done

case "$root" in
  /*) ;;
  *) echo "repository root must be absolute" >&2; exit 66 ;;
esac
test -d "$root" || { echo "repository root is not a directory" >&2; exit 66; }
test -d "$output" || { echo "output must be a caller-owned directory" >&2; exit 66; }

root_real=$(realpath "$root")
output_real=$(realpath "$output")
case "$output_real" in
  "$root_real"|"$root_real"/*)
    echo "output must not be the repository root or a descendant" >&2
    exit 66
    ;;
esac
if test -n "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit)"; then
  echo "output must be an empty caller-owned directory" >&2
  exit 66
fi

expected_relations=$(jq -r '.expected.relations' "$denom")
expected_files=$(jq -r '.expected.envelope_files' "$denom")
expected_checks=$(jq -r '.expected.local_checks' "$denom")
plan_sha=$(sha256sum "$infra_plan" | awk '{print $1}')
replay_sha=$(sha256sum "$infra_replay" | awk '{print $1}')
locked_plan_sha=$(jq -r '.infra.assets.plan.sha256' "$lock")
locked_replay_sha=$(jq -r '.infra.assets.replay.sha256' "$lock")
test "$plan_sha" = "$locked_plan_sha" || { echo "infra plan digest mismatch" >&2; exit 66; }
test "$replay_sha" = "$locked_replay_sha" || { echo "infra replay digest mismatch" >&2; exit 66; }

jq -e --argjson expected "$expected_relations" '
  .schema=="gooo/infra-evidence/semantic-deployment-plan/v1" and
  .decision=="DEPLOYMENT_PLAN_GENERATED" and
  .summary.dependencies==$expected and
  (.dependencies|length)==$expected and
  .prior_contract.summary.openapi_bindings==1 and
  .prior_contract.summary.terraform_bindings==1 and
  .prior_contract.summary.deployment_chain_cells==4
' "$infra_plan" >/dev/null
jq -e '.schema=="gooo/infra-evidence/semantic-deployment-plan-replay/v1" and .comparisons_satisfied==.comparisons_total and .comparisons_total>0 and .mismatches==0' "$infra_replay" >/dev/null
jq -e --argjson expected "$expected_checks" 'type=="array" and length==12 and all(.[]; .schema=="gooo/activity-cardinality-resolution/v1")' "$core_receipts" >/dev/null

mkdir -p "$output"
: > "$output/evidence.ndjson"
: > "$output/relations.ndjson"
: > "$output/resolutions.ndjson"
: > "$output/unknowns.ndjson"

index=0
while IFS= read -r dependency; do
  relation_id=$(jq -r '.id' <<<"$dependency")
  kind=$(jq -r '.kind' <<<"$dependency")
  label=$(jq -r '.label' <<<"$dependency")
  from_activity=$(jq -r '.from_activity' <<<"$dependency")
  to_activity=$(jq -r '.to_activity' <<<"$dependency")
  via_entity=$(jq -r '.via_entity' <<<"$dependency")
  value_sha=$(jq -cS --argjson index "$index" '.dependencies[$index]' "$infra_plan" | sha256sum | awk '{print $1}')
  evidence_id="evidence:infra:v0.8.0-dev:$index"
  json_pointer="/dependencies/$index"

  jq -cS -n \
    --arg id "$evidence_id" --arg relation_id "$relation_id" \
    --arg repository "$(jq -r '.infra.repository' "$lock")" \
    --arg tag "$(jq -r '.infra.tag' "$lock")" \
    --arg target "$(jq -r '.infra.target_commit_sha' "$lock")" \
    --arg asset_name "$(jq -r '.infra.assets.plan.name' "$lock")" \
    --arg asset_sha "$(jq -r '.infra.assets.plan.sha256' "$lock")" \
    --arg member "$(jq -r '.infra.assets.plan.name' "$lock")" \
    --arg pointer "$json_pointer" --arg value_sha "$value_sha" \
    '{schema:"gooo/interchange/evidence/v2",id:$id,relation_id:$relation_id,
      source:{repository:$repository,tag:$tag,target_commit_sha:$target,asset_name:$asset_name,asset_sha256:$asset_sha,member:$member,json_pointer:$pointer},
      observation:{kind:"RELEASED_JSON_VALUE",value_sha256:$value_sha},
      authority:{claim_scope:"RELEASED_DECLARATION_ONLY",semantic_truth_claimed:false}}' >> "$output/evidence.ndjson"

  jq -cS -n \
    --arg id "$relation_id" --arg kind "$kind" --arg label "$label" \
    --arg from "$from_activity" --arg to "$to_activity" --arg via "$via_entity" \
    --arg evidence_id "$evidence_id" --argjson ordinal "$((index + 1))" \
    '{schema:"gooo/interchange/relation/v2",id:$id,kind:$kind,domain_state:"OBSERVED",disposition:"RELEASED",
      left:{kind:"GOOO_ACTIVITY",id:$from},right:{kind:"GOOO_ACTIVITY",id:$to},evidence_ids:[$evidence_id],
      attributes:{ordinal:$ordinal,label:$label,via_entity:$via,source:"INFRA_SEMANTIC_DEPLOYMENT_PLAN"},
      authority:{domain_semantics_preserved:true,claim_resolution_embedded:false}}' >> "$output/relations.ndjson"

  jq -cS -n --arg relation_id "$relation_id" \
    '{schema:"gooo/interchange/resolution/v2",relation_id:$relation_id,state:"CLOSED",stage:null,step:null,
      reason:"RELEASED_INFRA_RELATION_OBSERVED",unknown_class:null,next_operation:"NONE",blocked_by:[],
      authority:{source:"RELEASED_PRODUCT_EVIDENCE",state_inference_authorized:false}}' >> "$output/resolutions.ndjson"
  index=$((index + 1))
done < <(jq -c '.dependencies[]' "$infra_plan")

test "$index" = "$expected_relations" || { echo "dependency cardinality mismatch" >&2; exit 66; }

jq -S -n \
  --arg project_id "$(jq -r '.deployment.id' "$infra_plan")" \
  --argjson prior_contract "$(jq '.prior_contract' "$infra_plan")" \
  --arg repository "$(jq -r '.infra.repository' "$lock")" \
  --arg tag "$(jq -r '.infra.tag' "$lock")" \
  --arg target "$(jq -r '.infra.target_commit_sha' "$lock")" \
  --arg asset_name "$(jq -r '.infra.assets.plan.name' "$lock")" \
  --arg asset_sha "$(jq -r '.infra.assets.plan.sha256' "$lock")" \
  --arg schema "$(jq -r '.schema' "$infra_plan")" \
  --argjson relations "$index" \
  '{schema:"gooo/interchange/project/v2",project_id:$project_id,domain:"infra-evidence",
    release:{repository:$repository,tag:$tag,target_commit_sha:$target},
    source:{asset_name:$asset_name,asset_sha256:$asset_sha,member:$asset_name,schema:$schema},
    prior_contract:$prior_contract,
    relation_count:$relations,evidence_count:$relations,resolution_count:$relations,unknown_count:0,
    authority:{projection_owner:"INTERCHANGE_SPECIFICATION",domain_release_adoption_claimed:false,source_repository_writes:0,product_generation_authorized:false}}' > "$output/project.json"

check_ids=$(jq -c '.expected.local_check_ids' "$denom")
jq -S -n --argjson checks "$check_ids" \
  '{schema:"gooo/interchange/conformance/v2",required_files:8,required_local_checks:$checks,external_required_gates:0,repository_writes:0,product_generation_authorized:false}' > "$output/conformance.json"

payload_sha=$(cd "$output" && sha256sum project.json evidence.ndjson relations.ndjson resolutions.ndjson unknowns.ndjson conformance.json | sha256sum | awk '{print $1}')
jq -S -n \
  --arg receipt_schema "$(jq -r '.schema' "$infra_replay")" \
  --argjson comparisons_satisfied "$(jq '.comparisons_satisfied' "$infra_replay")" \
  --argjson comparisons_total "$(jq '.comparisons_total' "$infra_replay")" \
  --arg payload_sha "$payload_sha" \
  '{schema:"gooo/interchange/replay/v2",
    source:{receipt_schema:$receipt_schema,comparisons_satisfied:$comparisons_satisfied,comparisons_total:$comparisons_total,receipt_verified:true},
    projection:{payload_files:6,payload_sha256:$payload_sha},
    authority:{determinism_is_semantic_truth:false,product_execution_authorized:false}}' > "$output/replay.json"

(cd "$output" && sha256sum project.json evidence.ndjson relations.ndjson resolutions.ndjson unknowns.ndjson conformance.json > checksums.txt)

test "$(find "$output" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')" = "$expected_files" || { echo "envelope file cardinality mismatch" >&2; exit 66; }
