# AI Translation PR

Reusable composite GitHub Action that maintains a deterministic AI translation PR powered by Worphling.

It is designed for repositories where translation files should be generated automatically whenever a source pull request changes.

This action:

- Detects affected Worphling-enabled projects
- Runs `worphling check`
- Creates or updates a dedicated automation branch
- Runs `worphling sync`
- Opens or updates a PR back into the source branch
- Writes a readable pre-sync and post-sync summary into the PR body
- Cleans up stale PRs and branches when no translation work is needed

## When to use this

Use this action when you want generated translation updates to live in a separate PR instead of modifying the source PR branch directly.

This is useful for:

- Monorepos with multiple Worphling-enabled apps or packages
- Root-level projects using `project-roots: "."`
- Teams that want AI-generated translation changes reviewed separately

## Inputs

| Name                        | Required | Description                                                                           |
| --------------------------- | -------- | ------------------------------------------------------------------------------------- |
| `github-token`              | Yes      | GitHub token used for branch and PR operations                                        |
| `npm-token`                 | No       | NPM token used for private dependency installation                                    |
| `openai-api-key`            | Yes      | OpenAI API key used by Worphling                                                      |
| `pr-number`                 | Yes      | Source pull request number                                                            |
| `source-branch`             | Yes      | Source pull request head branch                                                       |
| `source-sha`                | Yes      | Source pull request head SHA                                                          |
| `automation-branch`         | Yes      | Branch used for generated AI translation changes                                      |
| `labels`                    | No       | Multiline labels applied to the AI translation PR                                     |
| `node-version`              | No       | Node.js version                                                                       |
| `pnpm-version`              | No       | pnpm version                                                                          |
| `install-command`           | No       | Install command passed to the shared setup action                                     |
| `build-command`             | No       | Build command passed to the shared setup action, or `false`                           |
| `working-directory`         | No       | Working directory passed to the shared setup action                                   |
| `project-roots`             | No       | Multiline list of Worphling project roots. Supports `.` and shell globs like `apps/*` |
| `artifact-root`             | No       | Directory where Worphling reports are written                                         |
| `global-invalidation-paths` | No       | Repo-level paths that invalidate all Worphling projects                               |
| `pr-title-template`         | No       | PR title template. Use `__PR_NUMBER__` as the placeholder                             |
| `pr-close-comment-template` | No       | Close comment template. Use `__PR_NUMBER__` as the placeholder                        |

## Outputs

| Name                     | Description                                                            |
| ------------------------ | ---------------------------------------------------------------------- |
| `affected-count`         | Number of affected Worphling-enabled projects                          |
| `affected-projects-json` | JSON array of affected project keys                                    |
| `changed-count`          | Number of projects that actually require generated translation changes |
| `changed-projects-json`  | JSON array of changed project keys                                     |
| `any-changes`            | Whether any project required generated translation changes             |

## Placeholder format

For user-configurable text templates, use:

```txt
__PR_NUMBER__
```

Example:

```yaml
pr-title-template: "Update AI translations for #__PR_NUMBER__"
pr-close-comment-template: "Closing automatically because PR #__PR_NUMBER__ no longer requires generated AI translation updates."
```

## Monorepo example

```yaml
name: AI Translation PR

on:
    pull_request:
        types:
            - opened
            - synchronize
            - reopened
            - ready_for_review
        paths:
            - "apps/**"
            - "apps/**/locales/**"
            - "apps/**/worphling.config.*"
            - "apps/**/translation-context.md"
            - "package.json"
            - "pnpm-lock.yaml"

concurrency:
    group: ai-translation-pr-${{ github.event.pull_request.number }}
    cancel-in-progress: true

permissions:
    contents: write
    pull-requests: write
    issues: write

jobs:
    ai-translation-pr:
        if: >
            github.event.pull_request.head.repo.full_name == github.repository &&
            !startsWith(github.event.pull_request.head.ref, 'worphling/')

        runs-on: ubuntu-latest

        steps:
            - name: Checkout source PR head
              uses: actions/checkout@v6
              with:
                  ref: ${{ github.event.pull_request.head.sha }}
                  fetch-depth: 0
                  persist-credentials: true

            - name: Maintain AI translation PR
              uses: technance-foundation/github-actions/ai-translation-pr@main
              with:
                  github-token: ${{ github.token }}
                  npm-token: ${{ secrets.NPM_TOKEN }}
                  openai-api-key: ${{ secrets.OPENAI_API_KEY }}
                  pr-number: ${{ github.event.pull_request.number }}
                  source-branch: ${{ github.event.pull_request.head.ref }}
                  source-sha: ${{ github.event.pull_request.head.sha }}
                  automation-branch: worphling/pr-${{ github.event.pull_request.number }}
                  project-roots: |
                      apps/*
                  artifact-root: ".github-artifacts/worphling"
                  global-invalidation-paths: |
                      package.json
                      pnpm-lock.yaml
                  pr-title-template: "Update AI translations for #__PR_NUMBER__"
                  pr-close-comment-template: "Closing automatically because PR #__PR_NUMBER__ no longer requires generated AI translation updates."
                  labels: |
                      automated
                      translations
                      worphling
```

## Root project example

```yaml
- name: Maintain AI translation PR
  uses: technance-foundation/github-actions/ai-translation-pr@main
  with:
      github-token: ${{ github.token }}
      npm-token: ${{ secrets.NPM_TOKEN }}
      openai-api-key: ${{ secrets.OPENAI_API_KEY }}
      pr-number: ${{ github.event.pull_request.number }}
      source-branch: ${{ github.event.pull_request.head.ref }}
      source-sha: ${{ github.event.pull_request.head.sha }}
      automation-branch: worphling/pr-${{ github.event.pull_request.number }}
      project-roots: |
          .
      artifact-root: ".github-artifacts/worphling"
      global-invalidation-paths: |
          package.json
          pnpm-lock.yaml
```

## Notes

- The action expects the caller workflow to checkout the repository before using it.
- `project-roots` can mix globs and explicit paths.
- If a global invalidation path changes, all Worphling-enabled projects are included.
- The generated PR body contains both pre-sync and post-sync summaries for easier review.
