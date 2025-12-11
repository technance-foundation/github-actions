# Release (Changesets + pnpm, auto on main)

This composite GitHub Action implements a **fully automated release flow** using Changesets and pnpm.

-   Runs on **push to `main`**
-   Detects pending Changesets
-   Bumps versions and removes `.changeset/*.md`
-   Commits and pushes version bumps back to `main`
-   Publishes packages to npm
-   Does **not** open PRs or rely on `changesets/action@v1`

> ⚠️ Important: Your workflow must skip this action when the commit author is `github-actions[bot]` to avoid infinite loops.

---

## 🚨 Important: Who Pushes the Release Commit

This action performs a **direct commit and push** to your release branch after applying version bumps.
The actor used for this push depends on how you configure the `push-token` input.

### How the actor is selected

| Case                     | Actor used for commit                                     | Notes                              |
| ------------------------ | --------------------------------------------------------- | ---------------------------------- |
| You provide `push-token` | That token becomes the identity (PAT or GitHub App token) | Recommended for protected branches |
| You omit `push-token`    | Falls back to default `GITHUB_TOKEN`                      | Often blocked by branch protection |

### Why this matters

If your branch protections require:

-   Bypass permissions
-   Non GitHub Actions actors
-   Linear history
-   No force pushes
-   or special review rules

...then **`GITHUB_TOKEN` may not be allowed to push**, and your release job will fail at the push step.

### Recommended setup

-   Use a **GitHub App installation token** or a **namespace PAT bot token** via `push-token`.
-   If you want to use `GITHUB_TOKEN`, ensure your repo allows:

    -   `Allow GitHub Actions to bypass branch protection rules`
    -   `contents: write` permission in the workflow

### Example using a push-token (recommended)

```yaml
with:
    npm-token: ${{ secrets.NPM_PUBLISH_TOKEN }}
    push-token: ${{ secrets.RELEASE_PUSH_TOKEN }}
```

---

## Inputs

| Name                | Default                                        | Description                                                                                                                              |
| ------------------- | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `node-version`      | `20`                                           | Node.js version                                                                                                                          |
| `pnpm-version`      | `9.0.6`                                        | pnpm version                                                                                                                             |
| `cache`             | `pnpm`                                         | Cache strategy for `actions/setup-node`                                                                                                  |
| `npm-registry`      | `https://registry.npmjs.org`                   | NPM registry URL                                                                                                                         |
| `npm-token`         |                                                | NPM token for publishing (optional, but required for publish)                                                                            |
| `push-token`        | _(empty)_                                      | Token used to push release commits. If omitted, falls back to `GITHUB_TOKEN`. Required if your branch protection blocks workflow pushes. |
| `install-command`   | `pnpm install --frozen-lockfile`               | Dependency install command                                                                                                               |
| `build-command`     | `pnpm build`                                   | Build command                                                                                                                            |
| `version-command`   | `pnpm run bump`                                | Changesets version command (bumps versions and removes `.changeset` files)                                                               |
| `publish-command`   | `pnpm run release`                             | Publish command                                                                                                                          |
| `working-directory` |                                                | Directory to run commands inside                                                                                                         |
| `git-user-name`     | `github-actions[bot]`                          | Git user.name for release commit                                                                                                         |
| `git-user-email`    | `github-actions[bot]@users.noreply.github.com` | Git user.email for release commit                                                                                                        |
| `commit-style`      | `normal`                                       | Commit message style: `normal` or `conventional`. Controls the format of the auto generated release commit message.                      |
| `commit-message`    |                                                | Override the commit message completely. If set, `commit-style` and auto generation are ignored and this value is used as-is.             |

---

## Outputs

| Name          | Description                                                 |
| ------------- | ----------------------------------------------------------- |
| `published`   | `'true'` if a publish occurred                              |
| `new_version` | Example new version extracted from Changesets (best effort) |

---

## Commit Messages

This action generates a commit message based on the Changesets release information and the selected `commit-style`, unless you explicitly override it with `commit-message`.

### `commit-style: normal` (default)

-   **Single package**

    ```text
    Release `@technance/worphling@10.0.2`
    ```

-   **Multiple packages**

    ```text
    Release packages

    - Released `@technance/worphling@12.3.1`
    - Released `@technance/code-style@1.0.0`
    - Released `@technance/stash@6.0.1`
    ```

-   **Fallback (no releases detected / status failure)**

    ```text
    Release package(s)
    ```

### `commit-style: conventional`

-   **Single package**

    ```text
    chore: release @technance/worphling@10.0.2
    ```

-   **Multiple packages**

    ```text
    chore: release packages

    - Released `@technance/worphling@12.3.1`
    - Released `@technance/code-style@1.0.0`
    - Released `@technance/stash@6.0.1`
    ```

-   **Fallback (no releases detected / status failure)**

    ```text
    chore: release package(s)
    ```

If the action cannot read release information from Changesets (for example if `changeset status` fails), it falls back to the `Release package(s)` / `chore: release package(s)` messages, depending on `commit-style`.

If you set `commit-message`, that value is used directly and `commit-style` is ignored.

---

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
        # Avoid infinite loops
        if: github.actor != 'github-actions[bot]'
        runs-on: ubuntu-latest

        permissions:
            contents: write # required to push commits
            id-token: write # optional, for OIDC auth
            # packages: write # if publishing to GitHub packages

        env:
            NPM_TOKEN: ${{ secrets.NPM_PUBLISH_TOKEN }}

        steps:
            - name: Automated release
              uses: technance-foundation/github-actions/release@v2
              with:
                  node-version: "20"
                  pnpm-version: "9.0.6"
                  npm-token: ${{ env.NPM_TOKEN }}

                  # Recommended: supply a push token
                  push-token: ${{ secrets.RELEASE_PUSH_TOKEN }}

                  # Optional: pick commit style (normal|conventional)
                  # commit-style: "conventional"

                  # Optional: fully override commit message
                  # commit-message: "Release monorepo packages for sprint 42"

                  # Optional overrides
                  # working-directory: '.'
                  # install-command: 'pnpm install --frozen-lockfile'
                  # build-command: 'pnpm build'
                  # version-command: 'pnpm run bump'
                  # publish-command: 'pnpm run release'
```

---

## How It Works (Step by Step)

1. **Checkout repository**

2. **Configure git** (sets bot user.name/email)

3. **Setup pnpm and Node**

4. **Authenticate npm registry** if `npm-token` is supplied

5. **Install dependencies**

6. **Build packages**

7. **Check for pending Changesets**

8. If changes exist:

    - Run version bump
    - Detect git diffs
    - Generate a commit message based on `commit-style` and Changesets output
    - Commit and push the changes

9. **Publish packages**

10. Set `published` and `new_version` outputs

---

## Notes and Limitations

-   The action performs a **direct push to main**, which is why configuring the pushing actor is critical.
-   The action does **not** open PRs.
-   It assumes your project uses Changesets with a standard setup.
-   The action intentionally removes `.changeset/*.md` after versioning.
-   Commit messages are generated based on Changesets status output; if that fails, the action falls back to generic `Release package(s)` / `chore: release package(s)` messages depending on `commit-style`.
-   If `commit-message` is set, it takes precedence over all automatic commit message generation.
