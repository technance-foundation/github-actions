# Release (Changesets + pnpm)

Reusable composite action that standardizes the **release workflow**:

-   Checkout + git config
-   Node + pnpm setup
-   Install & build
-   Capture new version via Changesets
-   Create Release PR **or** publish (using `changesets/action@v1`)
-   Optionally create and auto squash-merge a PR back to your base branch after a successful publish

## Minimal Usage

```yaml
name: Release
on:
    push:
        branches: [release]

permissions:
    contents: write
    pull-requests: write
    id-token: write

env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
    NPM_PUBLISH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}
    TURBO_TOKEN: ${{ secrets.VERCEL_TECHNANCE_TOKEN }}
    TURBO_TEAM: ${{ vars.TURBO_TEAM }}
    FORCE_COLOR: 3

concurrency: ${{ github.workflow }}-${{ github.ref }}

jobs:
    publish:
        runs-on: ubuntu-latest
        timeout-minutes: 15
        steps:
            - name: Release
              uses: technance-foundation/github-actions/release@v1
```

## With NPM Authentication

If you need to authenticate with a private NPM registry:

```yaml
- name: Release
  uses: technance-foundation/github-actions/release@v1
  with:
      npm-token: ${{ secrets.NPM_TOKEN }}
```

## Advanced Usage

Override Node version, working dir, custom commands, and PR behavior:

```yaml
steps:
    - name: Release
      uses: technance-foundation/github-actions/release@v1
      with:
          node-version: "20"
          pnpm-version: "9.0.6"
          working-directory: "."
          install-command: "pnpm install --frozen-lockfile"
          build-command: "pnpm build"
          version-command: "pnpm run bump"
          publish-command: "pnpm run release"
          pr-base: "main"
          auto-merge: true
```

## Dynamic PR Titles

The action generates distinct titles for the two PRs in the release flow:

| Packages    | Prepare PR (version bumps)               | Release PR (back-merge)          |
| ----------- | ---------------------------------------- | -------------------------------- |
| 1 package   | `` Prepare release `@scope/pkg@1.2.3` `` | `` Publish `@scope/pkg@1.2.3` `` |
| 2+ packages | `Prepare new releases`                   | `Publish new releases`           |

This keeps your PR history clear and your commit history on `main` clean:

```
abc1234 Publish `@myorg/utils@2.1.0`
ghi9012 Publish `@myorg/core@3.0.0`
```

## Back-Merge Behavior

After a successful publish, the action can automatically merge the release branch back to your base branch:

| Configuration                                | Behavior                                                        |
| -------------------------------------------- | --------------------------------------------------------------- |
| `open-pr-to-base: true`, `auto-merge: true`  | Creates PR and immediately squash-merges using admin privileges |
| `open-pr-to-base: true`, `auto-merge: false` | Creates PR but leaves it open for manual review                 |
| `open-pr-to-base: false`                     | No back-merge PR created                                        |

> **Note:** When `auto-merge: true`, the action uses `gh pr merge --admin` which bypasses branch protection rules. This requires the `GITHUB_TOKEN` to have admin access to the repository.

## Inputs

| Name                           | Default                            | Description                                                 |
| ------------------------------ | ---------------------------------- | ----------------------------------------------------------- |
| `fetch-depth`                  | `0`                                | Checkout depth                                              |
| `ref`                          | `${{ github.ref }}`                | Ref to checkout                                             |
| `node-version-file`            | `.nvmrc`                           | Path to `.nvmrc` (ignored if `node-version` set)            |
| `node-version`                 |                                    | Explicit Node version                                       |
| `pnpm-version`                 | `9.0.6`                            | pnpm version                                                |
| `cache`                        | `pnpm`                             | setup-node cache strategy                                   |
| `npm-registry`                 | `https://registry.npmjs.org`       | Registry URL                                                |
| `npm-token`                    |                                    | NPM token for authentication (optional)                     |
| `install-command`              | `pnpm install --frozen-lockfile`   | Install                                                     |
| `build-command`                | `pnpm build`                       | Build                                                       |
| `version-command`              | `pnpm run bump`                    | Changesets version command                                  |
| `publish-command`              | `pnpm run release`                 | Publish command                                             |
| `use-changesets`               | `true`                             | Toggle changesets/action                                    |
| `changesets-title`             | `Release`                          | Title for release PR (deprecated, auto-generated)           |
| `changesets-commit`            | `Release`                          | Commit message (deprecated, auto-generated)                 |
| `changesets-base-branch`       | `main`                             | Base branch for changesets version comparison               |
| `open-pr-to-base`              | `true`                             | Open PR back to base after publish                          |
| `pr-base`                      | `main`                             | Target branch for back-merge PR                             |
| `pr-title`                     |                                    | Override back-merge PR title (uses dynamic title if empty)  |
| `pr-body`                      | `Auto-generated after publishing.` | Back-merge PR body                                          |
| `auto-merge`                   | `true`                             | Auto squash-merge the back-merge PR (requires admin access) |
| `working-directory`            |                                    | Directory to run commands in                                |
| `continue-on-empty-changesets` | `true`                             | Skip version capture when no changesets                     |

## Outputs

| Name            | Description                                                          |
| --------------- | -------------------------------------------------------------------- |
| `published`     | `"true"` if publish occurred (from `changesets/action`)              |
| `new_version`   | Captured version from `changeset status`                             |
| `prepare_title` | Title for prepare PR (e.g. `` Prepare release `@scope/pkg@1.0.0` ``) |
| `release_title` | Title for back-merge PR (e.g. `` Publish `@scope/pkg@1.0.0` ``)      |
| `release_count` | Number of packages in this release                                   |
| `pr_url`        | URL of created back-merge PR (if any)                                |

## Requirements

-   Workflow must grant permissions: `contents: write`, `pull-requests: write`, `id-token: write`.
-   `npm-token` input is optional - only needed for private registry authentication.
-   **Admin access required** if using `auto-merge: true` (the default). The `GITHUB_TOKEN` must have admin privileges to bypass branch protection rules. Alternatively, set `auto-merge: false` to create the PR without auto-merging.
-   Env/Secrets expected:

    -   `GITHUB_TOKEN` (provided by GitHub, needs admin access for auto-merge)
    -   `NPM_TOKEN` (for install auth)
    -   `NPM_PUBLISH_TOKEN` (for publish auth)
