# E2E Relay

A simple explanation of what it is and why it's part of our E2E pipeline.

Most of our E2E setup works through GitHub Actions, but there’s one thing GitHub simply cannot do on its own: it doesn’t know when your preview deployment is actually ready. That’s where the Relay comes in.

The Relay is a small service that listens to GitHub events, watches for preview deployments to go live, and then starts the E2E test workflow at the right moment. It keeps the whole system connected so that E2E checks behave like a first-class part of your PRs.

---

## Relay Implementation

The Relay itself is implemented as a lightweight Node.js service that runs as a GitHub App.

🔗 Source code:  
https://github.com/technance-foundation/vercel-to-github-relay

This is the service responsible for:

-   Listening to GitHub App webhooks
-   Detecting preview deployments
-   Triggering `workflow_dispatch` for E2E runs
-   Managing check runs

---

## Why the Relay exists

When someone opens a pull request, we want to show an “E2E Tests” check immediately. But tests can’t run until:

1. a preview environment exists,
2. it has finished building, and
3. it’s reachable at a final URL.

GitHub doesn’t provide a native way to coordinate all of that. It can run workflows, yes, but it doesn’t know anything about your preview system. It can’t wait for it, and it can’t start a workflow only when the environment is actually ready.

So the Relay acts as that missing middle layer.
It watches everything, waits until the preview is live, and then triggers the test workflow with the exact URL and the check run ID.

---

## How it works at a high level

Here’s the lifecycle of a typical PR:

1. A pull request is opened.
   The Relay receives this event through a GitHub App installation webhook.

2. It immediately creates a GitHub Check Run for the project.
   This is why you see “E2E Tests — <project>” appear before any workflow runs.

3. It waits for the preview deployment to finish.
   The Relay keeps checking the preview provider until the deployment is actually reachable.

4. Once the preview is ready, it starts the GitHub workflow.
   It triggers the E2E workflow using `workflow_dispatch`, passing:

    - the preview URL
    - the project name
    - the check run ID it created earlier

5. The workflow runs using our `e2e-test-runner` action.
   That action updates the check run status from “in progress” → “completed”.

The Relay ensures that tests only run when the environment is truly ready, and GitHub never needs to know the details.

---

## What the Relay needs

It’s a very lightweight service. It only needs a few things:

-   GitHub App credentials
    (App ID, Private Key, Installation ID)
-   A way to check deployment status on your preview host
-   Any environment capable of running a small web service

That’s it. There’s no heavy infrastructure behind it.

---

## What the workflow needs for the Relay to trigger it

Your E2E workflow must support manual triggering with the following inputs:

```yaml
on:
    workflow_dispatch:
        inputs:
            url:
                required: true
            project:
                required: true
            check_run_id:
                required: true
```

The Relay fills these in when it triggers the workflow.
The `e2e-test-runner` uses them to run tests and update the check.

---

## If the Relay isn’t running

You’ll notice it immediately:

-   “E2E Tests” checks get created, but never move past “Queued”.
-   The preview URL is missing.
-   No workflow triggers.
-   No reports show up.

When this happens, the E2E system hasn’t broken — it’s simply waiting for the Relay to do its job.

---

## In short

-   The Relay connects your preview deployments to your E2E test workflow.
-   GitHub handles the workflow execution.
-   The test runner handles the actual testing.
-   The Relay ties it together so that E2E checks behave like part of the PR experience instead of an afterthought.
