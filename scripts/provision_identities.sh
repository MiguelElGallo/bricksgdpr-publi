#!/usr/bin/env bash
set -euo pipefail

mode="${1:---preflight-only}"
if [[ "$mode" != "--apply" && "$mode" != "--preflight-only" ]]; then
  echo "Usage: $0 [--preflight-only|--apply]" >&2
  exit 1
fi

: "${DATABRICKS_CONFIG_PROFILE:?Set the explicit Databricks CLI profile.}"
: "${DATABRICKS_WAREHOUSE_ID:?Set the explicit SQL warehouse ID.}"
: "${DATABRICKS_EXPECTED_HOST:?Set the exact expected https workspace host.}"
: "${DATABRICKS_EXPECTED_CALLER:?Set the expected provisioning caller email.}"
: "${DATABRICKS_IDENTITY_MODE:?Set DATABRICKS_IDENTITY_MODE to synthetic or human.}"
: "${PRIVACY_ADMIN_EMAIL:?Set PRIVACY_ADMIN_EMAIL to a valid email identity.}"
: "${RESTRICTED_USER_EMAIL:?Set RESTRICTED_USER_EMAIL to a valid email identity.}"
: "${CASE_USER_EMAIL:?Set CASE_USER_EMAIL to a valid email identity.}"

profile="$DATABRICKS_CONFIG_PROFILE"
warehouse_id="$DATABRICKS_WAREHOUSE_ID"
identity_mode="$DATABRICKS_IDENTITY_MODE"
expected_privacy_group_id="${PRIVACY_ADMIN_GROUP_ID:-}"
expected_restricted_group_id="${RESTRICTED_USER_GROUP_ID:-}"
expected_case_group_id="${CASE_USER_GROUP_ID:-}"

if [[ "$identity_mode" != "synthetic" && "$identity_mode" != "human" ]]; then
  echo "DATABRICKS_IDENTITY_MODE must be synthetic or human." >&2
  exit 1
fi

normalize_email() {
  tr '[:upper:]' '[:lower:]' <<<"$1"
}

synthetic_display_name() {
  local persona="$1"
  printf 'bricksgdpr synthetic %s %s' \
    "${DATABRICKS_EXPECTED_HOST#https://}" "$persona"
}

