# Release (Changesets + pnpm, auto on main)

This composite GitHub Action implements a **fully automated release flow** using Changesets and pnpm.

-   Runs on **push to `main`**
-   Detects pending Changesets
-   Bumps versions and removes `.changeset/*.md`
-   Commits and pushes version bumps back to `main`
-   Publishes packages to npm
-   Never opens PRs or uses `changesets/action@v1`

> ⚠️ Important: Your workflow must skip this action when the commit author is the GitHub Actions bot to avoid infinite loops.

## Inputs

| Name                | Default                                        | Description                                         |
| ------------------- | ---------------------------------------------- | --------------------------------------------------- |
| `node-version`      | `20`                                           | Node.js version                                     |
| `pnpm-version`      | `9.0.6`                                        | pnpm version                                        |
| `cache`             | `pnpm`                                         | `actions/setup-node` cache strategy                 |
| `npm-registry`      | `https://registry.npmjs.org`                   | NPM registry URL                                    |
| `npm-token`         |                                                | NPM token for publishing (optional but recommended) |
| `install-command`   | `pnpm install --frozen-lockfile`               | Command to install dependencies                     |
| `build-command`     | `pnpm build`                                   | Build command                                       |
| `version-command`   | `pnpm run bump`                                | Changesets version command                          |
| `publish-command`   | `pnpm run release`                             | Publish command                                     |
| `working-directory` |                                                | Directory to run commands in                        |
| `git-user-name`     | `github-actions[bot]`                          | Git user.name for release commit                    |
| `git-user-email`    | `github-actions[bot]@users.noreply.github.com` | Git user.email for release commit                   |

## Outputs

| Name          | Description                                       |
| ------------- | ------------------------------------------------- |
| `published`   | `"true"` if a publish occurred                    |
| `new_version` | Example new version from Changesets (best effort) |

## Example Workflow

```yaml
name: Release

on:
    push:
        branches:
            - main

concurrency:
    group: release-${{ github.ref }}
    cancel-in-progress: false

jobs:
    release:
        if: github.actor != 'github-actions[bot]'
        runs-on: ubuntu-latest

        permissions:
            contents: write # required to push
            id-token: write # if you use OIDC
            # packages: write # if publishing GH packages

        env:
            NPM_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

        steps:
            - name: Run automated release
              uses: technance-foundation/github-actions/release@v2
              with:
                  node-version: "20"
                  pnpm-version: "9.0.6"
                  npm-token: ${{ env.NPM_TOKEN }}
                  # working-directory: "."
                  # install-command: "pnpm install --frozen-lockfile"
                  # build-command: "pnpm build"
                  # version-command: "pnpm run bump"
                  # publish-command: "pnpm run release"
```
