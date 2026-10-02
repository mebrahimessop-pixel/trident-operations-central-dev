# Trident DEV — coordination probe setup

This document explains how the two-agent handoff loop works and the options for
automating the probe that detects a HANDOFF_READY state and triggers the next
agent.

## GitHub repository mode

The private GitHub repository is the durable source of truth for the coordination
files and build documentation. Commit `outputs/AI_AGENT_STATUS.json` and the
corresponding collaboration-log entry together so the next agent can reconstruct
the exact state. Use pull requests or short-lived branches for implementation
changes; never put credentials, tokens, live tenant exports, or personal data in
the repository. The GitHub Actions watchdog validates the status file every five
minutes and can flag an invalid or stale state, but it cannot launch a paid Codex
or Claude Code session by itself. Starting the next session still requires a local
runner, an explicitly configured API/CLI integration, or the user.

---

## How the loop works

Agents cannot measure their own token usage, so the loop does not rely on a
"98%" estimate. The primary handoff trigger is a work-unit cap. The watchdog
probe is the backup for ungraceful session endings.

```
Tool A (Codex or Claude Code)
  └─ claims ACTIVE lease in AI_AGENT_STATUS.json
  └─ for each work unit:
       PRE-WRITE: set partialActionState: "starting <task>" in status file
       do the work
       POST-WRITE: set partialActionState: null, increment workUnitsCompleted,
                   refresh lastHeartbeatAt
  └─ when workUnitsCompleted reaches maxWorkUnitsPerSession (5):
       writes HANDOFF_READY to AI_AGENT_STATUS.json
         (handoffTrigger: work_unit_cap)
       appends HANDOFF READY entry to AI_COLLABORATION_LOG.md
       sets sessionSummary
       warns user: "Handoff is ready. Stop sending work to Claude Code now; switch to Codex."

Normal path — graceful handoff:
  Probe reads AI_AGENT_STATUS.json → detects status = HANDOFF_READY
  → notifies user → user switches to Tool B

Backup path — ungraceful ending (session dies without writing HANDOFF_READY):
  Probe reads AI_AGENT_STATUS.json → detects status = CLAUDE_ACTIVE or CODEX_ACTIVE
    AND lastHeartbeatAt older than 90 minutes
  → probe force-writes HANDOFF_READY with handoffTrigger = watchdog_stale_lease
  → notifies user: "Stale session recovered"
  → user switches to Tool B, which reads partialActionState to find what was in-flight

Tool B (the other agent)
  └─ reads AI_AGENT_STATUS.json — confirms HANDOFF_READY
  └─ confirms handoffSequence is newer than last processed
  └─ reads partialActionState — if not null, verify the in-flight file before continuing
  └─ increments handoffSequence, sets own ACTIVE lease
  └─ sets partialActionState before starting each unit
  └─ resumes from nextAction
```

---

## Probe options

### Option 1 — Manual check (current default)

You check `AI_AGENT_STATUS.json` when convenient or when a tool warns you.

**Pros:** No setup required. Already working.  
**Cons:** You must remember to look. Handoff latency depends on you noticing.  
**Best for:** Low-frequency build sessions where you are present.

---

### Option 2 — Windows Task Scheduler + PowerShell toast notification

A scheduled PowerShell script runs every 5 minutes on your Windows machine,
reads `AI_AGENT_STATUS.json`, and fires a Windows toast notification when
`status = "HANDOFF_READY"`.

The interval is 5 minutes because the work-unit cap is 5 units — a session can
complete and hand off in as little as 20–30 minutes. A 15-minute probe could leave
the next agent idle for half a session.

**Setup:**

Save the script below as
`C:\Users\mebra\Documents\Codex\2026-09-21\we-are-resuming-an-existing-trident\infra\probe-handoff.ps1`

The script does two things: it notifies you when a handoff is ready, and it acts
as a watchdog that auto-writes HANDOFF_READY if an agent's lease has gone stale.
This means even if an agent session ends without writing its own handoff, the
probe recovers the loop automatically.

