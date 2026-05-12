# E2E Test Bootstrap

Composite action that primes the pnpm store cache and the Playwright browser cache so a downstream matrix of sharded test jobs starts against **warm** caches instead of all racing a cold cache miss in parallel.

## When to use it

Use it as a prerequisite job for any workflow whose `e2e-test-runner` shards run in a `strategy.matrix`. Without a bootstrap, 4 parallel shards each independently:

- run a full `pnpm install` against a cold store cache, and
- run `playwright install --with-deps chromium` against a cold browser cache.

With this action in a job the shards `needs:`, the install + browser download happen once and the shards consume the populated caches via the same keys that `e2e-test-runner` already uses.

## Inputs

| Name                 | Required | Default    | Description                                                                                                                                            |
| -------------------- | -------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `npm-token`          | ✔️       | —          | NPM token for installing private dependencies                                                                                                          |
| `node-version`       | –        | `22`       | Node.js version                                                                                                                                        |
| `pnpm-version`       | –        | `10.15.0`  | pnpm version. Used only if `package.json` does not pin `packageManager`                                                                                |
| `playwright-version` | –        | `1.53.2`   | Discriminator in the browser-cache key. **Must match** the `playwright-version` passed to `e2e-test-runner` in the shards, or the shards cache-miss    |

## Cache keys

This action writes to two caches whose keys must remain in lockstep with the corresponding consumers in `e2e-test-runner`:

- **pnpm store** — `${{ runner.os }}-node-<node-version>-pnpm-store-<package.json hash>-<pnpm-lock.yaml hash>` (delegated to the shared `setup` action).
- **Playwright browsers** — `${{ runner.os }}-playwright-<playwright-version>-<pnpm-lock.yaml hash>`.

If either key formula changes here it must change in `e2e-test-runner` too, otherwise the shards will not hit the entries this job writes.

## Usage

```yaml
jobs:
    bootstrap:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v6
              with:
                  fetch-depth: 1

            - uses: technance-foundation/github-actions/e2e-bootstrap@v1
              with:
                  node-version: "24"
                  pnpm-version: "11.0.9"
                  npm-token: ${{ secrets.NPM_TOKEN }}

    test-e2e-sharded:
        needs: bootstrap
        runs-on: 8core-linux-x64-ubuntu-latest
        strategy:
            fail-fast: true
            matrix:
                shard: [1, 2, 3, 4]
        steps:
            - uses: actions/checkout@v6
            - uses: technance-foundation/github-actions/e2e-test-runner@v1
              with:
                  # ... shard inputs as usual. pnpm + browser caches
                  # are already populated, so the runner's own setup
                  # steps will restore them instead of installing.
                  ...
```

Pair with `strategy.fail-fast: true` at the matrix level so a failing shard cancels its siblings — bootstrap on its own only addresses duplicated *setup* time, not duplicated *test* time after a failure.

## Why not put this in `e2e-test-runner`?

`e2e-test-runner` runs **per shard**. The whole point of the bootstrap is that it must run **once**, before the matrix fans out — that's only expressible as a separate job. The two actions deliberately share the same cache-key formulas so they hand off cleanly.

## Caveats

- This action does not run `actions/checkout`. The caller must check out the repo first so the `pnpm-lock.yaml` exists for the cache key hash and for `pnpm install` to read.
- The pnpm cache is portable across runner sizes, so it's fine to bootstrap on `ubuntu-latest` and consume from `8core-linux-x64-ubuntu-latest` shards. Bootstrapping on a smaller runner saves CI minutes for the same effect.
- If `playwright-version` here differs from the value in `e2e-test-runner`, the bootstrap is silently wasted — the shards will produce a different cache key and reinstall. Keep them in lockstep.
