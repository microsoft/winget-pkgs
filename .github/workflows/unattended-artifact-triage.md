---
emoji: 🖼️
name: Unattended Artifact Triage
description: >-
  Routes safe screenshot metadata from a trusted unattended validation
  operation to moderators without downloading or interpreting artifacts.
on:
  workflow_dispatch:
    inputs:
      pull_request_number:
        description: Pull request number to triage
        required: true
        type: string
  roles: [admin, maintainer, write]
if: github.event_name == 'workflow_dispatch'
checkout: false
concurrency:
  group: "gh-aw-${{ github.workflow }}-${{ github.event.inputs.pull_request_number }}"
  cancel-in-progress: false
  queue: max
pre-agent-steps:
  - name: Collect safe unattended artifact metadata
    uses: actions/github-script@v9
    env:
      TARGET_PR: ${{ github.event.inputs.pull_request_number }}
    with:
      github-token: "${{ github.token }}"
      script: |
        const fs = require("fs");
        const outputPath = "/tmp/gh-aw/unattended-artifact.json";
        fs.mkdirSync("/tmp/gh-aw", { recursive: true });
        const owner = "microsoft", repo = "winget-pkgs";
        const appId = 1451866;
        const appSlug = "wingetvalidator-prod";
        const completionName = "10. Validation Completed";
        const installationName = "08. Installation Validation";
        const targetLabel = "Validation-Unattended-Failed";
        const maxTextBytes = 20000, maxJsonBytes = 16000, maxEntries = 100;
        const maxEntryBytes = 10 * 1024 * 1024;
        const maxScreenshotBytes = 5 * 1024 * 1024;
        const unsafeLabels = new Set([
          "URL-Validation-Error", "Validation-Defender-Error",
          "Validation-Virus-Scan-Error", "Validation-SmartScreen",
          "Validation-SmartScreen-Error", "Needs-SmartScreen-Investigation",
          "Validation-Hash-Flagged", "Validation-Hash-Verification-Failed",
          "Validation-Hash-Error", "Error-Hash-Mismatch",
          "Validation-Signature-Error", "Validation-Shell-Execute",
          "Binary-Validation-Error", "Validation-Executable-Error",
          "Internal-Error-Static-Scan", "Possible-Malware",
          "Blocking-Issue",
        ]);
        const output = {
          available: false, pullRequestNumber: null, headSha: null,
          operationBound: false, installation: null, screenshot: null,
        };
        const fail = () => { throw new Error("Evidence is unavailable."); };
        const boundedInteger = (value, maximum) =>
          Number.isSafeInteger(value) && value >= 0 && value <= maximum;
        const trusted = (check, headSha) =>
          check?.app?.id === appId &&
          check?.app?.slug === appSlug &&
          check?.head_sha === headSha;
        try {
          const pullRequestNumber = Number(process.env.TARGET_PR);
          if (!Number.isSafeInteger(pullRequestNumber) || pullRequestNumber <= 0) fail();
          const pull = (
            await github.rest.pulls.get({
              owner, repo, pull_number: pullRequestNumber,
            })
          ).data;
          const headSha = String(pull?.head?.sha ?? "");
          output.pullRequestNumber = pullRequestNumber; output.headSha = headSha || null;
          if (pull?.state !== "open" || !/^[0-9a-f]{40}$/.test(headSha)) fail();
          const labels = new Set(
            (pull.labels ?? []).map((label) => String(label?.name ?? "")),
          );
          if (
            !labels.has(targetLabel) ||
            [...labels].some((label) => unsafeLabels.has(label))
          ) fail();
          const checksResponse = await github.rest.checks.listForRef({
            owner, repo, ref: headSha, app_id: appId,
            filter: "all", per_page: 100, page: 1,
          });
          const checks = checksResponse.data?.check_runs ?? [];
          const totalChecks = Number(checksResponse.data?.total_count ?? 0);
          if (
            !Number.isSafeInteger(totalChecks) ||
            totalChecks > 100 ||
            checks.length !== totalChecks
          ) fail();
          const trustedChecks = checks.filter((check) => trusted(check, headSha));
          const completions = trustedChecks
            .filter(
              (check) =>
                check.name === completionName &&
                check.status === "completed",
            );
          if (
            completions.some(
              (check) =>
                !Number.isSafeInteger(check.id) ||
                !Number.isFinite(Date.parse(check.completed_at ?? "")),
            )
          ) fail();
          const completion = completions.sort(
            (left, right) =>
              Date.parse(right.completed_at) - Date.parse(left.completed_at) ||
              right.id - left.id,
          )[0];
          if (!completion) fail();
          const completionTime = Date.parse(completion.completed_at);
          if (
            trustedChecks.some(
              (check) =>
                ["queued", "in_progress"].includes(check.status) &&
                (
                  !Number.isSafeInteger(check.id) ||
                  check.id > completion.id ||
                  Date.parse(check.started_at ?? "") > completionTime
                ),
            )
          ) fail();
          const completionText = String(completion.output?.text ?? "");
          const jsonBlocks = [
            ...completionText.matchAll(/```json\s*([\s\S]*?)```/gi),
          ];
          if (
            completionText.length === 0 ||
            completionText.length > maxTextBytes ||
            jsonBlocks.length !== 1 ||
            jsonBlocks[0][1].length === 0 ||
            jsonBlocks[0][1].length > maxJsonBytes
          ) fail();
          let payload;
          try { payload = JSON.parse(jsonBlocks[0][1]); } catch { fail(); }
          const operationId = String(payload?.OperationId ?? "").trim();
          const artifacts = payload?.Artifacts;
          if (
            payload?.PullRequestNumber !== pullRequestNumber ||
            operationId.length === 0 ||
            operationId.length > 128 ||
            operationId !== String(completion.external_id ?? "").trim() ||
            !artifacts ||
            typeof artifacts !== "object" ||
            Array.isArray(artifacts) ||
            operationId !== String(artifacts.OperationId ?? "").trim()
          ) fail();
          const installationChecks = checks.filter(
            (check) =>
              trusted(check, headSha) &&
              check.name === installationName &&
              check.status === "completed" &&
              String(check.external_id ?? "").trim() === operationId,
          );
          if (installationChecks.length !== 1) fail();
          const outcome = String(
            installationChecks[0].conclusion ?? "",
          ).toLowerCase();
          if (!["failure", "timed_out", "action_required"].includes(outcome)) fail();
          let artifactUrl;
          try { artifactUrl = new URL(String(artifacts.ArtifactDownloadUrl ?? "")); }
          catch { fail(); }
          if (
            artifactUrl.protocol !== "https:" ||
            artifactUrl.host !== "cdn.winget.microsoft.com" ||
            artifactUrl.username ||
            artifactUrl.password
          ) fail();
          const installationLogs = artifacts.InstallationLogs;
          const validationResults = artifacts.ValidationResults;
          if (!Array.isArray(installationLogs) || !Array.isArray(validationResults)) fail();
          const entries = [...installationLogs, ...validationResults];
          if (
            entries.length > maxEntries ||
            artifacts.TotalFilesCount !== entries.length ||
            !boundedInteger(artifacts.TotalSizeBytes, maxEntryBytes) ||
            !entries.every((entry) =>
              boundedInteger(entry?.SizeBytes, maxEntryBytes),
            )
          ) fail();
          const screenshots = installationLogs.filter(
            (entry) =>
              typeof entry?.FileName === "string" &&
              /\.(?:png|jpe?g)$/i.test(entry.FileName),
          );
          if (screenshots.length !== 1) fail();
          const screenshot = screenshots[0];
          const fileName = screenshot.FileName;
          if (
            fileName.length === 0 ||
            fileName.length > 192 ||
            fileName !== fileName.split(/[\\/]/).pop() ||
            !/^[A-Za-z0-9._ -]+$/.test(fileName) ||
            fileName.includes("..") ||
            screenshot.SizeBytes <= 0 ||
            screenshot.SizeBytes > maxScreenshotBytes
          ) fail();
          const normalized = fileName.toLowerCase();
          const category = (expression) => {
            const values = new Set(
              [...normalized.matchAll(expression)].map((match) => match[1]),
            );
            return values.size === 1 ? [...values][0] : null;
          };
          output.operationBound = true;
          output.installation = {
            stage: installationName,
            outcome,
            timedOut: outcome === "timed_out",
          };
          output.screenshot = {
            exists: true,
            format: normalized.endsWith(".png") ? "PNG" : "JPEG",
            architecture: category(
              /(?:^|[^a-z0-9])(arm64|x64|x86)(?=[^a-z0-9]|$)/g,
            ),
            scope: category(/(?:^|[^a-z0-9])(machine|user)(?=[^a-z0-9]|$)/g),
            locale: category(
              /(?:^|[^a-z0-9])([a-z]{2}-[a-z]{2})(?=[^a-z0-9]|$)/g,
            ),
            sizeBytes: screenshot.SizeBytes,
          };
          output.available = true;
        } catch {
          output.reason = "Trusted evidence was unavailable or unsafe.";
        } finally {
          fs.writeFileSync(outputPath, JSON.stringify(output));
        }
  - name: Upload deterministic evidence
    uses: actions/upload-artifact@v7
    with:
      name: >-
        unattended-artifact-evidence-${{ github.run_id }}-${{ github.run_attempt }}
      path: /tmp/gh-aw/unattended-artifact.json
      if-no-files-found: error
      retention-days: 1
