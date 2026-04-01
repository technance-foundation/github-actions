#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required but was not found on PATH." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but was not found on PATH." >&2
  exit 1
fi

: "${CHANGED_PROJECTS_JSON:?CHANGED_PROJECTS_JSON is required}"
: "${PR_BODY_FILE:?PR_BODY_FILE is required}"
: "${OPENAI_API_KEY:?OPENAI_API_KEY is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${SOURCE_BRANCH:?SOURCE_BRANCH is required}"
: "${SOURCE_SHA:?SOURCE_SHA is required}"
: "${AUTOMATION_BRANCH:?AUTOMATION_BRANCH is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

PROJECT_ROOTS_RAW="${PROJECT_ROOTS:-apps/*}"
REPORT_ROOT="${ARTIFACT_ROOT:-.github-artifacts/worphling}"
PR_TITLE_TEMPLATE="${AI_TRANSLATION_PR_TITLE_TEMPLATE:-Update AI translations for #__PR_NUMBER__}"

mkdir -p "$REPORT_ROOT"

repo_root="$(git rev-parse --show-toplevel)"

render_template() {
  local template="$1"
  local pr_number="$2"

  template="${template//__PR_NUMBER__/$pr_number}"

  printf '%s\n' "$template"
}

pr_title="$(render_template "$PR_TITLE_TEMPLATE" "$PR_NUMBER")"

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

