#!/usr/bin/env bash
set -euo pipefail

: "${PR_NUMBER:?PR_NUMBER is required}"
: "${AUTOMATION_BRANCH:?AUTOMATION_BRANCH is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"

render_template() {
  local template="$1"
  local pr_number="$2"

  template="${template//__PR_NUMBER__/$pr_number}"

  printf '%s\n' "$template"
}

comment_template="${AI_TRANSLATION_PR_CLOSE_COMMENT_TEMPLATE:-Closing automatically because PR #__PR_NUMBER__ no longer requires generated AI translation updates.}"
comment="$(render_template "$comment_template" "$PR_NUMBER")"

open_pr_number="$({ gh pr list --repo "$GITHUB_REPOSITORY" --state open --head "${AUTOMATION_BRANCH}" --json number --jq '.[0].number // empty'; } || true)"

if [ -n "$open_pr_number" ]; then
  gh pr close "$open_pr_number" \
    --repo "$GITHUB_REPOSITORY" \
    --comment "$comment" \
    --delete-branch=false
fi

git push origin --delete "$AUTOMATION_BRANCH" >/dev/null 2>&1 || true