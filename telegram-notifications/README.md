# Telegram Notifications GitHub Action

## Overview

This GitHub Action can be used in any repository to send notifications to a Telegram chat. The following pull request events will trigger a notification:

-   Pull request approved
-   Changes requested on a pull request
-   Comment added to a pull request review
-   Pull request opened (in draft or non-draft state)
-   Pull request marked as ready for review

## Example

Create a workflow in the `.github/workflows` directory of a repository to use this action:

```yaml
# .github/workflows/telegram-notifications.yml

name: Telegram notifications

on:
    pull_request:
        types: [opened, ready_for_review]
    pull_request_review:
        types: [submitted]

jobs:
    notify:
        runs-on: ubuntu-latest
        steps:
            - name: Telegram Notify
              uses: technance-foundation/github-actions/telegram-notifications@main
              with:
                  to: ${{ secrets.TELEGRAM_TO }}
                  token: ${{ secrets.TELEGRAM_TOKEN }}
```
