# E2E Test Runner

Complete reusable GitHub Action that:

-   Marks GitHub Check Run as **in_progress**
-   Sets up Node + pnpm
-   Installs root dependencies
-   Caches Playwright browsers
-   Installs Playwright deps/browsers on cache miss
-   Runs Playwright tests
-   Uploads Playwright HTML report
-   Marks GitHub Check Run as **completed**

This replaces 20+ lines of workflow steps with one action.

---

## Inputs

| Name                 | Required | Description                           |
| -------------------- | -------- | ------------------------------------- |
| `token`              | ✔️       | GitHub token with `checks: write`     |
| `check-run-id`       | ✔️       | The GitHub Check Run ID               |
| `project`            | ✔️       | Project/app folder under `apps/`      |
| `preview-url`        | ✔️       | BASE_URL for testing                  |
| `npm-token`          | ✔️       | NPM token for installing private deps |
| `node-version`       | –        | Node version (`22`)                   |
| `pnpm-version`       | –        | pnpm version (`10.15.0`)              |
| `playwright-version` | –        | Playwright version (`1.53.2`)         |

---

## Usage Example

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@main
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: ${{ inputs.project }}
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
```
