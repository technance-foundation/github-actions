/**
 * CommonJS module loaded by actions/github-script via `require()`
 * Keeps details_url pointing at the job page and completes the check with a summary.
 * @param {{ github: any, context: any, core: any }} args
 */
module.exports = async ({ github, context }) => {
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

    const project = process.env.PROJECT ?? "";
    const previewUrl = process.env.PREVIEW_URL ?? "";
    const jobStatus = (process.env.JOB_STATUS || "").toLowerCase();
    const conclusion = jobStatus === "success" ? "success" : "failure";

    async function findJobUrl() {
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
};
