# Load Env Action

This GitHub Action loads environment variables from a `.env`‑style file into the job environment so they are available to all subsequent steps in the same job.

## Features

- Reads variables from any `.env`‑style file
- Supports comments (`# ...`) and blank lines inside the `.env` file
- Provides the loaded environment variables by exporting them into `$GITHUB_ENV`

## Inputs

| Input  | Description                              | Required |
|--------|:-----------------------------------------|----------|
| `file` | Path to the `.env` file to be loaded     |    Yes   |

## Usage

### Example Workflow

```yaml
name: "Example with Load Env"

on: push

jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Load environment variables
        uses: technance-foundation/github-actions/.github/actions/load-env@main
        with:
          file: .env.ci

      - name: Do work with the loaded env
        run: ...
```

## Notes

- This action **does not** override variables already set in the workflow or job `env:` block — those take precedence.
- If the file path provided in `file` does not exist, the action will fail.