for email in "$PRIVACY_ADMIN_EMAIL" "$RESTRICTED_USER_EMAIL" "$CASE_USER_EMAIL"; do
  if [[ ! "$email" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    echo "Invalid email identity: $email" >&2
    exit 1
  fi
done

privacy_email_normalized="$(normalize_email "$PRIVACY_ADMIN_EMAIL")"
restricted_email_normalized="$(normalize_email "$RESTRICTED_USER_EMAIL")"
case_email_normalized="$(normalize_email "$CASE_USER_EMAIL")"
if [[ "$privacy_email_normalized" == "$restricted_email_normalized" \
  || "$privacy_email_normalized" == "$case_email_normalized" \
  || "$restricted_email_normalized" == "$case_email_normalized" ]]; then
  echo "The three user identities must be distinct." >&2
  exit 1
fi

if [[ "$identity_mode" == "synthetic" ]]; then
  if [[ "$privacy_email_normalized" != "bricksgdpr.privacy.admin@example.invalid" \
    || "$restricted_email_normalized" != "bricksgdpr.restricted.user@example.invalid" \
    || "$case_email_normalized" != "bricksgdpr.case.user@example.invalid" ]]; then
    echo "Synthetic mode requires the repository-owned example.invalid identities." >&2
    exit 1
  fi
else
  for email in \
    "$privacy_email_normalized" "$restricted_email_normalized" "$case_email_normalized"; do
    if [[ "$email" == *@example.invalid ]]; then
      echo "Human mode rejects reserved example.invalid identities." >&2
      exit 1
    fi
  done
fi

preflight_target() {
  local auth warehouse actual_host actual_caller actual_warehouse
  auth="$(databricks auth describe -p "$profile" --output json)"
  if [[ "$(jq -r '.status' <<<"$auth")" != "success" ]]; then
    echo "Databricks authentication is not valid for profile ${profile}." >&2
    exit 1
  fi
  actual_host="$(jq -r '.details.configuration.host.value // empty' <<<"$auth")"
  actual_caller="$(jq -r '.username // empty' <<<"$auth")"
  if [[ "$actual_host" != "$DATABRICKS_EXPECTED_HOST" ]]; then
    echo "Profile host does not match DATABRICKS_EXPECTED_HOST." >&2
    exit 1
  fi
  if [[ "$(normalize_email "$actual_caller")" != "$(normalize_email "$DATABRICKS_EXPECTED_CALLER")" ]]; then
    echo "Authenticated caller does not match DATABRICKS_EXPECTED_CALLER." >&2
    exit 1
  fi
  warehouse="$(databricks warehouses get "$warehouse_id" -p "$profile" --output json)"
  actual_warehouse="$(jq -r '.id // empty' <<<"$warehouse")"
  if [[ "$actual_warehouse" != "$warehouse_id" ]]; then
    echo "SQL warehouse preflight failed for ${warehouse_id}." >&2
    exit 1
  fi
}

urlencode_filter() {
  jq -nr --arg value "$1" '$value | @uri'
}

lookup_group() {
  local group_name="$1"
  local expected_group_id="$2"
  local filter response result_count actual_group_id external_id
  filter="$(urlencode_filter "displayName eq \"${group_name}\"")"
  response="$(
    databricks api get "/api/2.0/account/scim/v2/Groups?filter=${filter}" \
      -p "$profile" --output json
  )"
  result_count="$(jq -r '.totalResults // 0' <<<"$response")"
  if (( result_count > 1 )); then
    echo "More than one account group resolved for ${group_name}." >&2
    exit 1
  fi
  actual_group_id="$(jq -r '.Resources[0].id // empty' <<<"$response")"
  if [[ -n "$actual_group_id" && -z "$expected_group_id" ]]; then
    echo "Set the pinned group ID before adopting existing group ${group_name}." >&2
    exit 1
  fi
  if [[ -n "$actual_group_id" && "$actual_group_id" != "$expected_group_id" ]]; then
    echo "Pinned group ID does not match ${group_name}." >&2
    exit 1
  fi
  if [[ -z "$actual_group_id" && -n "$expected_group_id" ]]; then
    echo "Pinned group ${group_name} no longer exists; refusing replacement." >&2
    exit 1
  fi
  external_id="$(jq -r '.Resources[0].externalId // empty' <<<"$response")"
  if [[ -n "$external_id" ]]; then
    echo "Refusing to mutate externally managed group ${group_name}." >&2
    exit 1
  fi
  if jq -e '
      .Resources[0].roles[]?
      | select((.value // .display // "" | ascii_downcase) == "account_admin")
    ' >/dev/null <<<"$response"; then
    echo "Persona group cannot have the account-admin role: ${group_name}." >&2
    exit 1
  fi
  jq -r '.Resources[0].id // empty' <<<"$response"
}

verify_warehouse_permissions() {
  local permissions group_name email exact_permission direct_user_permission
  permissions="$(
    databricks warehouses get-permissions "$warehouse_id" \
      -p "$profile" --output json
  )"
  for group_name in privacy_admins restricted_users case_users; do
    exact_permission="$(
      jq -r --arg group_name "$group_name" '
        [
          .access_control_list[]?
          | select(.group_name == $group_name)
          | .all_permissions[]?
          | select(.inherited == false)
          | .permission_level
        ] as $levels
        | ($levels | length) == 1 and $levels[0] == "CAN_USE"
      ' <<<"$permissions"
    )"
    if [[ "$exact_permission" != "true" ]]; then
      echo "Persona group ${group_name} must have exactly direct warehouse CAN_USE." >&2
      exit 1
    fi
  done
  for email in "$PRIVACY_ADMIN_EMAIL" "$RESTRICTED_USER_EMAIL" "$CASE_USER_EMAIL"; do
    direct_user_permission="$(
      jq -r --arg email "$email" '
        [
          .access_control_list[]?
          | select((.user_name // "" | ascii_downcase) == ($email | ascii_downcase))
          | .all_permissions[]?
          | select(.inherited == false)
        ] | length
      ' <<<"$permissions"
    )"
    if (( direct_user_permission > 0 )); then
      echo "Persona users cannot have direct SQL warehouse permissions: ${email}." >&2
      exit 1
    fi
  done
}

create_group() {
  local group_name="$1"
  local payload response
  payload="$(jq -cn --arg display_name "$group_name" '{displayName: $display_name}')"
  response="$(
    databricks api post /api/2.0/account/scim/v2/Groups \
      -p "$profile" --json "$payload" --output json
  )"
  jq -r '.id' <<<"$response"
}

