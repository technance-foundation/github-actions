# E2E Check Runner

Reusable composite GitHub Action that updates GitHub Check Runs for E2E tests.

It implements two states:

-   **`in_progress`** — called at the start of the workflow
-   **`completed`** — called at the end, posting the summary

This action wraps the logic from our relay-driven E2E system and allows any workflow in any repo to easily update check runs.

### Where this is used

Most of the time, this action is called by our **E2E Relay**, which creates the check runs and updates them as the workflow progresses.  
If you want to understand the bigger picture of how checks are created and triggered, take a look at: [RELAY.md](../RELAY.md)

---

## Inputs

| Name           | Required | Description                                         |
| -------------- | -------- | --------------------------------------------------- |
| `token`        | ✔️       | GitHub token with `checks: write` permission        |
| `check-run-id` | ✔️       | Check run to update                                 |
| `state`        | ✔️       | `"in_progress"` or `"completed"`                    |
| `job-status`   | –        | `"success"` or `"failure"` (required for completed) |
| `project`      | –        | Project/app name (completed only)                   |
| `preview-url`  | –        | Preview deployment URL (completed only)             |

---

## Usage

### Mark check as in_progress

```yaml
- uses: technance-foundation/github-actions/e2e-check@main
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      state: in_progress
```

### Mark check as completed

```yaml
- uses: technance-foundation/github-actions/e2e-check@main
  if: always()
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      state: completed
      job-status: ${{ job.status }}
      project: ${{ inputs.project }}
      preview-url: ${{ inputs.url }}
```
