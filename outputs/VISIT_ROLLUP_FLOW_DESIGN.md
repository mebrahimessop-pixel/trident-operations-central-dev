# VisitWorkflow roll-up flow design

Environment: DEV only  
Author: Claude Code  
Date: 2026-10-01  
Status: PROPOSED — awaiting Codex implementation and verification

This document specifies the five Power Automate roll-up flows that keep the parent
`VisitWorkflow` record synchronised with its five child lists. Each flow appends a
`WorkflowAudit` row for every state change it makes.

---

## VisitWorkflow consolidated Status state machine

```
Scheduled
  → Arrived             (VisitAdmin: AttendanceStatus = Arrived)
  → Visit In Progress   (VisitClinicalStatus: Status = In Progress)
  → Visit Complete      (VisitClinicalStatus: Status = Complete)
  → Ready for QC        (VisitClinicalStatus: ReadyForQC = true AND Status = Complete)
  → QC In Progress      (QCFinding: any finding Status = In Progress or Open)
  → QC Returned         (QCFinding: any finding Status = Returned)
  → QC Passed           (QCFinding: all findings Status = Closed or Verified, or none exist)
  → Ready for EDC       (EDCStatus: Status = Ready)
  → EDC In Progress     (EDCStatus: Status = In Progress)
  → EDC Complete        (EDCStatus: Status = Complete — only after EDC guard passes)
  → PI Action           (PIAction: any action Status = Pending or In Progress)
  → Closed              (user action, only when CloseEligible = true)
```

Forward-only rule: a roll-up flow must never move the consolidated Status backwards
(e.g. from `QC Passed` back to `QC In Progress`) unless the child list evidence
genuinely requires it (e.g. a QC finding is reopened after passing). Each flow
must read the current parent Status before writing a new one.

---

## CloseEligible composite check

`CloseEligible = true` when ALL of the following are true for the VisitKey:

| Condition | Source |
|---|---|
| VisitClinicalStatus.Status = "Complete" | VisitClinicalStatus list |
| All QCFindings have Status = "Closed" or "Verified" (or no findings exist) | QCFinding list |
| EDCStatus.Status = "Complete" | EDCStatus list |
| All PIActions have Status = "Complete" or "Not Required" (or no actions exist) | PIAction list |

Every roll-up flow recalculates and writes `CloseEligible` to the parent after its
own update. It does not set Status to "Closed" — that requires an explicit user
action in the app when `CloseEligible = true`.

---

## OpenQueryCount calculation

`OpenQueryCount` = count of QCFindings for the VisitKey where Status is
`Open`, `Returned`, or `In Progress` (i.e. not yet Resolved, Verified, or Closed).

This is written by Flow 3 (QCFinding roll-up) and also read by the EDC guard.

---

## Common pattern for all five flows

Each flow follows this structure:

```
1. Trigger:  SharePoint — When an item is created or modified
             List: <child list>

2. Guard:    If VisitKey is blank → terminate (no parent to update)
             [PIAction only — VisitKey is optional]

3. Lookup:   Get items from VisitWorkflow where VisitKey = trigger.VisitKey
             Take first result; if empty → terminate and log warning

4. Cross-list gets (as needed for counts and CloseEligible):
             Get items from QCFinding where VisitKey = trigger.VisitKey
             Get items from EDCStatus where VisitKey = trigger.VisitKey
             Get items from PIAction where VisitKey = trigger.VisitKey
             Get items from VisitClinicalStatus where VisitKey = trigger.VisitKey

5. Calculate derived fields (see each flow below)

6. Update VisitWorkflow item (only fields this flow owns — do not blank others)

7. Create WorkflowAudit row (see WorkflowAudit spec below)
```

---

## Flow 1 — VisitAdmin roll-up

**Flow name:** `Trident DEV - VisitAdmin roll-up`  
**Trigger list:** VisitAdmin