resolve_report_output_path() {
  local project_dir="$1"
  local output_path="$2"

  if [ -z "$output_path" ]; then
    return
  fi

  case "$output_path" in
    /*)
      printf '%s\n' "$output_path"
      ;;
    *)
      (
        cd "$project_dir"
        python3 -c 'import os, sys; print(os.path.abspath(sys.argv[1]))' "$output_path"
      )
      ;;
  esac
}

stage_project_outputs_from_report() {
  local project_dir="$1"
  local report_file="$2"
  local any_paths="false"

  if [ ! -s "$report_file" ]; then
    echo "Cannot stage outputs because report file is missing: ${report_file}" >&2
    return 1
  fi

  if ! jq -e '.outputs != null' "$report_file" >/dev/null 2>&1; then
    echo "Cannot stage outputs because report is missing .outputs: ${report_file}" >&2
    return 1
  fi

  while IFS= read -r output_path; do
    local resolved_path

    [ -z "$output_path" ] && continue
    any_paths="true"
    resolved_path="$(resolve_report_output_path "$project_dir" "$output_path")"

    echo "Staging reported output: ${output_path}"
    echo "Resolved reported output: ${resolved_path}"

    if [ -e "$resolved_path" ]; then
      git add --all -- "$resolved_path"
    else
      echo "Reported output path does not exist on disk: ${resolved_path}" >&2
    fi
  done < <(
    jq -r '
      [
        (.outputs.writtenLocaleFiles[]?),
        (.outputs.writtenSnapshotFile // empty)
      ]
      | .[]
    ' "$report_file"
  )

  if [ "$any_paths" != "true" ]; then
    echo "Report contains no written output paths: ${report_file}" >&2
  fi
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

extract_error_issue_count() {
  local file="$1"
  jq -r '[.issues[]? | select(.severity == "error")] | length' "$file" 2>/dev/null || echo "0"
}

extract_warning_issue_count() {
  local file="$1"
  jq -r '[.issues[]? | select(.severity == "warning")] | length' "$file" 2>/dev/null || echo "0"
}

write_error_issue_bullets() {
  local file="$1"
  local output_file="$2"

  jq -r '
    [.issues[]? | select(.severity == "error")][0:10]
    | .[]
    | "- `" + .key + "` -- " + .type + ": " + .message
  ' "$file" > "$output_file" 2>/dev/null || : > "$output_file"
}

count_staged_files_for_project() {
  local project_dir="$1"
  local count="0"

  count="$(git diff --cached --name-only -- "$project_dir" | sed '/^[[:space:]]*$/d' | wc -l | tr -d '[:space:]')"

  if [ -z "$count" ]; then
    count="0"
  fi

  printf '%s\n' "$count"
}

apply_labels_to_pr() {
  local pr_number="$1"

  if [ -z "${AI_TRANSLATION_PR_LABELS:-}" ]; then
    return 0
  fi

  while IFS= read -r label; do
    label="$(printf '%s' "$label" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$label" ] && continue

    gh pr edit "$pr_number" \
      --repo "$GITHUB_REPOSITORY" \
      --add-label "$label" || true
  done <<< "$AI_TRANSLATION_PR_LABELS"
}

find_open_pr_number() {
  gh pr list \
    --repo "$GITHUB_REPOSITORY" \
    --state open \
    --head "$AUTOMATION_BRANCH" \
    --json number \
    --jq '.[0].number // empty'
}

find_closed_unmerged_pr_number() {
  gh pr list \
    --repo "$GITHUB_REPOSITORY" \
    --state closed \
    --head "$AUTOMATION_BRANCH" \
    --json number,mergedAt \
    --jq '.[] | select(.mergedAt == null) | .number' \
    | head -n 1
}

replace_post_sync_section() {
  local body_file="$1"
  local replacement_file="$2"

  local cleaned_file
  cleaned_file="$(mktemp)"

  awk '
    BEGIN {
      in_post_sync = 0
    }
    /^## ✨ Post-sync summary$/ {
      if (!in_post_sync) {
        in_post_sync = 1
      }
      next
    }
    in_post_sync && /^## / {
      in_post_sync = 0
      print
      next
    }
    !in_post_sync {
      print
    }
  ' "$body_file" > "$cleaned_file"

  {
    sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}' "$cleaned_file"
    echo
    echo
    cat "$replacement_file"
    echo
  } > "$body_file"
}

mapfile -t changed_project_keys < <(jq -r '.[]' <<< "$CHANGED_PROJECTS_JSON")

if [ "${#changed_project_keys[@]}" -eq 0 ]; then
  echo "No changed projects provided. Nothing to sync."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

temp_pr_body="$(mktemp)"
cp "$PR_BODY_FILE" "$temp_pr_body"

echo "Rebuilding ${AUTOMATION_BRANCH} deterministically from ${SOURCE_SHA}"
git checkout --force -B "$AUTOMATION_BRANCH" "$SOURCE_SHA"
git clean -fd

mkdir -p "$REPORT_ROOT"

post_sync_summary_file="$(mktemp)"
project_cards_file="$(mktemp)"

overall_verification_failed="false"
overall_sync_failed="false"
any_generated_changes="false"

{
  echo "## ✨ Post-sync summary"
  echo
  echo "Generated translation updates were applied where possible. Verification results are shown below."
  echo
  echo "| Project | Result | Files changed | Remaining issues |"
  echo "| --- | --- | ---: | --- |"
} > "$post_sync_summary_file"

for project_key in "${changed_project_keys[@]}"; do
  project_dir="${project_path_by_key[$project_key]:-}"

  if [ -z "$project_dir" ]; then
    echo "No project directory found for key ${project_key}" >&2
    overall_sync_failed="true"
    continue
  fi

  config_file="$(find_project_config "$project_dir")"

  if [ -z "$config_file" ]; then
    echo "No Worphling config found for ${project_dir}" >&2
    overall_sync_failed="true"
    continue
  fi

  config_name="$(basename "$config_file")"
  project_report_dir="${REPORT_ROOT}/${project_key}"
  mkdir -p "$project_report_dir"

  sync_report="${project_report_dir}/sync-report.json"
  post_check_report="${project_report_dir}/post-check-report.json"
  sync_report_abs="${repo_root}/${sync_report}"
  post_check_report_abs="${repo_root}/${post_check_report}"
  project_label="$(project_label_for_key "$project_key")"

  echo "Running worphling sync for ${project_label}"
  set +e
  (
    cd "$project_dir"
    OPENAI_API_KEY="$OPENAI_API_KEY" pnpm exec worphling sync \
      --write \
      --config "$config_name" \
      --report-file "$sync_report_abs"
  )
  sync_exit_code=$?
  set -e

  if [ ! -s "$sync_report" ]; then
    echo "worphling sync did not produce a readable report for ${project_label} (exit code ${sync_exit_code})" >&2
    overall_sync_failed="true"

    echo "| \`${project_label}\` | ❌ Sync failed | 0 | sync failed before a readable report was produced |" >> "$post_sync_summary_file"

    {
      echo
      echo "<details>"
      echo "<summary><strong>📌 ${project_label}</strong></summary>"
      echo
      echo "- **Result**: ❌ Sync failed"
      echo "- **Sync exit code**: ${sync_exit_code}"
      echo "- **Files changed**: 0"
      echo "- **Reason**: Worphling sync did not produce a readable report."
      echo
      echo "</details>"
    } >> "$project_cards_file"

    continue
  fi

  echo "worphling sync exit code for ${project_label}: ${sync_exit_code}"

  if ! jq -e '.summary != null' "$sync_report" >/dev/null 2>&1; then
    echo "Sync report for ${project_label} is missing .summary" >&2
    overall_sync_failed="true"
  fi

  if ! jq -e '.outputs != null' "$sync_report" >/dev/null 2>&1; then
    echo "Sync report for ${project_label} is missing .outputs" >&2
    overall_sync_failed="true"
  fi

  echo "Running post-sync verification for ${project_label}"
  set +e
  (
    cd "$project_dir"
    OPENAI_API_KEY="$OPENAI_API_KEY" pnpm exec worphling check \
      --config "$config_name" \
      --report-file "$post_check_report_abs"
  )
  post_check_exit_code=$?
  set -e

  if [ ! -s "$post_check_report" ]; then
    echo "Post-sync worphling check did not produce a readable report for ${project_label} (exit code ${post_check_exit_code})" >&2
    overall_verification_failed="true"

    stage_project_outputs_from_report "$project_dir" "$sync_report"

    staged_files_count="$(count_staged_files_for_project "$project_dir")"

    if [ "$staged_files_count" -gt 0 ]; then
      any_generated_changes="true"
    fi

    echo "| \`${project_label}\` | ⚠️ Synced but verification failed | ${staged_files_count} | post-sync check failed before a readable report was produced |" >> "$post_sync_summary_file"

    {
      echo
      echo "<details>"
      echo "<summary><strong>📌 ${project_label}</strong></summary>"
      echo
      echo "- **Result**: ⚠️ Synced but verification failed"
      echo "- **Sync exit code**: ${sync_exit_code}"
      echo "- **Post-sync check exit code**: ${post_check_exit_code}"
      echo "- **Files changed**: ${staged_files_count}"
      echo "- **Reason**: Post-sync verification did not produce a readable report."
      echo
      echo "</details>"
    } >> "$project_cards_file"

    continue
  fi

  if ! jq -e '.summary.hasChanges != null' "$post_check_report" >/dev/null 2>&1; then
    echo "Post-sync report for ${project_label} is missing summary.hasChanges" >&2
    cat "$post_check_report" >&2 || true
    overall_verification_failed="true"
  fi

  echo "Post-sync worphling check exit code for ${project_label}: ${post_check_exit_code}"

  stage_project_outputs_from_report "$project_dir" "$sync_report"

  staged_files_count="$(count_staged_files_for_project "$project_dir")"

  if [ "$staged_files_count" -gt 0 ]; then
    any_generated_changes="true"
  fi

  has_changes="$(jq -r '.summary.hasChanges // false' "$post_check_report")"
  remaining_missing="$(extract_missing "$post_check_report")"
  remaining_extra="$(extract_extra "$post_check_report")"
  remaining_modified="$(extract_modified "$post_check_report")"
  error_issue_count="$(extract_error_issue_count "$post_check_report")"
  warning_issue_count="$(extract_warning_issue_count "$post_check_report")"

  issue_summary="errors: ${error_issue_count}, warnings: ${warning_issue_count}, missing: ${remaining_missing}, extra: ${remaining_extra}, modified: ${remaining_modified}"

  result_label="✅ Synced and verified"
  result_description="✅ Synced successfully"

  if [ "$post_check_exit_code" -ne 0 ] || [ "$has_changes" != "false" ] || [ "$error_issue_count" -gt 0 ]; then
    overall_verification_failed="true"
    result_label="⚠️ Synced with verification issues"
    result_description="⚠️ Synced with verification issues"
  fi

  echo "| \`${project_label}\` | ${result_label} | ${staged_files_count} | ${issue_summary} |" >> "$post_sync_summary_file"

  {
    echo
    echo "<details>"
    echo "<summary><strong>📌 ${project_label}</strong></summary>"
    echo
    echo "- **Result**: ${result_description}"
    echo "- **Sync exit code**: ${sync_exit_code}"
    echo "- **Post-sync check exit code**: ${post_check_exit_code}"
    echo "- **Files changed**: ${staged_files_count}"
    echo "- **Remaining errors**: ${error_issue_count}"
    echo "- **Remaining warnings**: ${warning_issue_count}"
    echo "- **Remaining missing**: ${remaining_missing}"
    echo "- **Remaining extra**: ${remaining_extra}"
    echo "- **Remaining modified**: ${remaining_modified}"
    echo "- **Has remaining changes**: ${has_changes}"
    echo

    if [ "$error_issue_count" -gt 0 ]; then
      error_issue_bullets_file="$(mktemp)"
      write_error_issue_bullets "$post_check_report" "$error_issue_bullets_file"

      echo "### Remaining error issues"
      echo
      if [ -s "$error_issue_bullets_file" ]; then
        cat "$error_issue_bullets_file"
      else
        echo "- Error issues remain, but they could not be rendered."
      fi
      echo

      rm -f "$error_issue_bullets_file"
    fi

    echo "</details>"
  } >> "$project_cards_file"
done

if [ "$any_generated_changes" != "true" ] && git diff --cached --quiet; then
  echo "Worphling reported changes but no generated files were staged." >&2
  exit 1
fi

post_sync_combined_file="$(mktemp)"
{
  cat "$post_sync_summary_file"
  cat "$project_cards_file"
} > "$post_sync_combined_file"

replace_post_sync_section "$temp_pr_body" "$post_sync_combined_file"

if ! git diff --cached --quiet; then
  git commit -m "Update AI translations for #${PR_NUMBER}"
  git push --force-with-lease origin "HEAD:refs/heads/${AUTOMATION_BRANCH}"
else
  echo "No staged file changes were produced, but PR body will still reflect verification results."
fi

open_pr_number="$(find_open_pr_number)"

if [ -n "$open_pr_number" ]; then
  gh pr edit "$open_pr_number" \
    --repo "$GITHUB_REPOSITORY" \
    --title "$pr_title" \
    --body-file "$temp_pr_body"

  apply_labels_to_pr "$open_pr_number"

  echo "Updated existing AI translation PR #${open_pr_number}"
elif [ -n "$(find_closed_unmerged_pr_number)" ]; then
  closed_unmerged_pr_number="$(find_closed_unmerged_pr_number)"

  gh pr reopen "$closed_unmerged_pr_number" --repo "$GITHUB_REPOSITORY"

  gh pr edit "$closed_unmerged_pr_number" \
    --repo "$GITHUB_REPOSITORY" \
    --title "$pr_title" \
    --body-file "$temp_pr_body"

  apply_labels_to_pr "$closed_unmerged_pr_number"

  echo "Reopened and updated AI translation PR #${closed_unmerged_pr_number}"
else
  set +e
  gh pr create \
    --repo "$GITHUB_REPOSITORY" \
    --base "$SOURCE_BRANCH" \
    --head "$AUTOMATION_BRANCH" \
    --title "$pr_title" \
    --body-file "$temp_pr_body"
  create_exit_code=$?
  set -e

  new_pr_number="$(find_open_pr_number)"

  if [ -z "$new_pr_number" ] && [ "$create_exit_code" -ne 0 ]; then
    echo "Failed to create AI translation PR and no existing PR was found." >&2
    exit "$create_exit_code"
  fi

  if [ -n "$new_pr_number" ]; then
    apply_labels_to_pr "$new_pr_number"
    echo "AI translation PR is available as #${new_pr_number}"
  fi
fi

if [ "$overall_sync_failed" = "true" ]; then
  echo "One or more projects failed during sync. PR was still published when possible." >&2
  exit 1
fi

if [ "$overall_verification_failed" = "true" ]; then
  echo "One or more projects were synced, but post-sync verification still has issues. PR was published with failure details." >&2
  exit 1
fi

exit 0