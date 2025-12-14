# Release (Changesets + pnpm, auto on main)

This composite GitHub Action implements a **fully automated release flow** using Changesets and pnpm, including **npm publishing, git tags, and GitHub Releases**.

-   Runs on **push to `main`**
-   Detects pending Changesets
-   Bumps versions and removes `.changeset/*.md`
-   Commits and pushes version bumps back to `main`
-   Publishes packages to npm
-   Creates **git tags** for released packages
-   Creates **GitHub Releases** for each published tag
-   Does **not** open PRs or rely on `changesets/action@v1`

> ⚠️ Important: Your workflow **must skip this action when the commit author is `github-actions[bot]`** to avoid infinite loops.

---

## 🚨 Important: Who Pushes the Release Commit (and Tags)

This action performs a **direct commit and push** to your release branch after applying version bumps.
It also **pushes git tags** and **creates GitHub Releases**.

The actor used depends on how you configure `push-token`.

### How the actor is selected

| Case                     | Actor used for commit / tag / release           | Notes                                  |
| ------------------------ | ----------------------------------------------- | -------------------------------------- |
| You provide `push-token` | That token’s identity (PAT or GitHub App token) | **Recommended** for protected branches |
| You omit `push-token`    | Falls back to default `GITHUB_TOKEN`            | Often blocked by branch protection     |

### Why this matters

If your branch protections require:

-   Bypass permissions
-   Non GitHub Actions actors
-   Linear history
-   No force pushes
-   or special review rules

…then **`GITHUB_TOKEN` may not be allowed to push commits, tags, or create releases**, and the job will fail.

### Recommended setup

-   Use a **GitHub App installation token** or a **dedicated bot PAT** via `push-token`.
-   If you rely on `GITHUB_TOKEN`, ensure your repo allows:

    -   `Allow GitHub Actions to bypass branch protection rules`
    -   `contents: write` permission in the workflow

### Example using a push-token (recommended)

```yaml
with:
    npm-token: ${{ secrets.NPM_PUBLISH_TOKEN }}
    push-token: ${{ secrets.RELEASE_PUSH_TOKEN }}
```

---

## 🔐 Token & Auth Requirements (Important)

Some ecosystems and registries require **multiple tokens to be present** to publish successfully.

### Recommended workflow env setup

```yaml
env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    NPM_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}
    NODE_AUTH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}
```

-   `npm-token` input is used to authenticate npm
-   `NODE_AUTH_TOKEN` is required by some publish commands
-   `push-token` controls **git push, tag push, and GitHub Releases**

---

## Inputs

| Name                | Default                                        | Description                                                                                              |
| ------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `node-version`      | `20`                                           | Node.js version                                                                                          |
| `pnpm-version`      | `9.0.6`                                        | pnpm version                                                                                             |
| `cache`             | `pnpm`                                         | Cache strategy for `actions/setup-node`                                                                  |
| `npm-registry`      | `https://registry.npmjs.org`                   | NPM registry URL                                                                                         |
| `npm-token`         |                                                | NPM token for publishing (required for publish)                                                          |
| `push-token`        | _(empty)_                                      | Token used for commits, tags, and GitHub Releases. Required if branch protection blocks workflow pushes. |
| `install-command`   | `pnpm install --frozen-lockfile`               | Dependency install command                                                                               |
| `build-command`     | `pnpm build`                                   | Build command                                                                                            |
| `version-command`   | `pnpm run bump`                                | Changesets version command (bumps versions and removes `.changeset` files)                               |
| `publish-command`   | `pnpm run release`                             | Publish command                                                                                          |
| `working-directory` |                                                | Directory to run commands inside                                                                         |
| `git-user-name`     | `github-actions[bot]`                          | Git user.name for release commit                                                                         |
| `git-user-email`    | `github-actions[bot]@users.noreply.github.com` | Git user.email for release commit                                                                        |
| `commit-style`      | `normal`                                       | Commit message style: `normal` or `conventional`                                                         |
| `commit-message`    |                                                | Fully override the commit message                                                                        |

---

## Outputs

| Name          | Description                                                 |
| ------------- | ----------------------------------------------------------- |
| `published`   | `'true'` if a publish occurred                              |
| `new_version` | Example new version extracted from Changesets (best effort) |

---

## 🏷️ Git Tags & GitHub Releases

When a publish occurs, the action:

1. Creates **git tags** for each released package
   Example:

    ```
    @technance/platform-sdk@5.2.1
    ```

2. Pushes those tags to the repository

3. Creates **GitHub Releases** for each tag using:

    - Tag name as the release title
    - Auto-generated release notes (`gh release create --generate-notes`)

> ℹ️ Requires the **GitHub CLI (`gh`)** to be available on the runner.
> GitHub-hosted runners include it by default.

---

## Commit Messages

Commit messages are generated from Changesets output unless overridden.

### `commit-style: normal` (default)

-   **Single package**

    ```
    Release `@technance/worphling@10.0.2`
    ```

-   **Multiple packages**

    ```
    Release packages

    - Released `@technance/worphling@12.3.1`
    - Released `@technance/code-style@1.0.0`
    ```

-   **Fallback**

    ```
    Release package(s)
    ```

### `commit-style: conventional`

-   **Single package**

    ```
    chore: release @technance/worphling@10.0.2
    ```

-   **Multiple packages**

    ```
    chore: release packages
    ```

If `commit-message` is provided, it takes precedence and disables auto generation.

---

## Example Workflow (Recommended)

```yaml
name: Release

on:
    push:
        branches:
            - main
    workflow_dispatch:

concurrency:
    group: release-${{ github.ref }}
    cancel-in-progress: false

jobs:
    release:
        if: github.actor != 'github-actions[bot]'
        runs-on: ubuntu-latest

        permissions:
            contents: write
            id-token: write

        env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
            NPM_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}
            NODE_AUTH_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

        steps:
            - name: Automated release
              uses: technance-foundation/github-actions/release@v2
              with:
                  node-version: "22"
                  pnpm-version: "10.15.0"
                  npm-token: ${{ env.NPM_TOKEN }}
                  push-token: ${{ secrets.RELEASE_PUSH_TOKEN }}
                  git-user-name: "technance-bot"
                  git-user-email: "technance-bot@users.noreply.github.com"
```

---

## How It Works (Step by Step)

1. Checkout repository
2. Configure git identity
3. Setup Node.js and pnpm
4. Verify required tools (`jq`, `gh`)
5. Authenticate npm registry
6. Install dependencies
7. Build packages
8. Detect pending Changesets
9. If changes exist:

    - Run version bump
    - Generate commit message
    - Commit and push changes

10. Publish packages to npm
11. Create git tags
12. Create GitHub Releases
13. Set outputs and clean up artifacts

---

## Notes and Limitations

-   Performs a **direct push to main**
-   Does **not** open PRs
-   Assumes a standard Changesets setup
-   Release metadata files (`release.json`, `release.filtered.json`) are **never committed**
-   If tagging or release creation fails due to permissions, publish may still succeed
