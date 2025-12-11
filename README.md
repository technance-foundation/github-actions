# GitHub Actions

This repository contains reusable **composite GitHub Actions** maintained by Technance.

---

## 📦 Available Actions

-   [Setup](setup/README.md)
    A reusable GitHub Action for setting up a `pnpm` repository for the subsequent steps.

-   [Telegram Notifications](telegram-notifications/README.md)
    Send GitHub event notifications to a Telegram chat.

-   [Release](release/README.md)
    Automated release pipeline using pnpm + Changesets. Runs on push to `main`, applies version bumps, removes consumed Changesets, commits the updated versions, and publishes packages.

-   [Publish Any Commit](publish-any-commit/README.md)
    Preview-publish packages from any commit/PR using `pnpm dlx pkg-pr-new publish` for one or more package paths.

-   [Load Env](load-env/README.md)  
    Loads environment variables from a `.env` file into the job environment.

-   [E2E Check Runner](e2e-check/README.md)
    Updates GitHub Check Runs for E2E tests (marks checks as `in_progress` and `completed`). Used to standardize status reporting for E2E workflows. This E2E action relies on the external **Relay** service [^1].

-   [E2E Test Runner](e2e-test-runner/README.md)
    Full Playwright E2E test pipeline: installs deps, caches browsers, runs tests, uploads reports, and updates GitHub Check Runs. Replaces long multi-step workflows with one action. This E2E action relies on the external **Relay** service [^1].

[^1]: These E2E actions integrate with the external **Relay** service, which waits for preview deployments to become ready and then triggers the E2E workflow. Relay implementation: https://github.com/technance-foundation/vercel-to-github-relay See [RELAY.md](https://github.com/technance-foundation/github-actions/blob/main/RELAY.md) for a full explanation.
