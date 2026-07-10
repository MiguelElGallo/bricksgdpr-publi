#!/usr/bin/env bash
set -euo pipefail

mode="${1:---tree}"
if [[ "$mode" != "--tree" && "$mode" != "--history" ]]; then
  echo "Usage: $0 [--tree|--history]" >&2
  exit 2
fi

for command_name in git rg; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Required command is not available: ${command_name}." >&2
    exit 2
  fi
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

file_list="$(mktemp)"
trap 'rm -f "$file_list"' EXIT
git ls-files --cached --others --exclude-standard -z >"$file_list"

failed=0

publication_commits() {
  git rev-list HEAD --branches --tags --remotes
}

is_sensitive_path() {
  local candidate="$1"
  case "$candidate" in
    .env.example)
      return 1
      ;;
    .env|.env.*|*.env|*.env.*|\
    .databrickscfg|*/.databrickscfg|\
    .databricks/*|*/.databricks/*|\
    .dbt/*|*/.dbt/*|\
    .config/databricks/*|*/.config/databricks/*|\
    .config/dbt/*|*/.config/dbt/*|\
    .user.yml|*/.user.yml|\
    logs/*|*/logs/*|target/*|*/target/*|\
    credentials*.json|*/credentials*.json|\
    token.json|*/token.json|token-cache.json|*/token-cache.json|*.token|\
    *.pem|*.key|*.p8|*.p12|*.pfx|*.jks|*.keystore|\
    id_dsa|*/id_dsa|id_ecdsa|*/id_ecdsa|id_ed25519|*/id_ed25519|id_rsa|*/id_rsa)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

report_tree_sensitive_paths() {
  local candidate matches=""
  while IFS= read -r -d '' candidate; do
    if is_sensitive_path "$candidate"; then
      matches+="${candidate}"$'\n'
    fi
  done <"$file_list"
  matches="$(printf '%s' "$matches" | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "sensitive filename:"
    echo "$matches"
    failed=1
  fi
}

report_history_sensitive_paths() {
  local commit candidate matches=""
  while IFS= read -r commit; do
    while IFS= read -r -d '' candidate; do
      if is_sensitive_path "$candidate"; then
        matches+="${commit}:${candidate}"$'\n'
      fi
    done < <(git ls-tree -r -z --name-only "$commit")
  done < <(publication_commits)
  matches="$(printf '%s' "$matches" | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "sensitive filename:"
    echo "$matches"
    failed=1
  fi
}

report_tree_rule() {
  local rule="$1" pattern="$2" matches
  matches="$({
    xargs -0 rg -n -H --no-heading --color never -e "$pattern" <"$file_list" || true
  } | sed -E 's#^([^:]+:[0-9]+):.*#\1#' | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "${rule}:"
    echo "$matches"
    failed=1
  fi
}

report_history_rule() {
  local rule="$1" pattern="$2" matches
  matches="$({
    while IFS= read -r commit; do
      git grep -n -I -E "$pattern" "$commit" -- . || true
    done < <(publication_commits)
  } | sed -E 's#^([0-9a-f]+:[^:]+:[0-9]+):.*#\1#' | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "${rule}:"
    echo "$matches"
    failed=1
  fi
}

report_tree_emails() {
  local matches
  matches="$({
    xargs -0 rg -n -H -o --no-heading --color never \
      -g '!uv.lock' \
      -e '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' \
      <"$file_list" || true
  } | awk -F: '
      {
        email = $NF
        email_lower = tolower(email)
        domain = email_lower
        sub(/^.*@/, "", domain)
        if (domain !~ /(^|\.)invalid$/ &&
            domain !~ /(^|\.)example$/ &&
            domain != "example.com" &&
            domain != "example.net" &&
            domain != "example.org" &&
            domain != "users.noreply.github.com" &&
            email_lower != "noreply@github.com") {
          print $1 ":" $2
        }
      }
    ' | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "non-reserved email address:"
    echo "$matches"
    failed=1
  fi
}