lookup_user() {
  local email="$1"
  local filter response result_count
  filter="$(urlencode_filter "userName eq \"${email}\"")"
  response="$(
    databricks api get "/api/2.0/account/scim/v2/Users?filter=${filter}" \
      -p "$profile" --output json
  )"
  result_count="$(jq -r '.totalResults // 0' <<<"$response")"
  if (( result_count > 1 )); then
    echo "More than one account user resolved for ${email}." >&2
    exit 1
  fi
  jq -r '.Resources[0].id // empty' <<<"$response"
}

create_user() {
  local email="$1"
  local persona="$2"
  local display_name payload response
  if [[ "$identity_mode" == "synthetic" ]]; then
    display_name="$(synthetic_display_name "$persona")"
    payload="$(
      jq -cn --arg user_name "$email" --arg display_name "$display_name" \
        '{userName: $user_name, displayName: $display_name, active: true}'
    )"
  else
    payload="$(jq -cn --arg user_name "$email" '{userName: $user_name, active: true}')"
  fi
  response="$(
    databricks api post /api/2.0/account/scim/v2/Users \
      -p "$profile" --json "$payload" --output json
  )"
  jq -r '.id' <<<"$response"
}

verify_user() {
  local email="$1"
  local user_id="$2"
  local persona="$3"
  local response active actual_email actual_display_name expected_display_name external_id
  local workspace_filter workspace_response workspace_result_count workspace_user_id
  [[ -z "$user_id" ]] && return
  response="$(
    databricks api get "/api/2.0/account/scim/v2/Users/${user_id}" \
      -p "$profile" --output json
  )"
  active="$(jq -r '.active // false' <<<"$response")"
  actual_email="$(jq -r '.userName // empty' <<<"$response")"
  actual_display_name="$(jq -r '.displayName // empty' <<<"$response")"
  external_id="$(jq -r '.externalId // empty' <<<"$response")"
  if [[ "$active" != "true" ]]; then
    echo "User identity is not active: ${email}" >&2
    exit 1
  fi
  if [[ "$(normalize_email "$actual_email")" != "$(normalize_email "$email")" ]]; then
    echo "Resolved SCIM identity does not match requested email: ${email}" >&2
    exit 1
  fi
  if [[ "$identity_mode" == "synthetic" && -n "$external_id" ]]; then
    echo "Synthetic users cannot be externally managed: ${email}." >&2
    exit 1
  fi
  if [[ "$identity_mode" == "synthetic" ]]; then
    expected_display_name="$(synthetic_display_name "$persona")"
    if [[ "$actual_display_name" != "$expected_display_name" ]]; then
      echo "Synthetic user provenance marker does not match: ${email}." >&2
      exit 1
    fi
  fi
  if jq -e '
      .roles[]?
      | select((.value // .display // "" | ascii_downcase) == "account_admin")
    ' >/dev/null <<<"$response"; then
    echo "Persona user cannot be an account administrator: ${email}." >&2
    exit 1
  fi

  workspace_filter="$(urlencode_filter "userName eq \"${email}\"")"
  workspace_response="$(
    databricks api get "/api/2.0/preview/scim/v2/Users?filter=${workspace_filter}" \
      -p "$profile" --output json
  )"
  workspace_result_count="$(jq -r '.totalResults // 0' <<<"$workspace_response")"
  if (( workspace_result_count > 1 )); then
    echo "More than one workspace user resolved for ${email}." >&2
    exit 1
  fi
  if (( workspace_result_count == 1 )); then
    workspace_user_id="$(jq -r '.Resources[0].id // empty' <<<"$workspace_response")"
    if [[ "$workspace_user_id" != "$user_id" ]]; then
      echo "Account and workspace user IDs do not match for ${email}." >&2
      exit 1
    fi
    if jq -e '.Resources[0].groups[]? | select(.display == "admins")' \
      >/dev/null <<<"$workspace_response"; then
      echo "Persona user cannot belong to the workspace admins group: ${email}." >&2
      exit 1
    fi
  fi
}

