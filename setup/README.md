# Setup Workflow Action

This is a reusable GitHub Action designed to prepare a Node.js + pnpm project for subsequent workflow steps.
It handles environment setup, dependency installation, caching, and optional build - so later jobs can run without repeating setup.

## Features

-   Sets up Node.js and pnpm for the workflow
-   Restores and saves the pnpm store cache for faster installs
-   Authenticates to the NPM registry (for private packages)
-   Installs dependencies (optional)
-   Builds the project (optional)
-   Allows overriding install/build commands or skipping them entirely

## Inputs

| Input          | Description                                                                                                                      |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `node-version` | The version of Node.js to use. Default is `20`.                                                                                  |
| `pnpm-version` | The version of pnpm to use. Default is `9.0.6`.                                                                                  |
| `pnpm-cache`   | Cache strategy can be one of `read`, `write`, or `off`. Default is `write`                                                       |
| `npm-token`    | NPM token for authenticating to the NPM registry. Required if installing from private packages.                                  |
| `install`      | Either `"false"` to skip installing dependencies, or the install command to run. Default is `pnpm install --no-frozen-lockfile`. |
| `build`        | Either `"false"` to skip building, or the build command to run. Default is `pnpm build`.                                         |

## Usage

### Example Workflow

To use this reusable action in your GitHub workflow, create a new workflow YAML file (e.g., `.github/workflows/setup.yml`) in the repo:

```yaml
name: "Setup"

on: push

jobs:
    setup:
        runs-on: ubuntu-latest
        steps:
            - uses: technance-foundation/github-actions/setup@v1
              with:
                  node-version: "20"
                  pnpm-version: "10.6.5"
                  npm-token: ${{ secrets.NPM_TOKEN }}
```

### Skipping Install or Build

If you want to skip install or build:

```yaml
- uses: technance-foundation/github-actions/setup@v1
  with:
  npm-token: ${{ secrets.NPM_TOKEN }}
  install: "false"
  build: "false"
```

### Custom Install/Build Commands

You can override the defaults:

```yaml
- uses: technance-foundation/github-actions/setup@v1
  with:
  npm-token: ${{ secrets.NPM_TOKEN }}
  install: "pnpm install --frozen-lockfile"
  build: "pnpm run build:prod"
```