report_history_emails() {
  local matches
  matches="$({
    while IFS= read -r commit; do
      git grep -n -I -E -o \
        '[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}' \
        "$commit" -- . ':(exclude)uv.lock' || true
    done < <(publication_commits)
  } | awk -F: '
      {
        email = $NF
        email_lower = tolower(email)
        domain = email_lower
        sub(/^.*@/, "", domain)
        if (domain !~ /(^|\.)invalid$/ &&
            domain !~ /(^|\.)example$/ &&
            domain != "example.com" &&
            domain != "example.net" &&
            domain != "example.org" &&
            domain != "users.noreply.github.com" &&
            email_lower != "noreply@github.com") {
          print $1 ":" $2 ":" $3
        }
      }
    ' | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "non-reserved email address:"
    echo "$matches"
    failed=1
  fi
}

report_history_commit_emails() {
  local matches
  matches="$({
    while IFS= read -r commit; do
      git show -s \
        --format="${commit}%x09%ae%n${commit}%x09%ce" \
        "$commit"
    done < <(publication_commits)
  } | awk -F '\t' '
      {
        email = tolower($2)
        domain = email
        sub(/^.*@/, "", domain)
        if (domain !~ /(^|\.)invalid$/ &&
            domain !~ /(^|\.)example$/ &&
            domain != "example.com" &&
            domain != "example.net" &&
            domain != "example.org" &&
            domain != "users.noreply.github.com" &&
            email != "noreply@github.com") {
          print $1 ":commit-email"
        }
      }
    ' | sort -u)"
  if [[ -n "$matches" ]]; then
    echo "non-reserved commit email metadata:"
    echo "$matches"
    failed=1
  fi
}

workspace_host='(dbc-[[:alnum:]-]+\.databricks\.com|([[:alnum:]-]+\.)+(cloud|gcp)\.databricks\.com|adb-[0-9]+\.[0-9]+\.azuredatabricks\.net)'
warehouse_id='(/sql/1\.0/warehouses/[0-9a-f]{16}|DATABRICKS_WAREHOUSE_ID[[:space:]]*=[[:space:]]*[0-9a-f]{16}|warehouse_id:[[:space:]]*[0-9a-f]{16})'
account_id='DATABRICKS_ACCOUNT_ID[[:space:]]*=[[:space:]]*[0-9a-f]{8}-[0-9a-f-]{27,}'
group_id='(PRIVACY_ADMIN|RESTRICTED_USER|CASE_USER)_GROUP_ID[[:space:]]*=[[:space:]]*[0-9]{5,}'
home_path='/Users/[[:alnum:]_.-]+/'
known_token='(dapi[a-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})'
private_key='BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'

if [[ "$mode" == "--history" ]]; then
  report_history_sensitive_paths
  report_history_rule "Databricks workspace host" "$workspace_host"
  report_history_rule "Databricks warehouse identifier" "$warehouse_id"
  report_history_rule "Databricks account identifier" "$account_id"
  report_history_rule "Databricks group identifier" "$group_id"
  report_history_rule "personal home path" "$home_path"
  report_history_rule "credential-shaped token" "$known_token"
  report_history_rule "private key material" "$private_key"
  report_history_emails
  report_history_commit_emails
else
  report_tree_sensitive_paths
  report_tree_rule "Databricks workspace host" "$workspace_host"
  report_tree_rule "Databricks warehouse identifier" "$warehouse_id"
  report_tree_rule "Databricks account identifier" "$account_id"
  report_tree_rule "Databricks group identifier" "$group_id"
  report_tree_rule "personal home path" "$home_path"
  report_tree_rule "credential-shaped token" "$known_token"
  report_tree_rule "private key material" "$private_key"
  report_tree_emails
fi

if (( failed != 0 )); then
  echo "Publication safety check failed. Matched values are intentionally redacted." >&2
  exit 1
fi

echo "Publication safety check passed (${mode#--})."
