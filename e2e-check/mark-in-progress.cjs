/**
 * CommonJS module loaded by actions/github-script via `require()`
 * Finds the job HTML URL and updates the check to "in_progress".
 */
module.exports = async ({ github, context, core }) => {
    core.info("### E2E CHECK — mark-in-progress starting");

    const checkRunId = Number(process.env.CHECK_RUN_ID);
    if (!checkRunId) throw new Error("CHECK_RUN_ID is missing");

    const owner = context.repo.owner;
    const repo = context.repo.repo;
    const runId = context.runId;
    const jobName = context.job;
    const runAttempt = Number(
        context.runAttempt ?? process.env.GITHUB_RUN_ATTEMPT ?? 1
    );

    core.info(`Owner: ${owner}`);
    core.info(`Repo: ${repo}`);
    core.info(`Run ID: ${runId}`);
    core.info(`Job Name: ${jobName}`);
    core.info(`Run Attempt: ${runAttempt}`);

    const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

    async function findJobUrl() {
        for (let i = 0; i < 5; i++) {
            core.info(`Polling GitHub jobs (attempt ${i + 1})…`);

            const { data } = await github.rest.actions.listJobsForWorkflowRun({
                owner,
                repo,
                run_id: runId,
                filter: "latest",
            });

            core.info("Jobs returned:");
            core.info(
                JSON.stringify(
                    data.jobs.map((j) => ({
                        id: j.id,
                        name: j.name,
                        attempt: j.run_attempt,
                        url: j.html_url,
                    })),
                    null,
                    2
                )
            );

            const match =
                data.jobs.find(
                    (j) =>
                        j.name === jobName &&
                        (j.run_attempt ?? runAttempt) === runAttempt
                ) || data.jobs.find((j) => j.name === jobName);

            if (match && match.html_url) {
                core.info(`Matched job ${match.id} (${match.name})`);
                return match.html_url;
            }

            await delay(1000);
        }

        core.info("⚠️ Job not found, falling back to run URL");
        return `https://github.com/${owner}/${repo}/actions/runs/${runId}`;
    }

    const details_url = await findJobUrl();

    core.info(`Updating check ${checkRunId} → in_progress`);
    core.info(`details_url = ${details_url}`);

    try {
        await github.rest.checks.update({
            owner,
            repo,
            check_run_id: checkRunId,
            status: "in_progress",
            started_at: new Date().toISOString(),
            details_url,
        });
        core.info("✔ Check updated to in_progress");
    } catch (err) {
        core.error("❌ Failed to update check run");
        core.error(err);
        throw err;
    }
};