**Fields this flow updates on VisitWorkflow:**

| VisitWorkflow field | Source / Logic |
|---|---|
| `PlannedDate` | `trigger.PlannedDate` |
| `ReceptionOwner` | `trigger.ReceptionOwner` |
| `ActualVisitDate` | `trigger.ArrivalAt` date part (set only when ArrivalAt is not blank and parent ActualVisitDate is blank) |
| `Status` | See transitions below |

**Status transitions:**

```
IF trigger.AttendanceStatus = "Arrived"
   AND parent.Status = "Scheduled"
THEN parent.Status = "Arrived"

IF trigger.AttendanceStatus = "No Show" or "Cancelled"
   AND parent.Status IN ("Scheduled", "Arrived")
THEN parent.Status = "Scheduled"   // revert; no further action
```

**WorkflowAudit row:** EventType = "Status Change", FieldName = "Status",
OldValue = previous parent Status, NewValue = new parent Status.

---

## Flow 2 — VisitClinicalStatus roll-up

**Flow name:** `Trident DEV - VisitClinicalStatus roll-up`  
**Trigger list:** VisitClinicalStatus

**Fields this flow updates on VisitWorkflow:**

| VisitWorkflow field | Source / Logic |
|---|---|
| `VisitOwner` | `trigger.VisitOwner` |
| `ActualVisitDate` | `trigger.StartedAt` date part (set only when blank on parent) |
| `Status` | See transitions below |
| `CloseEligible` | Recalculated composite check |

**Status transitions:**

```
IF trigger.Status = "In Progress"
   AND parent.Status = "Arrived"
THEN parent.Status = "Visit In Progress"

IF trigger.Status = "Complete"
   AND parent.Status = "Visit In Progress"
THEN parent.Status = "Visit Complete"

IF trigger.Status = "Complete"
   AND trigger.ReadyForQC = true
   AND parent.Status IN ("Visit In Progress", "Visit Complete")
THEN parent.Status = "Ready for QC"
     parent.QCReadyAt = utcNow()  [only if currently blank]
```

**WorkflowAudit row:** EventType = "Status Change".

---

## Flow 3 — QCFinding roll-up

**Flow name:** `Trident DEV - QCFinding roll-up`  
**Trigger list:** QCFinding

**Cross-list gets required:** all QCFindings for this VisitKey.

**Derived values:**

```
openFindings  = QCFindings where Status IN ("Open", "Returned", "In Progress")
closedFindings = QCFindings where Status IN ("Resolved", "Verified", "Closed")
allClosed     = (openFindings.count == 0 AND closedFindings.count > 0)
               OR total QCFindings.count == 0

qcStatus:
  IF any finding Status = "Returned" → QCStatus = "Returned"
  ELSE IF openFindings.count > 0     → QCStatus = "In Progress"
  ELSE IF allClosed                  → QCStatus = "Passed"
  ELSE                               → QCStatus = "Not Ready"
```

**Fields this flow updates on VisitWorkflow:**

| VisitWorkflow field | Value |
|---|---|
| `OpenQueryCount` | `openFindings.count` |
| `QCStatus` | Derived above |
| `QCStartedAt` | `utcNow()` if transitioning to In Progress and currently blank |
| `QCPassedAt` | `utcNow()` if transitioning to Passed and currently blank |
| `Status` | See transitions below |
| `CloseEligible` | Recalculated composite check |

**Status transitions:**

```
IF qcStatus = "Returned"
   AND parent.Status IN ("QC In Progress", "Ready for QC")
THEN parent.Status = "QC Returned"

IF qcStatus = "In Progress"
   AND parent.Status IN ("Ready for QC", "QC Returned")
THEN parent.Status = "QC In Progress"

IF qcStatus = "Passed"
   AND parent.Status IN ("QC In Progress", "QC Returned", "Ready for QC")
THEN parent.Status = "QC Passed"
     parent.QCPassedAt = utcNow()
```

