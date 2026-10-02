# Trident Operations Central DEV

This repository is a shared DEV-only engineering workspace for Claude Code and Codex.

Before acting, read:

- `outputs/AI_AGENT_STATUS.json`
- `outputs/PLATFORM_STACK_INVENTORY.md`
- `outputs/AI_COLLABORATION_LOG.md`
- `outputs/CLAUDE_REVIEW_BRIEF.md`
- `outputs/DEV_UAT_RESULTS_2026-09-30.md`
- `outputs/DEV_MVP_LAUNCH_PLAN.md`
- `outputs/DEV_UAT_PLAN_2026-09-29.md`
- `config/lists/achieve-ram-pilot.json`
- `infra/provision-dev-lists.ps1`

Claude Code owns retrospective review and correction of local implementation files, documentation, tests, formulas, and configuration assets. Codex owns prospective feature work, tenant changes, cloud deployment, and end-to-end verification. Do not log into or modify Azure, SharePoint, Power Apps, or Power Automate from Claude Code.

Never request, expose, store, or transmit passwords, client secrets, access tokens, or personal data. Work only with fictitious DEV UAT data. Do not touch production. Use unified diffs for local changes. Record every review and finding in `outputs/AI_COLLABORATION_LOG.md`. A recommendation is not a deployment, and a finding is not verified without direct evidence.

At approximately 98% of your own usage allowance, stop starting new work, append a complete `HANDOFF READY` entry to `outputs/AI_COLLABORATION_LOG.md`, and warn the user to stop sending work to Claude Code and switch to Codex. Do not wait for a hard limit or leave a partial action undocumented.

Before starting, confirm the other agent is not ACTIVE in `outputs/AI_AGENT_STATUS.json`, set your own status to `CLAUDE_ACTIVE`, and re-read the relevant project files. Check your own usage at least every five hours. The inactive agent may poll the status file hourly for `HANDOFF_READY` or `BLOCKED`, then set its own ACTIVE status before taking over.
