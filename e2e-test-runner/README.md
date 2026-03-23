# E2E Test Runner

Complete reusable GitHub Action that:

- Marks GitHub Check Run as **in_progress**
- Sets up Node + pnpm
- Installs root dependencies
- Caches Playwright browsers
- Installs Playwright deps/browsers on cache miss
- Runs Playwright tests
- Uploads Playwright HTML report
- Marks GitHub Check Run as **completed**

---

## About the Relay

This action doesn’t run on its own.  
It’s usually triggered by our [**E2E Relay**](../RELAY.md), a lightweight service that waits for a preview deployment to go live and then starts the workflow with the correct metadata (preview URL, project name, and check run ID).

If you’re curious how that works, see: [RELAY.md](../RELAY.md)

---

## Inputs

| Name                 | Required | Description                                                       |
| -------------------- | -------- | ----------------------------------------------------------------- |
| `token`              | ✔️       | GitHub token with `checks: write`                                 |
| `check-run-id`       | ✔️       | The GitHub Check Run ID                                           |
| `project`            | ✔️       | Project/app name used for reporting and default working directory |
| `preview-url`        | ✔️       | BASE_URL for testing                                              |
| `npm-token`          | ✔️       | NPM token for installing private dependencies                     |
| `node-version`       | –        | Node version (`22`)                                               |
| `pnpm-version`       | –        | pnpm version (`10.15.0`)                                          |
| `playwright-version` | –        | Playwright version (`1.53.2`)                                     |
| `test-command`       | –        | Command used to run E2E tests (default: `pnpm run test:e2e`)      |
| `working-directory`  | –        | Working directory where E2E tests should run                      |

---

## Working directory behavior

If `working-directory` is not provided, the action defaults to:

```txt
apps/<project>
```

This keeps the action convenient for standard app layouts while allowing custom repo structures when needed.

---

## Usage Example

### Default

Uses:

- `pnpm run test:e2e`
- `apps/<project>` as working directory

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@v1
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: ${{ inputs.project }}
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
```

---

### Custom test command

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@v1
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: ${{ inputs.project }}
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
      test-command: pnpm run test:e2e:ci
```

---

### Custom working directory

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@v1
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: midnight
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
      working-directory: apps/midnight
```

---

### Example: run a specific test file

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@v1
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: ${{ inputs.project }}
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
      test-command: pnpm exec playwright test tests/e2e/tests/flows/auth/register.spec.ts
```

---

### Example: custom working directory and custom test command

```yaml
- uses: technance-foundation/github-actions/e2e-test-runner@v1
  with:
      token: ${{ steps.app-token.outputs.token }}
      check-run-id: ${{ inputs.check_run_id }}
      project: midnight
      preview-url: ${{ inputs.url }}
      npm-token: ${{ secrets.NPM_TOKEN }}
      working-directory: apps/midnight
      test-command: pnpm run test:e2e:ci
```
