/**
 * CommonJS module loaded by actions/github-script via `require()`
 * Finds the job HTML URL and updates the check to "in_progress" with details_url set to the job page.
 * @param {{ github: any, context: any, core: any }} args
 */
module.exports = async ({ github, context, core }) => {
    const checkRunId = Number(process.env.CHECK_RUN_ID);
    if (!checkRunId) {
        throw new Error("CHECK_RUN_ID is missing");
    }

    const owner = context.repo.owner;
    const repo = context.repo.repo;
    const runId = context.runId;
    const jobName = context.job;
    const runAttempt = Number(
        context.runAttempt ?? process.env.GITHUB_RUN_ATTEMPT ?? 1
    );

    const delay = (ms) => new Promise((r) => setTimeout(r, ms));

    async function findJobUrl() {
        // the jobs list can race this step; poll a few times
        for (let i = 0; i < 5; i++) {
            const { data } = await github.rest.actions.listJobsForWorkflowRun({
                owner,
                repo,
                run_id: runId,
                filter: "latest",
            });

            const match =
                data.jobs.find(
                    (j) =>
                        j.name === jobName &&
                        (j.run_attempt ?? runAttempt) === runAttempt
                ) || data.jobs.find((j) => j.name === jobName);

            if (match?.html_url) {
                core.info(`Matched job "${jobName}" (id: ${match.id})`);
                return match.html_url;
            }

            await delay(1000);
        }

        // fallback to the run URL if we didn’t see the job yet
        return `https://github.com/${owner}/${repo}/actions/runs/${runId}`;
    }

    const details_url = await findJobUrl();

    await github.rest.checks.update({
        owner,
        repo,
        check_run_id: checkRunId,
        status: "in_progress",
        started_at: new Date().toISOString(),
        details_url,
    });
};