engine: copilot
permissions:
  checks: read
  pull-requests: read
  copilot-requests: write
network:
  allowed:
    - defaults
tools:
  bash: ["cat"]
safe-outputs:
  threat-detection: true
  report-failure-as-issue: false
  report-incomplete:
    create-issue: false
  noop:
    report-as-issue: false
  missing-tool: false
  missing-data: false
  jobs:
    post-unattended-artifact-comment:
      description: Post one fixed-target unattended artifact routing comment
      runs-on: ubuntu-slim
      if: >-
        needs.detection.result == 'success' &&
        needs.detection.outputs.detection_success == 'true'
      output: Unattended artifact routing comment posted
      inputs:
        body:
          description: Complete moderator-facing comment body
          required: true
          type: string
      permissions:
        issues: write
        pull-requests: read
      steps:
        - name: Download deterministic evidence
          uses: actions/download-artifact@v8
          with:
            name: >-
              unattended-artifact-evidence-${{ github.run_id }}-${{ github.run_attempt }}
            path: ${{ runner.temp }}/unattended-artifact-evidence
        - name: Validate and post fixed-target comment
          uses: actions/github-script@v9
          env:
            TARGET_PR: ${{ github.event.inputs.pull_request_number }}
            EVIDENCE_PATH: >-
              ${{ runner.temp }}/unattended-artifact-evidence/unattended-artifact.json
          with:
            github-token: "${{ github.token }}"
            script: |
              const fs = require("fs");
              const owner = "microsoft";
              const repo = "winget-pkgs";
              const footer =
                "###### Template: msftbot/moderatorAssist/unattendedArtifactTriage";
              const unsafeLabels = new Set([
                "URL-Validation-Error", "Validation-Defender-Error",
                "Validation-Virus-Scan-Error", "Validation-SmartScreen",
                "Validation-SmartScreen-Error", "Needs-SmartScreen-Investigation",
                "Validation-Hash-Flagged", "Validation-Hash-Verification-Failed",
                "Validation-Hash-Error", "Error-Hash-Mismatch",
                "Validation-Signature-Error", "Validation-Shell-Execute",
                "Binary-Validation-Error", "Validation-Executable-Error",
                "Internal-Error-Static-Scan", "Possible-Malware",
                "Blocking-Issue",
              ]);
              const stop = () => { throw new Error("Comment safety gate failed."); };
              try {
                const target = Number(process.env.TARGET_PR);
                if (!Number.isSafeInteger(target) || target <= 0) stop();
                const outputPath = process.env.GH_AW_AGENT_OUTPUT;
                if (!outputPath || fs.statSync(outputPath).size > 20000) stop();
                const output = JSON.parse(fs.readFileSync(outputPath, "utf8"));
                const items = (output.items ?? []).filter(
                  (item) => item.type === "post_unattended_artifact_comment",
                );
                if (items.length !== 1) stop();
                const body = items[0].body;
                if (typeof body !== "string" || body.length > 3500 || body.includes("@")) stop();
                const evidencePath = process.env.EVIDENCE_PATH;
                if (!evidencePath || fs.statSync(evidencePath).size > 4096) stop();
                const evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
                const installation = evidence.installation;
                const screenshot = evidence.screenshot;
                const outcomes = {
                  failure: "failure",
                  timed_out: "timed out",
                  action_required: "action_required",
                };
                if (
                  !evidence.available ||
                  evidence.pullRequestNumber !== target ||
                  !/^[0-9a-f]{40}$/.test(evidence.headSha ?? "") ||
                  evidence.operationBound !== true ||
                  installation?.stage !== "08. Installation Validation" ||
                  !Object.hasOwn(outcomes, installation?.outcome) ||
                  installation.timedOut !== (installation.outcome === "timed_out") ||
                  screenshot?.exists !== true ||
                  !["PNG", "JPEG"].includes(screenshot.format) ||
                  !Number.isSafeInteger(screenshot.sizeBytes) || screenshot.sizeBytes <= 0 ||
                  screenshot.sizeBytes > 5 * 1024 * 1024 ||
                  ![null, "arm64", "x64", "x86"].includes(screenshot.architecture) ||
                  ![null, "machine", "user"].includes(screenshot.scope) ||
                  !(screenshot.locale === null || /^[a-z]{2}-[a-z]{2}$/.test(screenshot.locale))
                ) stop();
                const categories = [
                  ["architecture", screenshot.architecture],
                  ["scope", screenshot.scope],
                  ["locale", screenshot.locale],
                ].filter(([, value]) => value !== null);
                const categoryText = categories.length
                  ? ` ${categories.map(([key, value]) => `${key}: ${value}`).join("; ")}.`
                  : "";
                const expectedBody = [
                  "[!WARNING]", "**Experimental moderator routing - no image analysis was performed.**", "",
                  `Trusted validation metadata shows that the current operation's **${installation.stage}** stage ended with **\`${outcomes[installation.outcome]}\`** and produced a screenshot artifact. This workflow did not access or interpret the screenshot, logs, archive, or installer.`,
                  "", `Screenshot metadata: **\`${screenshot.format}\`**, **\`${screenshot.sizeBytes}\` bytes**.${categoryText}`, "",
                  "**Moderator action:** inspect the screenshot through approved internal tooling. Treat it only as an investigation route, not as an automated diagnosis.",
                  "", "<details>", "<summary>Trusted routing evidence</summary>", "",
                  `Head SHA: \`${evidence.headSha}\``, "",
                  "Operation binding: current head, newest completed validation operation", "",
                  "Screenshot pixels interpreted: no", "", "</details>",
                ].join("\n");
                if (body !== expectedBody) stop();
                const evidenceHead = evidence.headSha;
                const { data: pull } = await github.rest.pulls.get({
                  owner, repo, pull_number: target,
                });
                const labels = new Set(
                  (pull.labels ?? []).map((label) => String(label.name ?? "")),
                );
                if (
                  pull.state !== "open" ||
                  pull.head?.sha !== evidenceHead ||
                  !labels.has("Validation-Unattended-Failed") ||
                  [...labels].some((label) => unsafeLabels.has(label))
                ) stop();
                const comments = await github.rest.issues.listComments({
                  owner, repo, issue_number: target, per_page: 100, page: 1,
                });
                if (String(comments.headers?.link ?? "").includes('rel="next"')) stop();
                if (
                  comments.data.some((comment) => {
                    const prior = String(comment.body ?? "");
                    return prior.includes(footer) && prior.includes(evidenceHead);
                  }) ||
                  comments.data.some(
                    (comment) =>
                      comment.user?.type === "User" &&
                      ["OWNER", "MEMBER", "COLLABORATOR"].includes(
                        String(comment.author_association ?? ""),
                      ),
                  )
                ) stop();
                if (process.env.GH_AW_SAFE_OUTPUTS_STAGED === "true") {
                  core.info("Fixed-target comment passed staged safety checks.");
                  return;
                }
                await github.rest.issues.createComment({
                  owner, repo, issue_number: target, body: `${body}\n\n${footer}`,
                });
              } catch {
                core.setFailed("Fixed-target comment was rejected.");
              }
