# Trident DEV — handoff probe and watchdog
# Run via Windows Task Scheduler every 5 minutes.
# Does two things:
#   1. Notifies you when a HANDOFF_READY state is waiting.
#   2. Auto-writes HANDOFF_READY if an active lease has expired without a clean handoff,
#      so the loop recovers even when a session ends ungracefully.
#
# Register once with (run as Administrator):
#   $action   = New-ScheduledTaskAction -Execute 'powershell.exe' `
#                 -Argument '-WindowStyle Hidden -File "C:\Users\mebra\Documents\Codex\2026-09-21\we-are-resuming-an-existing-trident\infra\probe-handoff.ps1"'
#   $trigger  = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -Once -At (Get-Date)
#   $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
#   Register-ScheduledTask -TaskName 'TridentDevHandoffProbe' -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited -Force
#
# NOTE: Do NOT add -NonInteractive to the Argument string — it suppresses the toast UI.

$statusFile       = "C:\Users\mebra\Documents\Codex\2026-09-21\we-are-resuming-an-existing-trident\outputs\AI_AGENT_STATUS.json"
$leaseLimitMinutes = 90   # must match leaseDurationMinutes in AI_AGENT_STATUS.json

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
    $nextAgent = if ($state.activeAgent -eq 'CODEX' -or $state.codex.status -in @('HANDOFF_READY','READY_TO_START')) { 'Claude Code' } elseif ($state.activeAgent -eq 'CLAUDE_CODE' -or $state.claudeCode.status -in @('HANDOFF_READY','READY_TO_START')) { 'Codex' } else { 'the next available agent' }
    Show-Toast `
        "Trident DEV — handoff ready (seq $($state.handoffSequence))" `
        "Switch to $nextAgent. $($state.sessionSummary) Next: $($state.nextAction)"
    exit 0
}

# --- Case 2: watchdog — active lease has expired without a clean handoff ---
if ($state.status -in @('CLAUDE_ACTIVE', 'CODEX_ACTIVE')) {
    $lastBeat   = [datetime]::Parse($state.lastHeartbeatAt)
    $ageMinutes = ([datetime]::UtcNow - $lastBeat.ToUniversalTime()).TotalMinutes

    if ($ageMinutes -gt $leaseLimitMinutes) {
        # Force-write HANDOFF_READY so the next agent can safely take over
        $state.activeAgent      = 'NONE'
        $state.status           = 'HANDOFF_READY'
        $state.leaseOwner       = 'NONE'
        $state.leaseExpiresAt   = $null
        $state.handoffTrigger   = 'watchdog_stale_lease'
        $state.handoffCreatedAt = [datetime]::Now.ToString('o')
        $state.sessionSummary   = "Session ended without a handoff — lease expired $([math]::Round($ageMinutes)) min ago. Check partialActionState before resuming."
        $state.updatedAt        = [datetime]::Now.ToString('o')

        $state | ConvertTo-Json -Depth 20 | Set-Content $statusFile -Encoding UTF8

        $nextAgent = if ($state.activeAgent -eq 'CODEX' -or $state.codex.status -in @('HANDOFF_READY','READY_TO_START')) { 'Claude Code' } elseif ($state.activeAgent -eq 'CLAUDE_CODE' -or $state.claudeCode.status -in @('HANDOFF_READY','READY_TO_START')) { 'Codex' } else { 'the next available agent' }
        Show-Toast `
            "Trident DEV — stale session recovered (seq $($state.handoffSequence))" `
            "Lease expired $([math]::Round($ageMinutes)) min ago. HANDOFF_READY written. Switch to $nextAgent and check partialActionState."
        exit 0
    }
}

# --- Case 3: active session is healthy — no action needed ---
exit 0
