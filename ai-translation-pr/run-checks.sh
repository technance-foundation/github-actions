#!/usr/bin/env bash
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but was not found on PATH." >&2
  exit 1
fi

: "${AFFECTED_PROJECTS_JSON:?AFFECTED_PROJECTS_JSON is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${SOURCE_BRANCH:?SOURCE_BRANCH is required}"
: "${AUTOMATION_BRANCH:?AUTOMATION_BRANCH is required}"

PROJECT_ROOTS_RAW="${PROJECT_ROOTS:-apps/*}"
REPORT_ROOT="${ARTIFACT_ROOT:-.github-artifacts/worphling}"

mkdir -p "$REPORT_ROOT"

find_project_config() {
  local project_dir="$1"
  find "$project_dir" -maxdepth 1 -type f \
    \( -name 'worphling.config.js' -o -name 'worphling.config.mjs' -o -name 'worphling.config.cjs' -o -name 'worphling.config.ts' \) \
    | sort \
    | head -n 1
}

normalize_path() {
  local value="$1"

  if [ "$value" = "." ]; then
    printf '.\n'
    return
  fi

  value="${value%/}"
  printf '%s\n' "$value"
}

project_key_for_path() {
  local project_path="$1"

  if [ "$project_path" = "." ]; then
    printf 'root\n'
    return
  fi

  project_path="${project_path%/}"
  printf '%s\n' "$project_path" | sed 's#[/. ]#-#g'
}

project_label_for_key() {
  local project_key="$1"

  if [ "$project_key" = "root" ]; then
    printf 'root project\n'
    return
  fi

  printf '%s\n' "$project_key"
}

expand_project_roots() {
  local line
  local pattern
  local matched

  while IFS= read -r line; do
    pattern="$(printf '%s' "$line" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$pattern" ] && continue

    if [ "$pattern" = "." ]; then
      printf '.\n'
      continue
    fi

    matched="false"
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      matched="true"
      normalize_path "$path"
    done < <(compgen -G "$pattern" || true)

    if [ "$matched" = "false" ] && [ -d "$pattern" ]; then
      normalize_path "$pattern"
    fi
  done <<< "$PROJECT_ROOTS_RAW"
}

declare -A project_path_by_key=()

while IFS= read -r project_path; do
  [ -z "$project_path" ] && continue
  [ -d "$project_path" ] || continue

  if [ -n "$(find_project_config "$project_path")" ]; then
    project_key="$(project_key_for_path "$project_path")"
    project_path_by_key["$project_key"]="$project_path"
  fi
done < <(expand_project_roots | sort -u)

json_number() {
  local file="$1"
  local jq_expr="$2"
  jq -r "$jq_expr // 0" "$file" 2>/dev/null || echo "0"
}

extract_missing() {
  local file="$1"
  json_number "$file" '
    .summary.missingCount
    // .summary.missing
    // .counts.missing
    // .totals.missing
  '
}

extract_extra() {
  local file="$1"
  json_number "$file" '
    .summary.extraCount
    // .summary.extra
    // .counts.extra
    // .totals.extra
  '
}

extract_modified() {
  local file="$1"
  json_number "$file" '
    .summary.modifiedCount
    // .summary.modified
    // .counts.modified
    // .totals.modified
  '
}

mapfile -t project_keys < <(jq -r '.[]' <<<"$AFFECTED_PROJECTS_JSON")

changed_project_keys=()
pr_body_file="${REPORT_ROOT}/ai-translation-pr-body.md"

{
  echo "# 🤖 AI translation PR"
  echo
  echo "This PR is automatically maintained by the AI translation workflow."
  echo
  echo "It contains generated translation updates for source PR #${PR_NUMBER}."
  echo
  echo "## Overview"
  echo
  echo "- **Source PR**: #${PR_NUMBER}"
  echo "- **Source branch**: \`${SOURCE_BRANCH}\`"
  echo "- **Automation branch**: \`${AUTOMATION_BRANCH}\`"
  echo
  echo "> [!IMPORTANT]"
  echo "> Merge this AI translation PR into the source branch before the source PR is merged to \`main\`."
  echo
  echo "## 📦 Projects selected for review"
  echo
} > "$pr_body_file"

