# Trident Operations Central — DEV build

This private repository is the shared source of truth for the Trident Operations Central DEV build, its SharePoint schema, Power Platform build notes, UAT evidence, and Codex/Claude Code handoff records.

## Scope and safety

- Environment: **DEV only**.
- `productionWritesEnabled` must remain `false`.
- Test data must be fictitious and clearly marked as DEV/UAT data.
- Never commit client secrets, tokens, `.env` files, tenant exports, or personal data.
- Production publication and production writes require a separate, explicit approval.

## Coordination

Read these files before starting work:

1. `outputs/AI_AGENT_STATUS.json` — current lease and handoff state.
2. The newest entry in `outputs/AI_COLLABORATION_LOG.md` — decisions and next actions.
3. `outputs/CLAUDE_CODE_START_HERE.md` and `outputs/CLAUDE_REVIEW_BRIEF.md` — role-specific instructions.

Agents claim a single lease in `AI_AGENT_STATUS.json`; only one agent may be ACTIVE at a time. Each agent records `partialActionState` before a work unit and records evidence afterward. GitHub Actions can validate and flag stale coordination, but cannot silently launch a paid Codex or Claude Code session. The human or an explicitly configured local runner must start the next session.

## Repository workflow

- Use a short-lived branch for changes and open a pull request for review.
- Do not edit the same active work unit concurrently.
- Keep live tenant actions and credentials outside Git history.
- Update the collaboration log and status file in the same change as the implementation notes.

## Key paths

- `config/lists/` — SharePoint list/schema definitions.
- `infra/` — DEV provisioning, probes, and operational scripts.
- `outputs/` — plans, UAT evidence, handoffs, and collaboration records.
- `.github/workflows/` — repository-only coordination checks.
