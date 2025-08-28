# GitHub Actions

This repository contains reusable **composite GitHub Actions** maintained by the Technance.

---

## 📦 Available Actions

-   [Check](.github/actions/check/README.md)  
    Run project checks such as linting, formatting, and testing with Node.js + pnpm.

-   [Telegram Notifications](.github/actions/telegram-notifications/README.md)  
    Send GitHub event notifications to a Telegram chat.

---

## 🚀 Usage

To use any action, reference it in your workflow like this:

```yaml
uses: technance-foundation/github-actions/.github/actions/<action-name>@main
```