---

# Unattended Artifact Triage (Experimental)

## Task

Run `cat "/tmp/gh-aw/unattended-artifact.json"`. Emit `noop` unless
`available` is exactly `true`. Otherwise call
`post_unattended_artifact_comment` once with only the complete `body` below.

## Evidence boundary

The collector binds the current PR head to the newest completed
`10. Validation Completed` from App `1451866`/`wingetvalidator-prod`, rejects a
newer pending trusted Check, and requires same-operation installation failure,
the active failure label, exact HTTPS CDN host, and one bounded PNG/JPEG
basename. It downloads nothing and excludes raw names, paths, URLs, timestamps,
Check text, logs, archives, and operation IDs.

The custom job requires that evidence, reconstructs the canonical body, and
re-fetches only the dispatch-input PR. It rejects stale/closed heads, unsafe
labels, human moderation, incomplete history, duplicates, mentions, or any body
that differs from evidence-derived text.

## Privacy and no-op policy

There is no approved OCR/redaction/vision path. Never retrieve or send
screenshot bytes, logs, OCR, archives, installers, URLs, filenames, paths,
hashes, credentials, or security details. Never interpret pixels, infer a cause,
or compensate for missing evidence; ambiguity is `noop`.

## Comment

Pass exactly this body without a code fence. Replace placeholders from evidence;
render `timed_out` as `timed out`; append optional categories only for non-null
values in architecture/scope/locale order.

```text
[!WARNING]
**Experimental moderator routing - no image analysis was performed.**

Trusted validation metadata shows that the current operation's **08. Installation Validation** stage ended with **`<outcome>`** and produced a screenshot artifact. This workflow did not access or interpret the screenshot, logs, archive, or installer.

Screenshot metadata: **`<format>`**, **`<sizeBytes>` bytes**.<optional: space then `architecture: value; scope: value; locale: value.`>

**Moderator action:** inspect the screenshot through approved internal tooling. Treat it only as an investigation route, not as an automated diagnosis.

<details>
<summary>Trusted routing evidence</summary>

Head SHA: `<headSha>`

Operation binding: current head, newest completed validation operation

Screenshot pixels interpreted: no

</details>
```

No mentions, links, or footer; the job appends its fixed footer. If uncertain,
emit `noop`; never create issue output.