Do not advance to "Ready for EDC" here — that is driven by EDCStatus.

**WorkflowAudit rows:** one row per field changed (Status, QCStatus, OpenQueryCount).

---

## Flow 4 — EDCStatus roll-up

**Flow name:** `Trident DEV - EDCStatus roll-up`  
**Trigger list:** EDCStatus

**Note:** This flow runs after the EDC completion guard. By the time it sees
`Status = "Complete"` the guard has already confirmed the record is valid.

**Fields this flow updates on VisitWorkflow:**

| VisitWorkflow field | Value |
|---|---|
| `EDCStatus` (choice field) | Mirror of trigger.Status |
| `EDCReadyAt` | `utcNow()` if trigger.Status = "Ready" and currently blank |
| `EDCStartedAt` | `utcNow()` if trigger.Status = "In Progress" and currently blank |
| `EDCCompletedAt` | `utcNow()` if trigger.Status = "Complete" and currently blank |
| `Status` | See transitions below |
| `CloseEligible` | Recalculated composite check |

**Status transitions:**

```
IF trigger.Status = "Ready"
   AND parent.Status = "QC Passed"
THEN parent.Status = "Ready for EDC"

IF trigger.Status = "In Progress"
   AND parent.Status = "Ready for EDC"
THEN parent.Status = "EDC In Progress"

IF trigger.Status = "Complete"
   AND parent.Status = "EDC In Progress"
THEN parent.Status = "EDC Complete"
```

**WorkflowAudit rows:** one row for Status change, one for EDCStatus change.

---

## Flow 5 — PIAction roll-up

**Flow name:** `Trident DEV - PIAction roll-up`  
**Trigger list:** PIAction

**Guard (first step):** if `trigger.VisitKey` is blank, terminate immediately. Study-level
PIActions do not update any VisitWorkflow record.

**Cross-list gets required:** all PIActions for this VisitKey.

**Derived values:**

```
actionRequired = any PIAction where Status NOT IN ("Not Required", "Entered in Error")
pendingActions = PIActions where Status IN ("Pending", "In Progress")
allDone        = pendingActions.count == 0

piActionStatus:
  IF pendingActions.count > 0 → "Pending"
  ELSE IF actionRequired      → "Complete"
  ELSE                        → "Not Required"
```

**Fields this flow updates on VisitWorkflow:**

| VisitWorkflow field | Value |
|---|---|
| `PIActionRequired` | `actionRequired` (Yes/No) |
| `PIActionStatus` | Derived above |
| `Status` | See transitions below |
| `CloseEligible` | Recalculated composite check |

**Status transitions:**

```
IF pendingActions.count > 0
   AND parent.Status IN ("EDC Complete", "PI Action")
THEN parent.Status = "PI Action"

IF piActionStatus = "Complete"
   AND parent.Status = "PI Action"
THEN
  // Do not auto-close. Set CloseEligible = true if composite check passes.
  // User performs the Close action in the app.
```

**WorkflowAudit rows:** one row for PIActionRequired change, one for PIActionStatus
change, one for Status change if applicable.

---

## WorkflowAudit row specification

Every roll-up flow creates a new WorkflowAudit item for each field it changes.
Fields to populate:

| WorkflowAudit field | Value |
|---|---|
| `AuditEventID` | `concat('AUD-', triggerWorkflow().run.name, '-', field_name)` or a guid expression |
| `EntityType` | `"VisitWorkflow"` |
| `EntityKey` | `trigger.VisitKey` |
| `StudyID` | `trigger.StudyID` (pass the lookup value) |
| `ParticipantID` | `trigger.ParticipantID` |
| `EventType` | `"Status Change"` (or `"Created"` for new child records) |
| `FieldName` | Name of the VisitWorkflow field being updated |
| `OldValue` | Previous value read from the parent record before update |
| `NewValue` | The value being written |
| `ChangedBy` | `trigger._createdby` or `trigger._modifiedby` (the user who saved the child record) |
| `ChangedAt` | `utcNow()` |
| `Reason` | Leave blank (automation-initiated; not a correction) |
| `SourceApp` | `"Power Automate"` |
| `CorrelationID` | `triggerWorkflow().run.name` (links all audit rows from the same flow run) |

