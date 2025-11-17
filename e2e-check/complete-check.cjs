/**
 * Completes a GitHub check run with debug logging.
 */
module.exports = async ({ github, context, core }) => {
    core.info("### E2E CHECK — complete-check starting");

    const checkRunId = Number(process.env.CHECK_RUN_ID);
    if (!checkRunId) throw new Error("CHECK_RUN_ID is missing");

    const owner = context.repo.owner;
    const repo = context.repo.repo;
    const runId = context.runId;
    const jobName = context.job;
    const runAttempt = Number(
        context.runAttempt ?? process.env.GITHUB_RUN_ATTEMPT ?? 1
    );

    const project = process.env.PROJECT ?? "";
    const previewUrl = process.env.PREVIEW_URL ?? "";
    const jobStatus = (process.env.JOB_STATUS || "").toLowerCase();
    const conclusion = jobStatus === "success" ? "success" : "failure";

    core.info(`Owner: ${owner}`);
    core.info(`Repo: ${repo}`);
    core.info(`Run ID: ${runId}`);
    core.info(`Job Name: ${jobName}`);
    core.info(`Run Attempt: ${runAttempt}`);
    core.info(`Project: ${project}`);
    core.info(`Preview URL: ${previewUrl}`);
    core.info(`Job Status: ${jobStatus}`);
    core.info(`Conclusion: ${conclusion}`);

    async function findJobUrl() {
        core.info("Fetching job list…");

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

        return (
            match?.html_url ??
            `https://github.com/${owner}/${repo}/actions/runs/${runId}`
        );
    }

    const details_url = await findJobUrl();

    const summary = [
        `**Workflow:** ${context.workflow}`,
        `**Job:** ${jobName}`,
        `**Run:** https://github.com/${owner}/${repo}/actions/runs/${runId}`,
        `**Project:** ${project}`,
        `**Preview URL:** ${previewUrl}`,
        `**Report Artifact:** ${project}-playwright-report`,
    ].join("\n");

    core.info("Updating check run to completed:");
    core.info(JSON.stringify({ conclusion, details_url }, null, 2));

    try {
        await github.rest.checks.update({
            owner,
            repo,
            check_run_id: checkRunId,
            status: "completed",
            completed_at: new Date().toISOString(),
            conclusion,
            details_url,
            output: { title: "E2E Tests", summary },
        });
        core.info("✔ Check updated to completed");
    } catch (err) {
        core.error("❌ Failed to update check run");
        core.error(err);
        throw err;
    }
};