```powershell
$statusFile  = "C:\Users\mebra\Documents\Codex\2026-09-21\we-are-resuming-an-existing-trident\outputs\AI_AGENT_STATUS.json"
$leaseLimitMinutes = 90   # must match leaseDurationMinutes in the status file

$raw   = Get-Content $statusFile -Raw
$state = $raw | ConvertFrom-Json

function Show-Toast {
    param([string]$Title, [string]$Body)
    Add-Type -AssemblyName System.Windows.Forms
    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $balloon.Icon    = [System.Drawing.SystemIcons]::Information
    $balloon.Visible = $true
    $balloon.ShowBalloonTip(12000, $Title, $Body, [System.Windows.Forms.ToolTipIcon]::Info)
    Start-Sleep -Seconds 14
    $balloon.Dispose()
}

# --- Case 1: handoff already written cleanly ---
if ($state.status -eq 'HANDOFF_READY') {
    $nextAgent = if ($state.codex.status -eq 'READY_TO_START') { 'Codex' } else { 'Claude Code' }
    Show-Toast `
        "Trident DEV — handoff ready (seq $($state.handoffSequence))" `
        "Switch to $nextAgent. $($state.sessionSummary) Next: $($state.nextAction)"
    exit 0
}

# --- Case 2: watchdog — active lease has expired without a handoff ---
if ($state.status -in @('CLAUDE_ACTIVE','CODEX_ACTIVE')) {
    $lastBeat = [datetime]::Parse($state.lastHeartbeatAt)
    $ageMinutes = ([datetime]::UtcNow - $lastBeat.ToUniversalTime()).TotalMinutes

    if ($ageMinutes -gt $leaseLimitMinutes) {
        # Force-write HANDOFF_READY so the other agent can safely take over
        $state.activeAgent      = 'NONE'
        $state.status           = 'HANDOFF_READY'
        $state.leaseOwner       = 'NONE'
        $state.leaseExpiresAt   = $null
        $state.handoffTrigger   = 'watchdog_stale_lease'
        $state.handoffCreatedAt = [datetime]::Now.ToString('o')
        $state.sessionSummary   = "Session ended without a handoff — lease expired $([math]::Round($ageMinutes)) min ago. Check partialActionState before resuming."
        $state.updatedAt        = [datetime]::Now.ToString('o')

        $state | ConvertTo-Json -Depth 20 | Set-Content $statusFile -Encoding UTF8

        $nextAgent = if ($state.codex.status -eq 'READY_TO_START') { 'Codex' } else { 'Claude Code' }
        Show-Toast `
            "Trident DEV — stale session recovered" `
            "Lease expired $([math]::Round($ageMinutes)) min ago. HANDOFF_READY written. Switch to $nextAgent and check partialActionState."
        exit 0
    }
}

# --- Case 3: active and healthy — no action needed ---
exit 0
```

Register the scheduled task (run once in PowerShell as Administrator):

```powershell
$action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
              -Argument '-WindowStyle Hidden -File "C:\Users\mebra\Documents\Codex\2026-09-21\we-are-resuming-an-existing-trident\infra\probe-handoff.ps1"'
$trigger  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'TridentDevHandoffProbe' -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited -Force
```

**Important:** Do not add `-NonInteractive` to the `-Argument` string. That flag
suppresses the interactive desktop session which prevents the balloon tip from
appearing.

**Pros:** Fully local, no cloud dependency, runs silently.  
**Cons:** Only fires when your machine is on and unlocked. Requires one-time setup.  
**Best for:** Sustained build sessions at your desk.

---

### Option 3 — Power Automate scheduled flow + Teams or email alert

A Power Automate flow runs every 15–30 minutes, reads `AI_AGENT_STATUS.json`
from the DEV SharePoint document library, and sends a Teams message or email when
`status = "HANDOFF_READY"`.

**Prerequisites:**
- `AI_AGENT_STATUS.json` must be stored in a SharePoint document library
  (currently it is a local file — move or copy it to SharePoint if using this option).
- A Power Automate premium connector or SharePoint HTTP action to read the JSON.

**Flow outline:**

