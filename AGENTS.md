# Agent instructions

Follow `.github/copilot-instructions.md` for repository-specific development guidance.

## Issues

Before filing a GitHub issue in this repository:

1. Search existing open and closed issues for duplicates.
2. Use the GitHub issue forms in `.github/ISSUE_TEMPLATE/`; do not file a blank issue unless a maintainer explicitly asks for one.
3. Use `package_issue.yml` for package behavior problems, `package_request.yml` for new package requests, `update_request.yml` for version update requests, and `feature_request.yml` for repository or process improvements.
4. Do not file WinGet client issues here; use `microsoft/winget-cli` for client behavior.
5. Keep issue bodies concise and evidence-based. Do not paste large speculative patches into issue bodies; open a pull request or link a branch when manifest changes are available.

## Pull requests

Before opening a pull request:

1. Review `CONTRIBUTING.md` and follow the repository PR template.
2. Modify exactly one package per PR.
3. Validate manifests locally when practical with `winget validate --manifest <path-to-version-folder>`.
4. Do not recursively scan or search the entire `manifests/` directory; work only in the specific package folder being modified.
5. Summarize validation performed, or explain why validation was not run.
