#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "--apply" || "$#" -ne 1 ]]; then
  echo "Usage: $0 --apply" >&2
  echo "This creates and deletes three temporary Databricks service principals." >&2
  exit 1
fi

: "${DATABRICKS_CONFIG_PROFILE:?Set the explicit Databricks CLI profile.}"
: "${DATABRICKS_WAREHOUSE_ID:?Set the explicit SQL warehouse ID.}"
: "${DATABRICKS_ACCOUNT_ID:?Set the exact Databricks account ID.}"
: "${DATABRICKS_EXPECTED_HOST:?Set the exact expected https workspace host.}"
: "${DATABRICKS_EXPECTED_CALLER:?Set the expected validation caller email.}"
: "${DATABRICKS_IDENTITY_MODE:?Set DATABRICKS_IDENTITY_MODE.}"
: "${PRIVACY_ADMIN_EMAIL:?Set PRIVACY_ADMIN_EMAIL.}"
: "${RESTRICTED_USER_EMAIL:?Set RESTRICTED_USER_EMAIL.}"
: "${CASE_USER_EMAIL:?Set CASE_USER_EMAIL.}"
: "${PRIVACY_ADMIN_GROUP_ID:?Set the pinned privacy_admins group ID.}"
: "${RESTRICTED_USER_GROUP_ID:?Set the pinned restricted_users group ID.}"
: "${CASE_USER_GROUP_ID:?Set the pinned case_users group ID.}"

for command_name in databricks jq uuidgen; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Required command is not available: ${command_name}." >&2
    exit 1
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$DATABRICKS_CONFIG_PROFILE"
warehouse_id="$DATABRICKS_WAREHOUSE_ID"
nonce="$(uuidgen | tr '[:upper:]' '[:lower:]')"
workspace_dir="/Shared/bricksgdpr-persona-acceptance/${nonce}"
cleanup_done=false
cleanup_retry_attempts=10
cleanup_retry_delay_seconds=2
cleanup_absence_observations=2

personas=(privacy restricted case)
group_names=(privacy_admins restricted_users case_users)
expected_group_ids=(
  "$PRIVACY_ADMIN_GROUP_ID"
  "$RESTRICTED_USER_GROUP_ID"
  "$CASE_USER_GROUP_ID"
)
positive_files=(privacy_admin.sql restricted_user.sql case_user.sql)
group_ids=()
sp_ids=()
sp_apps=()
run_ids=()

urlencode_filter() {
  jq -nr --arg value "$1" '$value | @uri'
}

append_unique() {
  local candidate="$1" existing
  shift
  for existing in "$@"; do
    [[ "$existing" == "$candidate" ]] && return 1
  done
  return 0
}

is_not_found_output() {
  local output_lower
  output_lower="$(tr '[:upper:]' '[:lower:]' <<<"$1")"
  [[ "$output_lower" == *"resource_does_not_exist"* \
    || "$output_lower" == *"not_found"* \
    || "$output_lower" == *"status code 404"* \
    || "$output_lower" == *'"status":"404"'* \
    || "$output_lower" == *'"status": "404"'* \
    || ( "$output_lower" == *"service principal"* \
      && "$output_lower" == *"not found"* ) ]]
}

wait_for_service_principal_absence() {
  local sp_id="$1" display_name="$2" attempt status_output consecutive_absent=0

  for ((attempt = 1; attempt <= cleanup_retry_attempts; attempt++)); do
    if status_output="$(
      databricks api get "/api/2.0/account/scim/v2/ServicePrincipals/${sp_id}" \
        -p "$profile" --output json 2>&1
    )"; then
      consecutive_absent=0
      databricks api delete "/api/2.0/account/scim/v2/ServicePrincipals/${sp_id}" \
        -p "$profile" --output json >/dev/null 2>&1 || true
    elif is_not_found_output "$status_output"; then
      consecutive_absent=$((consecutive_absent + 1))
      if (( consecutive_absent >= cleanup_absence_observations )); then
        return 0
      fi
    else
      consecutive_absent=0
    fi
    if (( attempt < cleanup_retry_attempts )); then
      sleep "$cleanup_retry_delay_seconds"
      continue
    fi
    echo "Cleanup could not confirm stable deletion of ${display_name}." >&2
    return 1
  done
}