verify_account_membership_isolation() {
  local privacy_group_id="$1"
  local restricted_group_id="$2"
  local case_group_id="$3"
  local privacy_user_id="$4"
  local restricted_user_id="$5"
  local case_user_id="$6"
  local start_index=1 page_size=100 list_response total_results page_count
  local scanned_group_id group_response group_name membership user_id expected_group_id
  local -a group_ids memberships

  memberships=(
    "${privacy_user_id}:${privacy_group_id}"
    "${restricted_user_id}:${restricted_group_id}"
    "${case_user_id}:${case_group_id}"
  )

  while :; do
    list_response="$(
      databricks api get \
        "/api/2.0/account/scim/v2/Groups?startIndex=${start_index}&count=${page_size}" \
        -p "$profile" --output json
    )"
    total_results="$(jq -r '.totalResults // 0' <<<"$list_response")"
    group_ids=()
    while IFS= read -r scanned_group_id; do
      group_ids+=("$scanned_group_id")
    done < <(jq -r '.Resources[]?.id' <<<"$list_response")
    page_count="${#group_ids[@]}"

    if (( page_count > 0 )); then
      for scanned_group_id in "${group_ids[@]}"; do
        group_response="$(
          databricks api get "/api/2.0/account/scim/v2/Groups/${scanned_group_id}" \
            -p "$profile" --output json
        )"
        group_name="$(jq -r '.displayName // empty' <<<"$group_response")"
        for membership in "${memberships[@]}"; do
          user_id="${membership%%:*}"
          expected_group_id="${membership#*:}"
          [[ -z "$user_id" ]] && continue
          if jq -e --arg member_id "$user_id" \
            '.members[]? | select(.value == $member_id)' \
            >/dev/null <<<"$group_response"; then
            if jq -e '
                .roles[]?
                | select((.value // .display // "" | ascii_downcase) == "account_admin")
              ' >/dev/null <<<"$group_response"; then
              echo "Persona user inherits account admin through group ${group_name}." >&2
              exit 1
            fi
            if [[ "$scanned_group_id" != "$expected_group_id" \
              && "$group_name" != "account users" ]]; then
              echo "Persona user belongs to an unexpected account group: ${group_name}." >&2
              exit 1
            fi
          fi
          if [[ -n "$expected_group_id" ]] \
            && jq -e --arg member_id "$expected_group_id" \
              '.members[]? | select(.value == $member_id)' \
              >/dev/null <<<"$group_response"; then
            echo "Persona groups cannot be nested in another account group: ${group_name}." >&2
            exit 1
          fi
        done
      done
    fi

    (( start_index + page_count > total_results )) && break
    (( page_count == 0 )) && break
    (( start_index += page_count ))
  done
}

verify_persona_separation() {
  local privacy_group_id="$1"
  local restricted_group_id="$2"
  local case_group_id="$3"
  local privacy_user_id="$4"
  local restricted_user_id="$5"
  local case_user_id="$6"
  local require_expected_member="${7:-true}"
  local group_id user_id expected_user_id response
  local unexpected_member_count expected_member_count

  if [[ -n "$privacy_group_id" && -n "$restricted_group_id" \
    && "$privacy_group_id" == "$restricted_group_id" ]] \
    || [[ -n "$privacy_group_id" && -n "$case_group_id" \
    && "$privacy_group_id" == "$case_group_id" ]] \
    || [[ -n "$restricted_group_id" && -n "$case_group_id" \
    && "$restricted_group_id" == "$case_group_id" ]]; then
    echo "The persona groups must resolve to distinct SCIM IDs." >&2
    exit 1
  fi
  if [[ -n "$privacy_user_id" && -n "$restricted_user_id" \
    && "$privacy_user_id" == "$restricted_user_id" ]] \
    || [[ -n "$privacy_user_id" && -n "$case_user_id" \
    && "$privacy_user_id" == "$case_user_id" ]] \
    || [[ -n "$restricted_user_id" && -n "$case_user_id" \
    && "$restricted_user_id" == "$case_user_id" ]]; then
    echo "The persona users must resolve to distinct SCIM IDs." >&2
    exit 1
  fi

  for group_id in "$privacy_group_id" "$restricted_group_id" "$case_group_id"; do
    [[ -z "$group_id" ]] && continue
    case "$group_id" in
      "$privacy_group_id") expected_user_id="$privacy_user_id" ;;
      "$restricted_group_id") expected_user_id="$restricted_user_id" ;;
      "$case_group_id") expected_user_id="$case_user_id" ;;
    esac
    response="$(
      databricks api get "/api/2.0/account/scim/v2/Groups/${group_id}" \
        -p "$profile" --output json
    )"
    if jq -e '
        .roles[]?
        | select((.value // .display // "" | ascii_downcase) == "account_admin")
      ' >/dev/null <<<"$response"; then
      echo "Persona groups cannot have the account-admin role." >&2
      exit 1
    fi
    unexpected_member_count="$(
      jq -r --arg expected_user_id "$expected_user_id" '
        [.members[]? | select(.value != $expected_user_id)] | length
      ' <<<"$response"
    )"
    if (( unexpected_member_count > 0 )); then
      echo "Persona groups cannot contain unexpected users, service principals, or groups." >&2
      exit 1
    fi
    expected_member_count="$(
      jq -r --arg expected_user_id "$expected_user_id" '
        [.members[]? | select(.value == $expected_user_id)] | length
      ' <<<"$response"
    )"
    if [[ "$require_expected_member" == "true" && -n "$expected_user_id" ]] \
      && (( expected_member_count != 1 )); then
      echo "Persona group does not contain exactly its expected persistent user." >&2
      exit 1
    fi
    for user_id in "$privacy_user_id" "$restricted_user_id" "$case_user_id"; do
      [[ -z "$user_id" ]] && continue
      if jq -e --arg user_id "$user_id" \
        '.members[]? | select(.value == $user_id)' >/dev/null <<<"$response"; then
        case "${group_id}:${user_id}" in
          "${privacy_group_id}:${privacy_user_id}"|\
          "${restricted_group_id}:${restricted_user_id}"|\
          "${case_group_id}:${case_user_id}") ;;
          *)
            echo "A persona user already belongs to a different persona group." >&2
            exit 1
            ;;
        esac
      fi
    done
  done
}

