# GitHub Actions

This repository contains reusable **composite GitHub Actions** maintained by the Technance.

---

## 📦 Available Actions

-   [Check](.github/actions/check/README.md)  
    Run project checks such as linting, formatting, and testing with Node.js + pnpm.

-   [Telegram Notifications](.github/actions/telegram-notifications/README.md)  
    Send GitHub event notifications to a Telegram chat.

-   [Release](.github/actions/release/README.md)  
    Standardized release pipeline with pnpm + Changesets. Captures version, creates a Release PR or publishes, and can open a PR back to `main`.

-   [Publish Any Commit](.github/actions/publish-any-commit/README.md)  
    Preview-publish packages from any commit/PR using `pnpm dlx pkg-pr-new publish` for one or more package paths.