wait_for_service_principal_name_absence() {
  local filter="$1" display_name="$2" attempt response consecutive_absent=0

  for ((attempt = 1; attempt <= cleanup_retry_attempts; attempt++)); do
    if response="$(
      databricks api get \
        "/api/2.0/account/scim/v2/ServicePrincipals?filter=${filter}" \
        -p "$profile" --output json 2>/dev/null
    )" && jq -e '
      (.totalResults | type) == "number"
      and .totalResults == 0
      and ((.Resources // []) | type) == "array"
      and ((.Resources // []) | length) == 0
    ' >/dev/null <<<"$response"; then
      consecutive_absent=$((consecutive_absent + 1))
      if (( consecutive_absent >= cleanup_absence_observations )); then
        return 0
      fi
    else
      consecutive_absent=0
    fi

    if (( attempt < cleanup_retry_attempts )); then
      sleep "$cleanup_retry_delay_seconds"
      continue
    fi
    echo "Cleanup could not confirm stable name removal for ${display_name}." >&2
    return 1
  done
}

ensure_group_members_absent() {
  local group_id="$1" display_name="$2" attempt group_response sp_id membership_payload
  local consecutive_absent=0 present_count
  shift 2
  local -a member_ids=("$@")

  for ((attempt = 1; attempt <= cleanup_retry_attempts; attempt++)); do
    if group_response="$(
      databricks api get "/api/2.0/account/scim/v2/Groups/${group_id}" \
        -p "$profile" --output json 2>/dev/null
    )" && jq -e '
      (.id | type) == "string" and ((.members // []) | type) == "array"
    ' >/dev/null <<<"$group_response"; then
      present_count=0
      for sp_id in "${member_ids[@]}"; do
        if ! jq -e --arg sp_id "$sp_id" \
          '.members[]? | select(.value == $sp_id)' \
          >/dev/null <<<"$group_response"; then
          continue
        fi
        present_count=$((present_count + 1))
        membership_payload="$(
          jq -cn --arg path "members[value eq \"${sp_id}\"]" '{
            schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
            Operations: [{op: "remove", path: $path}]
          }'
        )"
        databricks api patch "/api/2.0/account/scim/v2/Groups/${group_id}" \
          -p "$profile" --json "$membership_payload" --output json \
          >/dev/null 2>&1 || true
      done
      if (( present_count > 0 )); then
        consecutive_absent=0
      else
        consecutive_absent=$((consecutive_absent + 1))
        if (( consecutive_absent >= cleanup_absence_observations )); then
          return 0
        fi
      fi
    else
      consecutive_absent=0
    fi

    if (( attempt < cleanup_retry_attempts )); then
      sleep "$cleanup_retry_delay_seconds"
      continue
    fi
    echo "Cleanup could not confirm group-member removal for ${display_name}." >&2
    return 1
  done
}

wait_for_workspace_absence() {
  local attempt status_output output_lower consecutive_absent=0

  for ((attempt = 1; attempt <= cleanup_retry_attempts; attempt++)); do
    if status_output="$(
      databricks workspace get-status "$workspace_dir" \
        -p "$profile" --output json 2>&1
    )"; then
      consecutive_absent=0
      databricks workspace delete "$workspace_dir" --recursive -p "$profile" \
        >/dev/null 2>&1 || true
    else
      output_lower="$(tr '[:upper:]' '[:lower:]' <<<"$status_output")"
      if [[ "$output_lower" == *"resource_does_not_exist"* \
        || "$output_lower" == *"doesn't exist"* \
        || "$output_lower" == *"does not exist"* ]]; then
        consecutive_absent=$((consecutive_absent + 1))
        if (( consecutive_absent >= cleanup_absence_observations )); then
          return 0
        fi
      else
        consecutive_absent=0
      fi
    fi

    if (( attempt < cleanup_retry_attempts )); then
      sleep "$cleanup_retry_delay_seconds"
      continue
    fi
    echo "Cleanup could not confirm stable workspace-file removal." >&2
    return 1
  done
}

cleanup_resources() {
  local failed=0 runs_response discovered_run_ids_text run_id run_json pending_count life_cycle_state
  local index persona display_name filter response sp_id group_id patch_payload existing
  local -a cleanup_run_ids=() discovered_sp_ids=() persona_sp_ids=()

  [[ "$cleanup_done" == "true" ]] && return 0

  if (( ${#run_ids[@]} > 0 )); then
    for run_id in "${run_ids[@]}"; do
      [[ -n "$run_id" ]] && cleanup_run_ids+=("$run_id")
    done
  fi
  if runs_response="$(
    databricks jobs list-runs --run-type SUBMIT_RUN --limit 100 \
      -p "$profile" --output json
  )"; then
    if discovered_run_ids_text="$(
      jq -r --arg nonce "$nonce" '
        (if type == "array" then . else (.runs // []) end)[]?
        | select((.run_name // "") | endswith($nonce))
        | .run_id
      ' <<<"$runs_response"
    )"; then
      while IFS= read -r run_id; do
        [[ -z "$run_id" ]] && continue
        if (( ${#cleanup_run_ids[@]} == 0 )) \
          || append_unique "$run_id" "${cleanup_run_ids[@]}"; then
          cleanup_run_ids+=("$run_id")
        fi
      done <<<"$discovered_run_ids_text"
    else
      echo "Cleanup could not parse discovered one-time persona runs." >&2
      failed=1
    fi
  else
    echo "Cleanup could not discover one-time persona runs." >&2
    failed=1
  fi

  if (( ${#cleanup_run_ids[@]} > 0 )); then
    for run_id in "${cleanup_run_ids[@]}"; do
      if ! run_json="$(databricks jobs get-run "$run_id" -p "$profile" --output json)"; then
        echo "Cleanup could not inspect run ${run_id}." >&2
        failed=1
        continue
      fi
      life_cycle_state="$(jq -r '.state.life_cycle_state // empty' <<<"$run_json")"
      pending_count="$(
        jq -r '[
          .tasks[]?
          | select(
              .state.life_cycle_state != "TERMINATED"
              and .state.life_cycle_state != "INTERNAL_ERROR"
              and .state.life_cycle_state != "SKIPPED"
            )
        ] | length' <<<"$run_json"
      )"
      if (( pending_count > 0 )) \
        || [[ "$life_cycle_state" != "TERMINATED" \
          && "$life_cycle_state" != "INTERNAL_ERROR" \
          && "$life_cycle_state" != "SKIPPED" ]]; then
        if ! databricks jobs cancel-run "$run_id" --timeout 2m \
          -p "$profile" --output json >/dev/null; then
          echo "Cleanup could not cancel run ${run_id}." >&2
          failed=1
        fi
      fi
      if run_json="$(databricks jobs get-run "$run_id" -p "$profile" --output json)"; then
        pending_count="$(
          jq -r '[
            .tasks[]?
            | select(
                .state.life_cycle_state != "TERMINATED"
                and .state.life_cycle_state != "INTERNAL_ERROR"
                and .state.life_cycle_state != "SKIPPED"
              )
          ] | length' <<<"$run_json"
        )"
        if (( pending_count > 0 )); then
          echo "Cleanup found tasks still active in run ${run_id}." >&2
          failed=1
        fi
      else
        echo "Cleanup could not verify terminal tasks for run ${run_id}." >&2
        failed=1
      fi
    done
  fi

  patch_payload='{
    "schemas":["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
    "Operations":[{"op":"replace","path":"active","value":false}]
  }'
  for index in 0 1 2; do
    persona="${personas[$index]}"
    display_name="bricksgdpr-persona-acceptance-${persona}-${nonce}"
    filter="$(urlencode_filter "displayName eq \"${display_name}\"")"
    persona_sp_ids=()
    if (( ${#sp_ids[@]} > index )) && [[ -n "${sp_ids[$index]}" ]]; then
      persona_sp_ids+=("${sp_ids[$index]}")
    fi
    if response="$(
      databricks api get \
        "/api/2.0/account/scim/v2/ServicePrincipals?filter=${filter}" \
        -p "$profile" --output json
    )"; then
      while IFS= read -r sp_id; do
        [[ -z "$sp_id" ]] && continue
        if (( ${#persona_sp_ids[@]} == 0 )) \
          || append_unique "$sp_id" "${persona_sp_ids[@]}"; then
          persona_sp_ids+=("$sp_id")
        fi
      done < <(jq -r '.Resources[]?.id' <<<"$response")
    else
      echo "Cleanup could not discover temporary principal ${display_name}." >&2
      failed=1
    fi
    if (( ${#persona_sp_ids[@]} > 0 )); then
      for sp_id in "${persona_sp_ids[@]}"; do
        if (( ${#discovered_sp_ids[@]} == 0 )) \
          || append_unique "$sp_id" "${discovered_sp_ids[@]}"; then
          discovered_sp_ids+=("$sp_id")
        fi
        group_id="${group_ids[$index]:-}"
        if [[ -n "$group_id" ]]; then
          if ! ensure_group_members_absent "$group_id" "$display_name" "$sp_id"; then
            failed=1
          fi
        fi
        databricks api patch "/api/2.0/account/scim/v2/ServicePrincipals/${sp_id}" \
          -p "$profile" --json "$patch_payload" --output json >/dev/null 2>&1 || true
        databricks api delete "/api/2.0/account/scim/v2/ServicePrincipals/${sp_id}" \
          -p "$profile" --output json >/dev/null 2>&1 || true
        if ! wait_for_service_principal_absence "$sp_id" "$display_name"; then
          failed=1
        fi
      done
    fi

    if ! wait_for_service_principal_name_absence "$filter" "$display_name"; then
      failed=1
    fi
  done

  if ! wait_for_workspace_absence; then
    failed=1
  fi

  for index in 0 1 2; do
    group_id="${group_ids[$index]:-}"
    [[ -z "$group_id" ]] && continue
    if (( ${#discovered_sp_ids[@]} > 0 )); then
      if ! ensure_group_members_absent \
        "$group_id" "temporary persona principals" "${discovered_sp_ids[@]}"; then
        failed=1
      fi
    fi
  done

  if (( failed != 0 )); then
    return 1
  fi
  cleanup_done=true
  return 0
}

on_exit() {
  local original_status="$1"
  trap - EXIT
  trap '' INT TERM HUP
  if [[ "$cleanup_done" != "true" ]] && ! cleanup_resources; then
    echo "Persona acceptance cleanup failed; inspect the named resources immediately." >&2
    exit 90
  fi
  exit "$original_status"
}

on_signal() {
  local signal_status="$1"
  trap - INT TERM HUP
  exit "$signal_status"
}
trap 'on_exit $?' EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM
trap 'on_signal 129' HUP

lookup_group_id() {
  local group_name="$1" expected_group_id="$2" filter response actual_group_id
  filter="$(urlencode_filter "displayName eq \"${group_name}\"")"
  response="$(
    databricks api get "/api/2.0/account/scim/v2/Groups?filter=${filter}" \
      -p "$profile" --output json
  )"
  if [[ "$(jq -r '.totalResults // 0' <<<"$response")" != "1" ]]; then
    echo "Expected exactly one account group named ${group_name}." >&2
    exit 1
  fi
  actual_group_id="$(jq -r '.Resources[0].id' <<<"$response")"
  if [[ "$actual_group_id" != "$expected_group_id" ]]; then
    echo "Pinned group ID mismatch for ${group_name}." >&2
    exit 1
  fi
  printf '%s' "$actual_group_id"
}

grant_run_as_role() {
  local application_id="$1" rule_name encoded_name rule_set grant_rules payload
  rule_name="accounts/${DATABRICKS_ACCOUNT_ID}/servicePrincipals/${application_id}/ruleSets/default"
  encoded_name="$(urlencode_filter "$rule_name")"
  rule_set="$(
    databricks api get \
      "/api/2.0/preview/accounts/access-control/rule-sets?name=${encoded_name}&etag=" \
      -p "$profile" --output json
  )"
  grant_rules="$(
    jq --arg principal "users/${DATABRICKS_EXPECTED_CALLER}" '
      (.grant_rules // []) as $rules
      | if any(
          $rules[]?;
          .role == "roles/servicePrincipal.user"
          and (.principals // [] | index($principal)) != null
        )
        then $rules
        else $rules + [{
          role: "roles/servicePrincipal.user",
          principals: [$principal]
        }]
        end
    ' <<<"$rule_set"
  )"
  payload="$(
    jq -cn \
      --arg name "$rule_name" \
      --arg etag "$(jq -r '.etag' <<<"$rule_set")" \
      --argjson grant_rules "$grant_rules" \
      '{
        name: $name,
        rule_set: {
          name: $name,
          etag: $etag,
          grant_rules: $grant_rules
        }
      }'
  )"
  databricks api put /api/2.0/preview/accounts/access-control/rule-sets \
    -p "$profile" --json "$payload" --output json >/dev/null
}

create_validation_principal() {
  local persona="$1" group_id="$2" response sp_id application_id membership_payload
  response="$(
    databricks api post /api/2.0/account/scim/v2/ServicePrincipals \
      -p "$profile" --output json \
      --json "$(
        jq -cn --arg display_name "bricksgdpr-persona-acceptance-${persona}-${nonce}" \
          '{displayName: $display_name, active: true}'
      )"
  )"
  sp_id="$(jq -r '.id' <<<"$response")"
  application_id="$(jq -r '.applicationId' <<<"$response")"
  sp_ids+=("$sp_id")
  sp_apps+=("$application_id")

  databricks api put "/api/2.0/preview/permissionassignments/principals/${sp_id}" \
    -p "$profile" --json '{"permissions":["USER"]}' --output json >/dev/null
  membership_payload="$(
    jq -cn --arg member_id "$sp_id" '{
      schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
      Operations: [{
        op: "add",
        path: "members",
        value: [{value: $member_id}]
      }]
    }'
  )"
  databricks api patch "/api/2.0/account/scim/v2/Groups/${group_id}" \
    -p "$profile" --json "$membership_payload" --output json >/dev/null
  grant_run_as_role "$application_id"
}

negative_specs_for() {
  case "$1" in
    privacy)
      printf '%s\n' 'deny_udf:deny_udf.sql'
      ;;
    restricted)
      printf '%s\n' \
        'deny_layer1:deny_layer1.sql' \
        'deny_quarantine:deny_quarantine.sql' \
        'deny_layer3_case:deny_layer3_case.sql' \
        'deny_udf:deny_udf.sql'
      ;;
    case)
      printf '%s\n' \
        'deny_layer1:deny_layer1.sql' \
        'deny_quarantine:deny_quarantine.sql' \
        'deny_layer2:deny_layer2.sql' \
        'deny_priva_map:deny_priva_map.sql' \
        'deny_udf:deny_udf.sql'
      ;;
  esac
}

submit_persona_run() {
  local persona="$1" application_id="$2" positive_file="$3"
  local task_key file_name spec tasks payload response idempotency_token
  tasks="$(
    jq -cn \
      --arg path "${workspace_dir}/${positive_file}" \
      --arg warehouse_id "$warehouse_id" \
      --arg expected_user "$application_id" \
      '[{
        task_key: "allowed",
        timeout_seconds: 300,
        sql_task: {
          file: {path: $path, source: "WORKSPACE"},
          warehouse_id: $warehouse_id,
          parameters: {expected_user: $expected_user}
        }
      }]'
  )"
  while IFS= read -r spec; do
    [[ -z "$spec" ]] && continue
    task_key="${spec%%:*}"
    file_name="${spec#*:}"
    tasks="$(
      jq \
        --arg task_key "$task_key" \
        --arg path "${workspace_dir}/${file_name}" \
        --arg warehouse_id "$warehouse_id" \
        '. + [{
          task_key: $task_key,
          timeout_seconds: 300,
          sql_task: {
            file: {path: $path, source: "WORKSPACE"},
            warehouse_id: $warehouse_id
          }
        }]' <<<"$tasks"
    )"
  done < <(negative_specs_for "$persona")

  payload="$(
    jq -cn \
      --arg run_name "bricksgdpr-persona-${persona}-${nonce}" \
      --arg application_id "$application_id" \
      --argjson tasks "$tasks" \
      '{
        run_name: $run_name,
        timeout_seconds: 600,
        run_as: {service_principal_name: $application_id},
        tasks: $tasks
      }'
  )"
  idempotency_token="bricksgdpr-${persona}-${nonce}"
  if ! response="$(
    databricks jobs submit --no-wait --idempotency-token "$idempotency_token" \
      -p "$profile" --output json --json "$payload"
  )"; then
    response="$(
      databricks jobs submit --no-wait --idempotency-token "$idempotency_token" \
        -p "$profile" --output json --json "$payload"
    )"
  fi
  jq -r '.run_id' <<<"$response"
}

