# Claude Code handoff addendum

Paste this after the main Claude Code instruction.

```text

Use outputs/AI_AGENT_STATUS.json as a coordination state machine.

Before starting:

1. Read AI_AGENT_STATUS.json and the newest AI_COLLABORATION_LOG.md entry.
2. Refuse to start if another agent is ACTIVE and its lease has not expired.
3. Generate or increment a unique handoff sequence number.
4. Set:
   - activeAgent: CLAUDE_CODE
   - status: CLAUDE_ACTIVE
   - leaseOwner: CLAUDE_CODE
   - leaseStartedAt: current time
   - lastHeartbeatAt: current time
   - leaseExpiresAt: current time plus 90 minutes
5. Re-read all files relevant to the current finding before editing.

During work:

- Refresh lastHeartbeatAt at least every 15 minutes.
- Do not modify the tenant.
- Record whether each action is NOT_STARTED, STARTED_UNVERIFIED, or COMPLETED_VERIFIED.
- Never treat a local patch as a deployed cloud change.

At approximately 98% of your own usage allowance, or before any provider limit is likely:

1. Stop starting new work.
2. Finish or clearly mark any in-progress action as STARTED_UNVERIFIED.
3. Append a HANDOFF READY entry to AI_COLLABORATION_LOG.md.
4. Update AI_AGENT_STATUS.json with:
   - activeAgent: NONE
   - status: HANDOFF_READY
   - leaseOwner: NONE
   - handoffSequence: incremented value
   - lastCompletedAction
   - nextAction
   - evidence
   - partialActionState
   - handoffCreatedAt
5. Warn the user exactly:
   Handoff is ready. Stop sending work to Claude Code now; switch to Codex.

Stale-session recovery:

- If status is ACTIVE but lastHeartbeatAt is older than leaseExpiresAt, mark the old lease STALE and create a new HANDOFF READY entry before taking over.
- Never silently overwrite an ACTIVE lease.

When taking over from Codex:

- Confirm status is HANDOFF_READY or BLOCKED.
- Confirm the handoff sequence is newer than the last sequence you processed.
- Read the evidence and partialActionState.
- Set your own ACTIVE lease before starting.

Final launch gate:

Before production is considered, both Claude Code and Codex must independently record:

FINAL_REVIEW: COMPLETE
P0_FINDINGS: 0
P1_FINDINGS: 0
PRODUCTION_APPROVAL: REQUIRED

Do not mark a finding VERIFIED without direct evidence.
```
