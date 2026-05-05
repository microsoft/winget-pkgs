# First-Time Contributor Checklist

Use this checklist before you open your first manifest PR to `microsoft/winget-pkgs`. It focuses on the repository rules that most often cause first-pass validation failures.

## Pre-submit checklist

1. Confirm there is not already an open PR for the same package version.
2. Keep the PR to **one package version only**. In this repository, that means one multi-file manifest set for a single `PackageIdentifier` and `PackageVersion`.
3. Keep the PR to **manifest files only**. If you also need to update spelling files, `README.md`, `doc/`, tooling, or any other non-manifest file, submit those changes in a **separate PR**.
4. Use a [supported installer type](Policies.md#installer-types) and make sure the installer can run unattended.
5. Use a multi-file manifest set. Singleton manifests are not allowed in the community repository.
6. Add schema headers to every manifest file, including the `# yaml-language-server: $schema=...` comment at the top of each file.
7. Use the latest manifest version supported by the repository. See [doc\manifest\schema\README.md](manifest/schema/README.md) for the current schema versions.
8. Use a stable, version-specific installer URL from an official source whenever possible.
9. Validate the manifest locally:

   ```powershell
   winget validate --manifest <path-to-manifest>
   ```

10. Test the install locally:

   ```powershell
   winget settings --enable LocalManifestFiles
   winget install --manifest <path-to-manifest>
   ```

11. If possible, test in Windows Sandbox with [`Tools\SandboxTest.ps1`](tools/SandboxTest.md).
12. If your PR is a routine manifest submission, you do **not** need a separate issue first. Open an issue when you are proposing a repo change, discussing a policy/spec question, or reporting a broader problem.
13. After you submit the PR, watch for validation labels and review [ValidationFailureGuide.md](ValidationFailureGuide.md) if the bot reports a problem.

## One PR change means one package version

The repository enforces **one PR change** strictly:

- **Allowed:** one package version represented by its full multi-file manifest set
- **Not allowed:** two versions of the same package in one PR
- **Not allowed:** a manifest submission plus unrelated manifest changes
- **Not allowed:** a manifest submission plus non-manifest files such as spelling updates, `README.md`, `doc/` content, or tooling changes

If you discover a documentation, spelling, or tooling fix while preparing a manifest, finish the manifest PR first and submit the repo/documentation change as a separate PR.

## First-time contributor decision tree

```mermaid
flowchart TD
    A[Start a new contribution] --> B{Is this PR for a routine manifest submission?}
    B -- No --> C[Open or link an issue first, then follow the repo workflow for code, tooling, or docs changes]
    B -- Yes --> D{Does an open PR already exist for this package version?}
    D -- Yes --> E[Do not open another PR for the same package version]
    D -- No --> F{Does the PR contain exactly one package version<br/>as one multi-file manifest set?}
    F -- No --> G[Split the work into separate PRs until each PR has one package version]
    F -- Yes --> H{Does the PR also change README, doc, spelling files,<br/>tooling, or other non-manifest files?}
    H -- Yes --> I[Move the non-manifest changes into a separate PR]
    H -- No --> J{Is the installer URL stable, version-specific,<br/>and reachable from validation infrastructure?}
    J -- No --> K[Pick a stable official release URL before submitting]
    J -- Yes --> L{Can the installer run unattended with the correct type,<br/>switches, and dependencies?}
    L -- No --> M[Fix the installer metadata or use a package that supports unattended install]
    L -- Yes --> N[Run winget validate --manifest <path>]
    N --> O{Validation succeeded?}
    O -- No --> P[Fix the reported manifest issues and validate again]
    O -- Yes --> Q[Run winget install --manifest <path><br/>and optionally Tools\\SandboxTest.ps1]
    Q --> R{Install test succeeded?}
    R -- No --> S[Fix the installer behavior, URL, or metadata and test again]
    R -- Yes --> T[Submit the PR and monitor labels/comments]
```