assign_group_to_workspace() {
  local group_id="$1"
  databricks api put \
    "/api/2.0/preview/permissionassignments/principals/${group_id}" \
    -p "$profile" --json '{"permissions":["USER"]}' --output json >/dev/null
}

ensure_membership() {
  local group_id="$1"
  local user_id="$2"
  local response payload
  response="$(
    databricks api get "/api/2.0/account/scim/v2/Groups/${group_id}" \
      -p "$profile" --output json
  )"
  if jq -e --arg user_id "$user_id" '.members[]? | select(.value == $user_id)' \
    >/dev/null <<<"$response"; then
    return
  fi
  payload="$(
    jq -cn --arg user_id "$user_id" '{
      schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"],
      Operations: [{op: "add", path: "members", value: [{value: $user_id}]}]
    }'
  )"
  databricks api patch "/api/2.0/account/scim/v2/Groups/${group_id}" \
    -p "$profile" --json "$payload" --output json >/dev/null
}

grant_warehouse_use() {
  local group_name="$1"
  local payload
  payload="$(
    jq -cn --arg group_name "$group_name" '{
      access_control_list: [{group_name: $group_name, permission_level: "CAN_USE"}]
    }'
  )"
  databricks warehouses update-permissions "$warehouse_id" \
    -p "$profile" --json "$payload" --output json >/dev/null
}

configure_membership() {
  local group_name="$1"
  local group_id="$2"
  local user_id="$3"
  assign_group_to_workspace "$group_id"
  ensure_membership "$group_id" "$user_id"
  grant_warehouse_use "$group_name"
  echo "Configured ${group_name} with one USER-level workspace member and warehouse CAN_USE."
}

preflight_target

privacy_group_id="$(lookup_group privacy_admins "$expected_privacy_group_id")"
restricted_group_id="$(lookup_group restricted_users "$expected_restricted_group_id")"
case_group_id="$(lookup_group case_users "$expected_case_group_id")"
existing_group_count=0
[[ -n "$privacy_group_id" ]] && ((existing_group_count += 1))
[[ -n "$restricted_group_id" ]] && ((existing_group_count += 1))
[[ -n "$case_group_id" ]] && ((existing_group_count += 1))
if (( existing_group_count != 0 && existing_group_count != 3 )); then
  echo "Persona groups must be either all absent or all present and pinned." >&2
  exit 1
