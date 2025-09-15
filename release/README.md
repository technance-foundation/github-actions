# Release (Changesets + pnpm)

Reusable composite action that standardizes the **release workflow**:

-   Checkout + git config
-   Node + pnpm setup
-   Install & build
-   Capture new version via Changesets
-   Create Release PR **or** publish (using `changesets/action@v1`)
-   Optionally open a PR back to your base branch after a successful publish

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
              uses: technance-foundation/github-actions/release@main
```

## With NPM Authentication

If you need to authenticate with a private NPM registry:

```yaml
- name: Release
  uses: technance-foundation/github-actions/release@main
  with:
      npm-token: ${{ secrets.NPM_TOKEN }}
```

## Advanced Usage

Override Node version, working dir, custom commands, and PR behavior:

```yaml
steps:
    - name: Release
      uses: technance-foundation/github-actions/release@main
      with:
          node-version: "20"
          pnpm-version: "9.0.6"
          working-directory: "."
          install-command: "pnpm install --frozen-lockfile"
          build-command: "pnpm build"
          version-command: "pnpm run bump"
          publish-command: "pnpm run release"
          pr-base: "main"
          pr-title: "Merge ${{ github.ref_name }} back to main"
          pr-body: "Auto-generated after publishing."
```

## Inputs

| Name                           | Default                                                        | Description                                      |
| ------------------------------ | -------------------------------------------------------------- | ------------------------------------------------ |
| `fetch-depth`                  | `0`                                                            | Checkout depth                                   |
| `ref`                          | `${{ github.ref }}`                                            | Ref to checkout                                  |
| `node-version-file`            | `.nvmrc`                                                       | Path to `.nvmrc` (ignored if `node-version` set) |
| `node-version`                 |                                                                | Explicit Node version                            |
| `pnpm-version`                 | `9.0.6`                                                        | pnpm version                                     |
| `cache`                        | `pnpm`                                                         | setup-node cache strategy                        |
| `npm-registry`                 | `https://registry.npmjs.org`                                   | Registry URL                                     |
| `npm-token`                    |                                                                | NPM token for authentication (optional)          |
| `install-command`              | `pnpm install --frozen-lockfile`                               | Install                                          |
| `build-command`                | `pnpm build`                                                   | Build                                            |
| `version-command`              | `pnpm run bump`                                                | Changesets version command                       |
| `publish-command`              | `pnpm run release`                                             | Publish command                                  |
| `use-changesets`               | `true`                                                         | Toggle changesets/action                         |
| `changesets-title`             | `Release v\${{ env.NEW_VERSION }}`                             | Title for release PR                             |
| `changesets-commit`            | `Release v\${{ env.NEW_VERSION }}`                             | Commit message                                   |
| `changesets-base-branch`       | `main`                                                         | Base branch for changesets version comparison    |
| `open-pr-to-base`              | `true`                                                         | Open PR back to base after publish               |
| `pr-base`                      | `main`                                                         | Target branch for back-merge PR                  |
| `pr-title`                     | `Merge \${{ github.ref_name }} back to \${{ inputs.pr-base }}` | Back-merge PR title                              |
| `pr-body`                      | `Auto-generated after publishing.`                             | Back-merge PR body                               |
| `working-directory`            |                                                                | Directory to run commands in                     |
| `continue-on-empty-changesets` | `true`                                                         | Skip version capture when no changesets          |

## Outputs

| Name          | Description                                             |
| ------------- | ------------------------------------------------------- |
| `published`   | `"true"` if publish occurred (from `changesets/action`) |
| `new_version` | Captured version from `changeset status`                |
| `pr_url`      | URL of created back-merge PR (if any)                   |

## Requirements

-   Workflow must grant permissions: `contents: write`, `pull-requests: write`, `id-token: write`.
-   `npm-token` input is optional - only needed for private registry authentication.
-   Env/Secrets expected:

    -   `GITHUB_TOKEN` (provided by GitHub)
    -   `NPM_TOKEN` (for install auth)
    -   `NPM_PUBLISH_TOKEN` (for publish auth)
