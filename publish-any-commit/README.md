# Publish Any Commit (pkg-pr-new + pnpm)

Preview-publish packages from **any commit/PR** using `pnpm dlx pkg-pr-new publish`.
This action handles checkout, Node/pnpm setup, install, optional build, and running `pkg-pr-new` for **one or more** package paths.

## Minimal Usage

```yaml
name: Publish Any Commit
on:
    workflow_dispatch:
    pull_request:
    push:
        branches: ["**"]
        tags: ["!**"]
        paths:
            - "**" # adjust as needed

env:
    NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
    TURBO_TOKEN: ${{ secrets.VERCEL_TECHNANCE_TOKEN }}
    TURBO_TEAM: ${{ vars.TURBO_TEAM }}
    FORCE_COLOR: 3

jobs:
    build:
        runs-on: ubuntu-latest
        steps:
            - uses: technance-foundation/github-actions/publish-any-commit@main
```

## Target a Single Package

```yaml
- uses: technance-foundation/github-actions/publish-any-commit@main
  with:
      package-paths: "./packages/worphling"
```

## Target Multiple Packages

```yaml
- uses: technance-foundation/github-actions/publish-any-commit@main
  with:
      package-paths: |
          ./packages/nova
          ./packages/react-lib
```

or space-separated:

```yaml
with:
    package-paths: "./packages/nova ./packages/react-lib"
```

## Repo-wide (root)

```yaml
with:
    package-paths: "."
```

## Inputs

| Name                    | Default                          | Description                                            |
| ----------------------- | -------------------------------- | ------------------------------------------------------ |
| `fetch-depth`           | `0`                              | Checkout depth                                         |
| `ref`                   | `${{ github.ref }}`              | Ref to checkout                                        |
| `node-version-file`     | `.nvmrc`                         | Path to `.nvmrc` (ignored if `node-version` set)       |
| `node-version`          |                                  | Explicit Node version                                  |
| `pnpm-version`          | `9.0.6`                          | pnpm version                                           |
| `cache`                 | `pnpm`                           | setup-node cache strategy                              |
| `npm-registry`          | `https://registry.npmjs.org`     | Registry URL                                           |
| `install-command`       | `pnpm install --frozen-lockfile` | Install                                                |
| `build-command`         | `pnpm build`                     | Build (set to `""` to skip)                            |
| `package-paths`         | `.`                              | One or more package paths (newline or space-separated) |
| `pkg-pr-new-version`    | `latest`                         | Version/range for `pkg-pr-new`                         |
| `pkg-pr-new-extra-args` |                                  | Extra args passed to `pkg-pr-new publish`              |
| `working-directory`     |                                  | Directory to run commands in                           |

## Requirements

-   `NPM_TOKEN` must be set in `env:` (for registry authentication).
-   The workflow that uses this action typically runs on:

    ```yaml
    on:
        workflow_dispatch:
        pull_request:
        push:
            branches: ["**"]
            tags: ["!**"]
            paths: # narrow for faster CI if you like
                - "packages/<your-pkg>/**"
                - ".github/workflows/preview-release.yml"
    ```