---

## Race condition note

Multiple roll-up flows can update the same VisitWorkflow record if a child list
item is saved while another flow is already running. At DEV/pilot scale this is
unlikely to cause data loss, but each flow should:

1. Read the current parent record immediately before writing (not at trigger time).
2. Only update the fields it owns — never blank fields owned by other flows.
3. Use the SharePoint "Update item" action (not "Create item") to avoid duplicating
   the parent record.

For production scale, the five flows should be consolidated into a single
"Trident - VisitWorkflow state engine" flow that queues updates through a single
SharePoint item lock or Dataverse transaction.

---

## Suggested Codex build order

1. Flow 4 (EDCStatus roll-up) — depends only on EDCStatus, simplest lookup chain,
   builds directly on the already-tested EDC guard pattern.
2. Flow 2 (VisitClinicalStatus roll-up) — single child, no cross-list counts.
3. Flow 1 (VisitAdmin roll-up) — single child, simple attendance-status mapping.
4. Flow 3 (QCFinding roll-up) — requires multi-item count query; most complex logic.
5. Flow 5 (PIAction roll-up) — requires VisitKey null guard; similar count pattern
   to Flow 3.

After each flow is deployed and tested independently, run the full UAT matrix
end-to-end to confirm consolidated Status advances correctly from Scheduled to
CloseEligible across all five child lists.

---

## Test matrix for roll-up flows

| Test | Action | Expected VisitWorkflow result |
|---|---|---|
| R-01 | Set VisitAdmin.AttendanceStatus = "Arrived" | Status = "Arrived" |
| R-02 | Set VisitClinicalStatus.Status = "In Progress" | Status = "Visit In Progress" |
| R-03 | Set VisitClinicalStatus.Status = "Complete" | Status = "Visit Complete" |
| R-04 | Set VisitClinicalStatus.Status = "Complete", ReadyForQC = true | Status = "Ready for QC", QCReadyAt stamped |
| R-05 | Create QCFinding with Status = "Open" | OpenQueryCount = 1, Status = "QC In Progress", QCStartedAt stamped |
| R-06 | Set QCFinding.Status = "Returned" | QCStatus = "Returned", Status = "QC Returned" |
| R-07 | Set QCFinding.Status = "Closed", Resolution filled, ResolvedAt filled | OpenQueryCount = 0, QCStatus = "Passed", Status = "QC Passed", QCPassedAt stamped |
| R-08 | Set EDCStatus.Status = "Ready" | EDCStatus = "Ready", Status = "Ready for EDC", EDCReadyAt stamped |
| R-09 | Set EDCStatus.Status = "In Progress" | Status = "EDC In Progress", EDCStartedAt stamped |
| R-10 | Set EDCStatus.Status = "Complete" with valid evidence | Status = "EDC Complete", EDCCompletedAt stamped, CloseEligible evaluated |
| R-11 | Create PIAction with Status = "Pending" | PIActionRequired = true, PIActionStatus = "Pending", Status = "PI Action" |
| R-12 | Set PIAction.Status = "Complete" with CompletedAt and Outcome filled | PIActionStatus = "Complete", CloseEligible = true (if all other conditions met) |
| R-13 | Attempt to Close VisitWorkflow when CloseEligible = false | Blocked or warned by app (guard TBD) |
| R-14 | Close VisitWorkflow when CloseEligible = true | Status = "Closed", ClosedAt stamped, WorkflowAudit row created |
| R-15 | Reopen a closed QCFinding | OpenQueryCount increments, CloseEligible reverts to false |
