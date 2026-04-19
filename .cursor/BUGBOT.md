# Bugbot review guidance

## Global expectations

- **Latest head:** Assume the PR branch reflects the latest pushed commits; if review context looks stale relative to GitHub, refresh before commenting.
- **No force-push:** Do not suggest force-pushing shared branches as the default fix.
- **Prioritize behavior:** Flag correctness, security, compatibility, and API or contract risks ahead of style-only feedback unless style obscures a defect.
- **Trust CI:** When CI already enforces formatting or static analysis, avoid duplicating that noise in comments unless the check is wrong or misleading.


