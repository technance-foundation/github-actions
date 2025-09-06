# Check Workflow Action

This is a reusable GitHub Action designed to run various checks (like linting, formatting, and testing) in projects using Node.js and pnpm.

## Features

-   Sets up Node.js and pnpm for the workflow
-   Installs dependencies using pnpm & configures caches to optimize
-   Allows running a customizable check command

## Inputs

| Input               | Description                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `node-version`      | The version of Node.js to use. Default is `20`                                                                        |
| `pnpm-version`      | The version of pnpm to use. Default is `9.0.6`                                                                        |
| `check-command`     | The command to run checks. This could be a lint command, test, etc... or a combined one. Default is `pnpm run check`. |
| `npm-token`         | NPM token for authenticating to the NPM registry                                                                      |
| `working-directory` | The path in which node commands should execute. Defaults to project root                                              |

## Usage

### Example Workflow

To use this reusable action in your GitHub workflow, create a new workflow YAML file (e.g., `.github/workflows/check.yml`) in the repo:

```yaml
name: "Check"

on: push

jobs:
    check:
        runs-on: ubuntu-latest
        steps:
            - uses: technance-foundation/github-actions/check@main
              with:
                  node-version: "20"
                  pnpm-version: "9.0.6"
                  check-command: "pnpm run check"
```

### Example Check Commands

You can configure the `check-command` to run different checks:

-   **Lint**: `pnpm run lint`
-   **Prettier**: `pnpm run prettier`
-   **Tests**: `pnpm run test`
-   **Combined**: Create a combined script in your `package.json`:

```json
{
    "scripts": {
        "check": "pnpm run lint && pnpm run prettier --check && pnpm run test"
    }
}
```

Then, in the workflow, you can simply use:

```yaml
check-command: "pnpm run check"
```
