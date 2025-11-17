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

### About the Relay

This action doesn’t run on its own.  
It’s usually triggered by our **E2E Relay**, a lightweight service that waits for a preview deployment to go live and then starts the workflow with the correct metadata (preview URL, project name, and check run ID).

If you’re curious how that works, see: [RELAY.md](../RELAY.md)

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