fi
privacy_user_id="$(lookup_user "$PRIVACY_ADMIN_EMAIL")"
restricted_user_id="$(lookup_user "$RESTRICTED_USER_EMAIL")"
case_user_id="$(lookup_user "$CASE_USER_EMAIL")"
require_expected_members=true
[[ "$mode" == "--apply" ]] && require_expected_members=false

verify_user "$PRIVACY_ADMIN_EMAIL" "$privacy_user_id" privacy_admins
verify_user "$RESTRICTED_USER_EMAIL" "$restricted_user_id" restricted_users
verify_user "$CASE_USER_EMAIL" "$case_user_id" case_users
verify_persona_separation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id" \
  "$require_expected_members"
verify_account_membership_isolation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id"

if [[ "$mode" == "--preflight-only" ]]; then
  [[ -z "$privacy_group_id" ]] && echo "Plan: create account group privacy_admins."
  [[ -z "$restricted_group_id" ]] && echo "Plan: create account group restricted_users."
  [[ -z "$case_group_id" ]] && echo "Plan: create account group case_users."
  [[ -z "$privacy_user_id" ]] && echo "Plan: create the privacy_admins account user."
  [[ -z "$restricted_user_id" ]] && echo "Plan: create the restricted_users account user."
  [[ -z "$case_user_id" ]] && echo "Plan: create the case_users account user."
  if [[ -n "$privacy_group_id" && -n "$restricted_group_id" && -n "$case_group_id" ]]; then
    verify_warehouse_permissions
  fi
  echo "Read-only ${identity_mode} identity and Databricks target preflight passed; no writes performed."
  exit 0
fi

[[ -z "$privacy_group_id" ]] && privacy_group_id="$(create_group privacy_admins)"
[[ -z "$restricted_group_id" ]] && restricted_group_id="$(create_group restricted_users)"
[[ -z "$case_group_id" ]] && case_group_id="$(create_group case_users)"
[[ -z "$privacy_user_id" ]] \
  && privacy_user_id="$(create_user "$PRIVACY_ADMIN_EMAIL" privacy_admins)"
[[ -z "$restricted_user_id" ]] \
  && restricted_user_id="$(create_user "$RESTRICTED_USER_EMAIL" restricted_users)"
[[ -z "$case_user_id" ]] \
  && case_user_id="$(create_user "$CASE_USER_EMAIL" case_users)"

verify_user "$PRIVACY_ADMIN_EMAIL" "$privacy_user_id" privacy_admins
verify_user "$RESTRICTED_USER_EMAIL" "$restricted_user_id" restricted_users
verify_user "$CASE_USER_EMAIL" "$case_user_id" case_users
verify_persona_separation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id" false
verify_account_membership_isolation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id"

configure_membership privacy_admins "$privacy_group_id" "$privacy_user_id"
configure_membership restricted_users "$restricted_group_id" "$restricted_user_id"
configure_membership case_users "$case_group_id" "$case_user_id"

verify_persona_separation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id" true
verify_account_membership_isolation \
  "$privacy_group_id" "$restricted_group_id" "$case_group_id" \
  "$privacy_user_id" "$restricted_user_id" "$case_user_id"

verify_user "$PRIVACY_ADMIN_EMAIL" "$privacy_user_id" privacy_admins
verify_user "$RESTRICTED_USER_EMAIL" "$restricted_user_id" restricted_users
verify_user "$CASE_USER_EMAIL" "$case_user_id" case_users
verify_warehouse_permissions

if [[ "$identity_mode" == "synthetic" ]]; then
  echo "Synthetic users are topology fixtures and cannot complete email verification."
  echo "Validate group data-plane behavior with acceptance/personas SQL file tasks."
fi

echo "Pinned persona group IDs:"
echo "PRIVACY_ADMIN_GROUP_ID=${privacy_group_id}"
echo "RESTRICTED_USER_GROUP_ID=${restricted_group_id}"
echo "CASE_USER_GROUP_ID=${case_group_id}"
