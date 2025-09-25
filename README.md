# GitHub Actions
test
This repository contains reusable **composite GitHub Actions** maintained by the Technance.

---

## 📦 Available Actions

-   [Setup](setup/README.md)
    A reusable GitHub Action for setting up a `pnpm` repository with for the subsequent steps

-   [Telegram Notifications](telegram-notifications/README.md)
    Send GitHub event notifications to a Telegram chat.

-   [Release](release/README.md)
    Standardized release pipeline with pnpm + Changesets. Captures version, creates a Release PR or publishes, and can open a PR back to `main`.

-   [Publish Any Commit](publish-any-commit/README.md)
    Preview-publish packages from any commit/PR using `pnpm dlx pkg-pr-new publish` for one or more package paths.

-   [Load Env](load-env/README.md)
    Loads environment variables from a .env file into the job environment