for project_key in "${project_keys[@]}"; do
  project_dir="${project_path_by_key[$project_key]:-}"

  if [ -z "$project_dir" ]; then
    echo "No project directory found for key ${project_key}, skipping."
    continue
  fi

  config_file="$(find_project_config "$project_dir")"

  if [ -z "$config_file" ]; then
    echo "No Worphling config found for ${project_dir}, skipping."
    continue
  fi

  config_name="$(basename "$config_file")"
  project_report_dir="${REPORT_ROOT}/${project_key}"
  mkdir -p "$project_report_dir"

  check_report="${project_report_dir}/check-report.json"
  project_label="$(project_label_for_key "$project_key")"

  echo "Running worphling check for ${project_label}"

  set +e
  (
    cd "$project_dir"
    OPENAI_API_KEY="${OPENAI_API_KEY:-}" pnpm exec worphling check \
      --config "$config_name" \
      --report-file "../../${check_report}"
  )
  exit_code=$?
  set -e

  if [ ! -s "$check_report" ]; then
    echo "worphling check did not produce a readable report for ${project_label} (exit code ${exit_code})" >&2
    exit "$exit_code"
  fi

  if ! jq -e '.summary.hasChanges != null' "$check_report" >/dev/null 2>&1; then
    echo "worphling check report for ${project_label} is missing summary.hasChanges" >&2
    cat "$check_report" >&2 || true
    exit 1
  fi

  echo "worphling check exit code for ${project_label}: ${exit_code}"

  has_changes="$(jq -r '.summary.hasChanges // false' "$check_report")"

  if [ "$has_changes" = "true" ]; then
    changed_project_keys+=("$project_key")
    echo "- ✅ \`${project_label}\`" >> "$pr_body_file"
  else
    echo "- ℹ️ \`${project_label}\` -- already up to date" >> "$pr_body_file"
  fi
done

if [ "${#changed_project_keys[@]}" -gt 0 ]; then
  {
    echo
    echo "## 🔎 Pre-sync summary"
    echo
    echo "The following projects still need generated translation updates before sync runs:"
    echo
    echo
    echo "| Project | Missing | Extra | Modified |"
    echo "| --- | ---: | ---: | ---: |"
  } >> "$pr_body_file"

  for project_key in "${changed_project_keys[@]}"; do
    check_report="${REPORT_ROOT}/${project_key}/check-report.json"
    project_label="$(project_label_for_key "$project_key")"
    missing_count="$(extract_missing "$check_report")"
    extra_count="$(extract_extra "$check_report")"
    modified_count="$(extract_modified "$check_report")"

    echo "| \`${project_label}\` | ${missing_count} | ${extra_count} | ${modified_count} |" >> "$pr_body_file"
  done

  {
    echo
    echo "## ✨ Post-sync summary"
    echo
    echo "_This section will be filled automatically after the sync step completes._"
  } >> "$pr_body_file"
else
  {
    echo
    echo "## ✅ Pre-sync summary"
    echo
    echo "All reviewed projects are already up to date. No generated translation changes are needed."
  } >> "$pr_body_file"
fi

changed_count="${#changed_project_keys[@]}"

if [ "${#changed_project_keys[@]}" -gt 0 ]; then
  changed_json="$(jq -cn '$ARGS.positional' --args "${changed_project_keys[@]}")"
else
  changed_json='[]'
fi

{
  echo "changed_projects_json=${changed_json}"
  echo "changed_count=${changed_count}"
  echo "any_changes=$([ "$changed_count" -gt 0 ] && echo true || echo false)"
  echo "pr_body_file=${pr_body_file}"
} >> "$GITHUB_OUTPUT"

echo "Projects with Worphling changes (${changed_count}):"
for project_key in "${changed_project_keys[@]:-}"; do
  project_label="$(project_label_for_key "$project_key")"
  printf ' - %s\n' "$project_label"
done