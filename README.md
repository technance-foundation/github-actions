# GitHub Actions

This repository contains reusable **composite GitHub Actions** maintained by Technance.

---

## 📦 Available Actions

-   [Setup](setup/README.md)
    A reusable GitHub Action for setting up a `pnpm` repository for the subsequent steps.

-   [Telegram Notifications](telegram-notifications/README.md)
    Send GitHub event notifications to a Telegram chat.

-   [Release](release/README.md)
    Standardized release pipeline with pnpm + Changesets. Captures version, creates a Release PR or publishes, and can open a PR back to `main`.

-   [Publish Any Commit](publish-any-commit/README.md)
    Preview-publish packages from any commit/PR using `pnpm dlx pkg-pr-new publish` for one or more package paths.

-   [Load Env](load-env/README.md)  
    Loads environment variables from a `.env` file into the job environment.

-   [E2E Check Runner](e2e-check/README.md)  
    Updates GitHub Check Runs for E2E tests (marks checks as `in_progress` and `completed`). Used to standardize status reporting for E2E workflows.

-   [E2E Test Runner](e2e-test-runner/README.md)  
    Full Playwright E2E test pipeline: installs deps, caches browsers, runs tests, uploads reports, and updates GitHub Check Runs. Replaces long multi-step workflows with one action.

> [!NOTE]
> Our Playwright E2E system also uses a small service called the **Relay**.  
> It waits for preview deployments to become ready and then triggers the E2E workflow at the right moment.  
> You can read more about it here: [RELAY.md](./RELAY.md)