wait_for_tasks() {
  local run_id="$1" deadline run_json task_count pending_count
  deadline=$((SECONDS + 600))
  while (( SECONDS < deadline )); do
    run_json="$(databricks jobs get-run "$run_id" -p "$profile" --output json)"
    task_count="$(jq -r '.tasks | length' <<<"$run_json")"
    pending_count="$(
      jq -r '[
        .tasks[]?
        | select(
            .state.life_cycle_state != "TERMINATED"
            and .state.life_cycle_state != "INTERNAL_ERROR"
            and .state.life_cycle_state != "SKIPPED"
          )
      ] | length' <<<"$run_json"
    )"
    if (( task_count > 0 && pending_count == 0 )); then
      printf '%s' "$run_json"
      return
    fi
    sleep 2
  done
  echo "Timed out waiting for persona run ${run_id}." >&2
  exit 1
}

validate_persona_run() {
  local persona="$1" application_id="$2" run_id="$3" run_json
  local expected_task_count actual_task_count creator allowed_status spec task_key
  local negative_status task_run_id output error_text
  run_json="$(wait_for_tasks "$run_id")"
  creator="$(jq -r '.creator_user_name // empty' <<<"$run_json")"
  if [[ "$creator" != "$application_id" ]]; then
    echo "Run-as identity mismatch for ${persona}." >&2
    exit 1
  fi

  expected_task_count=1
  while IFS= read -r spec; do
    [[ -n "$spec" ]] && ((expected_task_count += 1))
  done < <(negative_specs_for "$persona")
  actual_task_count="$(jq -r '.tasks | length' <<<"$run_json")"
  if (( actual_task_count != expected_task_count )); then
    echo "Unexpected task count for ${persona}." >&2
    exit 1
  fi

  allowed_status="$(
    jq -r '.tasks[] | select(.task_key == "allowed") | .state.result_state' \
      <<<"$run_json"
  )"
  if [[ "$allowed_status" != "SUCCESS" ]]; then
    echo "Positive persona task failed for ${persona}." >&2
    exit 1
  fi

  while IFS= read -r spec; do
    [[ -z "$spec" ]] && continue
    task_key="${spec%%:*}"
    negative_status="$(
      jq -r --arg task_key "$task_key" '
        .tasks[] | select(.task_key == $task_key) | .state.result_state
      ' <<<"$run_json"
    )"
    task_run_id="$(
      jq -r --arg task_key "$task_key" '
        .tasks[] | select(.task_key == $task_key) | .run_id
      ' <<<"$run_json"
    )"
    if [[ "$negative_status" != "FAILED" || -z "$task_run_id" ]]; then
      echo "Expected-denial task did not fail for ${persona}/${task_key}." >&2
      exit 1
    fi
    output="$(
      databricks jobs get-run-output "$task_run_id" \
        -p "$profile" --output json
    )"
    error_text="$(jq -r '.error // empty' <<<"$output")"
    if [[ "$error_text" != *"INSUFFICIENT_PERMISSIONS"* \
      || "$error_text" != *"SQLSTATE: 42501"* ]]; then
      echo "Expected authorization error was not observed for ${persona}/${task_key}." >&2
      exit 1
    fi
  done < <(negative_specs_for "$persona")

  echo "PASS ${persona}: positive task succeeded and every denial returned SQLSTATE 42501."
}

