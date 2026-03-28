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

: "${PR_NUMBER:?PR_NUMBER is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

PROJECT_ROOTS_RAW="${PROJECT_ROOTS:-apps/*}"
REPORT_ROOT="${ARTIFACT_ROOT:-.github-artifacts/worphling}"
GLOBAL_INVALIDATION_PATHS_RAW="${GLOBAL_INVALIDATION_PATHS:-package.json
pnpm-lock.yaml}"

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

  local base
  base="$(basename "$project_path")"

  if [ -n "$base" ] && [ "$base" != "." ] && [ "$base" != "/" ]; then
    printf '%s\n' "$base"
    return
  fi

  printf '%s\n' "$project_path" | sed 's#[/ ]#-#g'
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

is_global_invalidation_path() {
  local candidate="$1"
  local path

  while IFS= read -r path; do
    path="$(printf '%s' "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -z "$path" ] && continue

    if [ "$candidate" = "$path" ]; then
      return 0
    fi
  done <<< "$GLOBAL_INVALIDATION_PATHS_RAW"

  return 1
}

file_belongs_to_project() {
  local file="$1"
  local project_path="$2"

  if [ "$project_path" = "." ]; then
    return 0
  fi

  case "$file" in
    "$project_path"/*) return 0 ;;
    "$project_path") return 0 ;;
    *) return 1 ;;
  esac
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

mapfile -t changed_files < <(
  gh api --paginate "repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/files" --jq '.[].filename'
)

echo "Changed files for PR #${PR_NUMBER}:"
printf ' - %s\n' "${changed_files[@]:-}"

declare -A affected_map=()
global_invalidation="false"

for file in "${changed_files[@]:-}"; do
  if is_global_invalidation_path "$file"; then
    global_invalidation="true"
  fi
done

if [ "$global_invalidation" = "true" ]; then
  echo "Global dependency/config file changed. Expanding to all Worphling-enabled projects."
  for project_key in "${!project_path_by_key[@]}"; do
    affected_map["$project_key"]=1
  done
else
  for file in "${changed_files[@]:-}"; do
    for project_key in "${!project_path_by_key[@]}"; do
      project_path="${project_path_by_key[$project_key]}"
      if file_belongs_to_project "$file" "$project_path"; then
        affected_map["$project_key"]=1
      fi
    done
  done
fi

affected_keys=()

for project_key in "${!affected_map[@]}"; do
  affected_keys+=("$project_key")
done

if [ "${#affected_keys[@]}" -gt 0 ]; then
  IFS=$'\n' affected_keys=($(printf '%s\n' "${affected_keys[@]}" | sort -u))
fi

printf '%s\n' "${affected_keys[@]:-}" > "${REPORT_ROOT}/affected-projects.txt"

affected_count="${#affected_keys[@]}"

if [ "${#affected_keys[@]}" -gt 0 ]; then
  affected_json="$(jq -cn '$ARGS.positional' --args "${affected_keys[@]}")"
else
  affected_json='[]'
fi

{
  echo "affected_count=${affected_count}"
  echo "affected_projects_json=${affected_json}"
} >> "$GITHUB_OUTPUT"

echo "Affected Worphling projects (${affected_count}):"
printf ' - %s\n' "${affected_keys[@]:-}"