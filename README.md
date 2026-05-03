# 🪟 AgentTeamLand fork of `microsoft/winget-pkgs`

> Fork of the official Windows Package Manager community repository. Used by AgentTeamLand to host new `atl` manifests on a feature branch before opening upstream PRs to [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs).

This is **not** the upstream Microsoft repo. If you came here looking to submit a manifest for your own application, you want [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs) — its README + `doc/` directory carry the upstream contribution guide.

## Why this fork exists

winget unlike Homebrew or Scoop does NOT pull from arbitrary repos — packages must be in Microsoft's official catalog. The flow for getting a new `atl` version into the catalog:

1. Goreleaser auto-pushes new manifests to this fork's `master` branch (under `manifests/a/AgentTeamLand/atl/<version>/`)
2. We open an upstream PR from this fork to `microsoft/winget-pkgs:master`
3. Microsoft's validation pipeline runs + a Microsoft reviewer merges
4. `winget install AgentTeamLand.atl` works for end users

The fork is the publishing target in step 1 + the PR source in step 2. Steps 3-4 happen on Microsoft's side.

## 📚 Documentation

Full docs live at **[agentteamland.github.io/docs](https://agentteamland.github.io/docs/)**.

Most relevant sections:

- [winget upstream-PR process](https://agentteamland.github.io/docs/contributing/winget-process) — the manual-PR step we run from this fork (the only release step that's not auto)
- [Release pipeline](https://agentteamland.github.io/docs/contributing/release-pipeline) — full goreleaser flow including how this fork fits in
- [Install `atl` (winget section)](https://agentteamland.github.io/docs/guide/install#windows-winget) — the user-facing install command
- [`microsoft/winget-pkgs`](https://github.com/microsoft/winget-pkgs) — the upstream repo (their README + `doc/` is the canonical contribution guide for non-AgentTeamLand manifests)

## License

This fork inherits the upstream MIT license. Our own contributions (commits + branches under `agentteamland/winget-pkgs`) are also MIT.