"${repo_root}/scripts/provision_identities.sh" --preflight-only

auth_description="$(databricks auth describe -p "$profile" --output json)"
actual_account_id="$(
  jq -r '.details.configuration.account_id.value // .account_id // empty' \
    <<<"$auth_description"
)"
if [[ "$actual_account_id" != "$DATABRICKS_ACCOUNT_ID" ]]; then
  echo "Profile account ID does not match DATABRICKS_ACCOUNT_ID." >&2
  exit 1
fi

for index in 0 1 2; do
  group_ids+=("$(lookup_group_id "${group_names[$index]}" "${expected_group_ids[$index]}")")
done

databricks workspace mkdirs "$workspace_dir" -p "$profile"
for sql_file in "${repo_root}"/acceptance/personas/*.sql; do
  databricks workspace import "${workspace_dir}/$(basename "$sql_file")" \
    --file "$sql_file" --format RAW --overwrite -p "$profile"
done
directory_id="$(
  databricks workspace get-status "$workspace_dir" \
    -p "$profile" --output json | jq -r '.object_id'
)"
databricks workspace update-permissions directories "$directory_id" \
  -p "$profile" --output json --json '{
    "access_control_list": [
      {"group_name": "privacy_admins", "permission_level": "CAN_READ"},
      {"group_name": "restricted_users", "permission_level": "CAN_READ"},
      {"group_name": "case_users", "permission_level": "CAN_READ"}
    ]
  }' >/dev/null

for index in 0 1 2; do
  create_validation_principal "${personas[$index]}" "${group_ids[$index]}"
done

for index in 0 1 2; do
  run_ids+=("$(
    submit_persona_run \
      "${personas[$index]}" "${sp_apps[$index]}" "${positive_files[$index]}"
  )")
done

for index in 0 1 2; do
  validate_persona_run "${personas[$index]}" "${sp_apps[$index]}" "${run_ids[$index]}"
done

trap '' INT TERM HUP
if ! cleanup_resources; then
  echo "Persona acceptance cleanup failed." >&2
  exit 90
fi
"${repo_root}/scripts/provision_identities.sh" --preflight-only >/dev/null
echo "Persona acceptance passed and all temporary principals and workspace files were removed."
