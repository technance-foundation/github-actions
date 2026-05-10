# E2E Test Runner

Complete reusable GitHub Action that:

- Marks GitHub Check Run as **in_progress**
- Sets up Node + pnpm
- Installs root dependencies
- Caches Playwright browsers
- Installs Playwright deps/browsers on cache miss
- Runs Playwright tests (with optional shard mode)
- Uploads Playwright HTML report — or a `blob-report/` when sharded
- Marks GitHub Check Run as **completed** — unless a downstream merge job owns completion

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
| `shard-index`          | –        | 1-based shard index. When set together with `shard-total`, the action runs Playwright in shard mode (see below). |
| `shard-total`          | –        | Total number of shards. Required alongside `shard-index` to enable shard mode. |
| `skip-check-completion` | –        | When `'true'`, the action does not mark the GitHub check as completed at the end of the job. Use this when a downstream merge job owns the final check status. |

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

---

## Sharded mode

Sharded mode partitions a single Playwright suite across N independent CI runners using Playwright's built-in [`--shard=<index>/<total>`](https://playwright.dev/docs/test-sharding) flag. Each shard emits a `blob-report/` artifact; a separate merge job stitches them back into one html + junit report.

### When to opt in

- Your Playwright config is **shard-aware** — any per-worker resource (a backend account pool, fixtures stored under `tests/.auth/<n>.json`, etc.) must use a global slot like `(shard-1) * workersPerShard + parallelIndex` so two shards can't alias the same resource. The midnight app does this in [`apps/midnight/tests/e2e/lib/auth/trade-account-pool.ts`](https://github.com/technance-foundation/technance-platform-frontend/blob/main/apps/midnight/tests/e2e/lib/auth/trade-account-pool.ts).
- Your `test-command` propagates extra args to Playwright. The action appends `-- --shard=<index>/<total>` after `inputs.test-command`, so a wrapper script (e.g. `node scripts/run-e2e-tests.js <app>`) must forward `process.argv.slice(3)` to `playwright test`. Otherwise `--shard` is silently dropped and every shard runs the full suite.
- Your test count is non-trivial (rough rule of thumb: > ~5 minutes per single-runner run). Below that the sharding overhead (4× setup, install, browser cache restore) dwarfs the savings.

If any of those isn't true, leave `shard-index`/`shard-total` unset and the action runs in its single-runner mode unchanged.

### Per-shard behavior

When `shard-index` AND `shard-total` are both set:

- `--shard=<index>/<total>` is appended to `test-command` (after `--`, so wrapper scripts that respect `--` get the flag).
- The Playwright config is expected to use the [`blob` reporter](https://playwright.dev/docs/test-reporters#blob-reporter) writing to `blob-report/`.
- Instead of uploading `playwright-report/`, the action uploads `blob-report/` as `<project>-playwright-blob-report-<shard-index>` so a merge job can pick the artifacts up by glob.
- If `skip-check-completion: "true"` is also set, the action skips `e2e-check@v1 state: completed` so the merge job can finalize the check exactly once (4 shards otherwise race PATCH `/check-runs` with conflicting outcomes).

### Caller workflow example

```yaml
jobs:
    test-e2e-sharded:
        runs-on: 8core-linux-x64-ubuntu-latest
        strategy:
            fail-fast: false
            matrix:
                shard: [1, 2, 3, 4]
        steps:
            - uses: actions/checkout@v6
            - id: app-token
              uses: tibdex/github-app-token@v2
              with:
                  app_id: ${{ vars.E2E_RELAY_GH_APP_ID }}
                  private_key: ${{ secrets.E2E_RELAY_GH_APP_PRIVATE_KEY }}

            - uses: technance-foundation/github-actions/e2e-test-runner@v1
              env:
                  PLAYWRIGHT_WORKERS: "2"
                  # Read by your shard-aware Playwright config so each
                  # runner can lease a disjoint slice of any per-worker
                  # backend resource (account pool, storage state, etc.).
                  PLAYWRIGHT_SHARD_INDEX: ${{ matrix.shard }}
                  PLAYWRIGHT_SHARD_TOTAL: ${{ strategy.job-total }}
              with:
                  token: ${{ steps.app-token.outputs.token }}
                  check-run-id: ${{ inputs.check_run_id }}
                  project: ${{ inputs.project }}
                  preview-url: ${{ inputs.url }}
                  npm-token: ${{ secrets.NPM_TOKEN }}
                  working-directory: ${{ inputs.working_directory }}
                  test-command: ${{ inputs.test_command }}
                  shard-index: ${{ matrix.shard }}
                  shard-total: ${{ strategy.job-total }}
                  skip-check-completion: "true"

    e2e-merge:
        runs-on: ubuntu-latest
        needs: [test-e2e-sharded]
        if: ${{ always() }}
        steps:
            - uses: actions/checkout@v6
            - id: app-token
              uses: tibdex/github-app-token@v2
              with:
                  app_id: ${{ vars.E2E_RELAY_GH_APP_ID }}
                  private_key: ${{ secrets.E2E_RELAY_GH_APP_PRIVATE_KEY }}

            - uses: technance-foundation/github-actions/setup@v1
              with:
                  node-version: "24"
                  pnpm-version: "10.32.1"
                  pnpm-cache: "read"
                  npm-token: ${{ secrets.NPM_TOKEN }}
                  install: "pnpm install --no-frozen-lockfile"
                  build: "false"

            - run: mkdir -p all-blob-reports
              shell: bash

            - uses: actions/download-artifact@v4
              with:
                  pattern: ${{ inputs.project }}-playwright-blob-report-*
                  path: all-blob-reports
                  merge-multiple: true

            # PLAYWRIGHT_JUNIT_OUTPUT_FILE points the junit reporter at
            # a real file; without it the XML goes to stdout and never
            # makes it into the uploaded artifact.
            - name: Merge Playwright reports
              shell: bash
              working-directory: ${{ inputs.working_directory }}
              env:
                  PLAYWRIGHT_JUNIT_OUTPUT_FILE: ${{ github.workspace }}/${{ inputs.working_directory }}/playwright-report/results.xml
              run: |
                  mkdir -p playwright-report
                  pnpm exec playwright merge-reports \
                      --reporter=list,html,junit \
                      "${{ github.workspace }}/all-blob-reports"

            - uses: actions/upload-artifact@v4
              if: ${{ always() }}
              with:
                  name: ${{ inputs.project }}-playwright-report
                  path: ${{ inputs.working_directory }}/playwright-report/
                  retention-days: 30
                  if-no-files-found: error

            - uses: technance-foundation/github-actions/e2e-check@v1
              if: ${{ always() }}
              with:
                  token: ${{ steps.app-token.outputs.token }}
                  check-run-id: ${{ inputs.check_run_id }}
                  state: completed
                  job-status: ${{ needs.test-e2e-sharded.result == 'success' && 'success' || 'failure' }}
                  project: ${{ inputs.project }}
                  preview-url: ${{ inputs.url }}
```

### Geometry rules of thumb

- `SHARDS × PLAYWRIGHT_WORKERS ≤ pool size` of any per-worker backend resource. Validate at config-load and fail fast — silent slot aliasing across shards is the worst kind of flake.
- 2 workers per shard is a safe default; raising it increases IP-level rate limit pressure on the preview environment from a single runner.
- Shards run in parallel matrix jobs; the wall-clock saving is roughly `1/SHARDS` minus per-shard setup overhead (~30–60s for browser cache restore + install).