```
Trigger:    Recurrence — every 15 minutes

Action 1:   SharePoint — Get file content
            Site: ClinicalOperationsDEV
            File: /outputs/AI_AGENT_STATUS.json

Action 2:   Parse JSON (schema: AI_AGENT_STATUS.json structure)

Condition:  status == "HANDOFF_READY"

Yes branch:
  Action 3: Teams — Post message to [your channel]
            Body: "Trident DEV handoff ready.
                   Sequence: @{body('Parse_JSON')?['handoffSequence']}
                   Summary: @{body('Parse_JSON')?['sessionSummary']}
                   Next: @{body('Parse_JSON')?['nextAction']}
                   Switch to: @{if(equals(body('Parse_JSON')?['codex/status'], 'READY_TO_START'), 'Codex', 'Claude Code')}"
```

**Pros:** Works from any device, even when your machine is off.
Sends mobile push notification via Teams app.  
**Cons:** Requires SharePoint file sync. Uses Power Automate run quota.  
**Best for:** Sessions where you step away and want a phone ping.

---

### Option 4 — Webhook push at handoff (most reliable, most setup)

Each agent calls an HTTP endpoint at handoff time instead of relying on a polling
probe. The endpoint (e.g. a Power Automate HTTP trigger, an ntfy.sh topic, or a
custom script) immediately pushes a notification.

**Simplest implementation — ntfy.sh (no account required):**

In the agent startup instructions, add:

```
At handoff, after writing AI_AGENT_STATUS.json, call:
  POST https://ntfy.sh/trident-dev-handoff
  Body: "Handoff sequence <N>. <sessionSummary>. Next: <nextAction>."
  Headers: Title: Trident DEV handoff
```

Subscribe on your phone via the ntfy app (free, open source) using the topic
`trident-dev-handoff`.

**Note:** ntfy.sh topics are public by default. Use a long random topic name to
avoid accidental exposure, and never include secrets in the notification body.

**Pros:** Instant push, no polling lag, works on any device.  
**Cons:** Topic is semi-public unless self-hosted. Requires agent to make an
outbound HTTP call at handoff.  
**Best for:** Fast iteration where 15-minute polling lag is too slow.

---

## Recommended choice for current build phase

**Option 2 (Task Scheduler)** is the lowest-friction choice right now.
It runs locally, requires a one-time five-minute setup, fires a toast notification
every 15 minutes when a handoff is waiting, and has no cloud dependency beyond what
is already deployed.

When the build moves to sustained multi-session work (e.g. overnight runs), upgrade
to **Option 3** so you get mobile alerts even when away from your desk.

---

---

## Independent agent queues

The two agents do not share a single sequential queue. Each action in
`AI_AGENT_STATUS.json → actionStates` carries an `owner` field:

| Value | Meaning |
|-------|---------|
| `codex` | Only Codex can do this (tenant change, cloud deployment, live verification) |
| `claudeCode` | Only Claude Code can do this (local file correction, formula review, doc patch) |
| `either` | Either agent can take it — first available picks it up |

Each action also carries a `blockedOn` field (the action-state key that must reach
`COMPLETED_VERIFIED` first, or `null` if unblocked).

**Rule:** When an agent reaches its work-unit cap and hands off, the *other* agent
scans for items owned by itself (or `either`) that have no `blockedOn` dependency
and starts on those immediately — it does not wait for the first agent to resume.
This means both agents can be productive in parallel across different parts of the
backlog.

**Example:** While Codex is deploying the PIAction guard (P1-1, owner=codex),
Claude Code can simultaneously work on P2-1 Screen2 formula errors and P2-2
system-managed field locks (both owner=claudeCode, no blockers). Neither agent
needs to sit idle.

**Conflict avoidance:** Two agents must never hold ACTIVE leases simultaneously.
The queue isolation is logical, not a lock bypass — one agent is ACTIVE at a time,
but each agent picks its own lane when it takes over.

---

## Probe interaction with stale-lease recovery

If the probe fires and `status = HANDOFF_READY` but `handoffCreatedAt` is more
than 90 minutes old with no newer `lastHeartbeatAt`, the session that wrote the
handoff may itself have been stale. Before switching tools:

1. Check `lastHeartbeatAt` and `leaseExpiresAt`.
2. If the lease would have expired, read `partialActionState` carefully — the
   previous agent may have left a finding half-written.
3. The incoming agent must verify the partial state before continuing, not assume
   it was cleanly completed.

This check is already encoded in the stale-lease recovery rule in
`CLAUDE_CODE_START_HERE.md`.
