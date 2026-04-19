# AGENTS.md

## Agentic guardrails

These apply to human and automated contributors (including Cloud Agents).

1. **Work from the latest branch tip**  
   Before you start work on a branch: `git fetch origin`, check it out, then `git merge --ff-only origin/<branch>` (or `git pull --ff-only` when upstream is configured). If you cannot fast-forward, stop and align with the repository's normal merge or rebase workflow. Do not silently work on a stale checkout.

2. **Never force-push shared history**  
   Do not `git push --force`, `git push --force-with-lease`, or rewrite published branch history unless a maintainer explicitly authorizes that operation for the exact repository and branch.

3. **Focused changes and verification**  
   Keep pull requests scoped; run this repository's standard build, test, and lint commands (see README, Makefile, or CLAUDE.md) before requesting review.

---

## Cursor Cloud specific instructions

_(Project-specific commands belong in this file below the guardrails.)_

