# Trident Operations Central DEV — User Execution Guide
# 2026-10-02 to 2026-10-07 (Codex weekly cap period)

Claude Code cannot make tenant changes. This guide gives you step-by-step click-by-click instructions
to carry the remaining P0-2 flow work, P0-3 permissions, and P1-3/P1-4/P1-5 Power Apps changes yourself.
All expressions are ready to copy-paste.

---

## Status at start of this guide

| Item | Status | What you need to do |
|---|---|---|
| P0-1 EDC completion guard | DONE | Nothing |
| P0-2 Flow 4 (EDCStatus roll-up) | Saved OFF, 2 fixes needed | Part 1 |
| P0-2 Flow 2 (VisitClinicalStatus) | Not built | Part 2 |
| P0-2 Flow 1 (VisitAdmin) | Not built | Part 3 |
| P0-2 Flow 3 (QCFinding) | Not built | Part 4 |
| P0-2 Flow 5 (PIAction) | Not built | Part 5 |
| P0-3 WorkflowAudit permissions | Staged, awaiting your confirmation | Part 6 |
| P1-1 PIAction completion guard | DONE | Nothing |
| P1-2 QCFinding closure guard | DONE | Nothing |
| P1-3 Auto-timestamps | Not built | Part 7 |
| P1-4 Duplicate detection | Not built | Part 8 |
| P1-5 Chronology validation | Not built | Part 9 |

---

## Expression copy-paste rules

- Every expression in this guide starts with `@`. Paste it exactly as written.
- In Power Automate: when you see an expression field, click the field, select the **Expression** tab in the dynamic content panel, paste the expression, click **OK**.
- In Power Apps: paste into the formula bar for the relevant property (OnSelect, DisplayMode, etc.).
- Never wrap expressions in quotes unless the guide says to.

---

## Part 1 — Fix and activate Flow 4 (EDCStatus roll-up)

**Flow:** `Trident DEV - EDCStatus roll-up` (ID ae08aa72-25cb-484a-82ea-883281a36d35)
**Fixes needed:** Add CloseEligible field (Item A). Add Returned→In Progress mapping (Item C).
Items B (Status guard expression) and D (timestamp null-checks) were confirmed correct by Codex seq 15.

### 1.1 — Open the flow

1. Go to make.powerautomate.com.
2. Left nav → My flows.
3. Find "Trident DEV - EDCStatus roll-up". Click **Edit**.

### 1.2 — Fix Item C: Returned mapping on EDCStatus mirror field

In the **Update item** action (the one that writes to VisitWorkflow):

1. Find the **EDCStatus** field mapping.
2. Click the expression next to it. It currently reads something like:
   `@triggerOutputs()?['body/Status/Value']`
3. Replace with:
   ```
   @if(equals(triggerOutputs()?['body/Status/Value'],'Returned'),
       'In Progress',
       triggerOutputs()?['body/Status/Value'])
   ```
4. Click **OK**.

### 1.3 — Fix Item A: Add CloseEligible

Still in the same **Update item** action:

1. Click **Add new item** (or the + button to add another field to the Update action body).
2. Select the **CloseEligible** column.
3. In the value field, select the **Expression** tab and paste:
   ```
   @and(
     equals(triggerOutputs()?['body/Status/Value'],'Complete'),
     equals(first(body('Get_items')?['value'])?['QCStatus/Value'],'Passed'),
     or(
       equals(first(body('Get_items')?['value'])?['PIActionStatus/Value'],'Complete'),
       equals(first(body('Get_items')?['value'])?['PIActionStatus/Value'],'Not Required'),
       empty(first(body('Get_items')?['value'])?['PIActionStatus/Value'])
     )
   )
   ```
   *(Note: `Get_items` is the action name Codex used for the VisitWorkflow Get items call. Confirm the exact action name matches in your flow — check the action title above the Get items step.)*
4. Click **OK**.

### 1.4 — Save and check

1. Click **Save**.
2. Wait for save to complete.
3. Check the flow checker (top right) — must show **0 errors, 0 warnings**.
4. If errors appear, the most common cause is a mismatched action name in `body('Get_items')`. Check the actual name of the Get items action (the `...` menu → Rename shows the internal name) and update the expression.

### 1.5 — Activate the flow

1. Return to My flows list.
2. Find "Trident DEV - EDCStatus roll-up".
3. Toggle the flow from **Off** to **On**.
4. Confirm it shows as **On**.

### 1.6 — Run activation tests F4-T1 through F4-T6

Use fictitious DEV records only. Record run IDs from the flow run history after each test.

**F4-T1 — Ready transition**
- Open the DEV app → EDCStatus screen for DEV-UAT-20260930-VW-001.
- Set Status = "Ready". Save.
- Expected: Flow run succeeds. VisitWorkflow.EDCStatus = "Ready", Status = "Ready for EDC", EDCReadyAt is populated.

**F4-T2 — In Progress transition**
- Set EDCStatus.Status = "In Progress". Save.
- Expected: VisitWorkflow.EDCStatus = "In Progress", Status = "EDC In Progress", EDCStartedAt populated, EDCReadyAt unchanged.

**F4-T3 — Complete transition (valid)**
- Ensure the EDCStatus record has QueryStatus = None or Resolved, OpenQueryCount = 0, CompletedAt populated (so the EDC completion guard does NOT demote it).
- Set EDCStatus.Status = "Complete". Save.
- Expected: EDC guard runs first (no demotion). Roll-up runs: VisitWorkflow.EDCStatus = "Complete", Status = "EDC Complete", EDCCompletedAt populated.

**F4-T4 — Returned mapping**
- Set EDCStatus.Status = "Returned". Save.
- Expected: VisitWorkflow.EDCStatus = "In Progress" (not "Returned"). Parent Status unchanged.

**F4-T5 — No backwards transition**
- Reset parent Status to "QC Passed" by editing the VisitWorkflow record directly in SharePoint.
- Set EDCStatus.Status = "Complete". Save.
- Expected: VisitWorkflow.Status remains "QC Passed" — the transition only fires when parent is "EDC In Progress".

**F4-T6 — Timestamp idempotency**
- Run F4-T2 again on the same record.
- Expected: EDCStartedAt is unchanged from the first run.

**Record evidence:** Note the flow run IDs from the Run history, and the VisitWorkflow record field values after each test. This is the verification evidence for P0-2 Flow 4.

---

## Part 2 — Build Flow 2: VisitClinicalStatus roll-up

**Flow name:** `Trident DEV - VisitClinicalStatus roll-up`
**Copy from:** `Trident DEV - EDCStatus roll-up` to reuse the connection and basic structure.

### 2.1 — Create the flow

1. My flows → Find "Trident DEV - EDCStatus roll-up" → Click **...** → **Save As**.
2. Name it `Trident DEV - VisitClinicalStatus roll-up`. Save.
3. Open the copy to edit.

### 2.2 — Change the trigger

1. Click the trigger step (SharePoint — When an item is created or modified).
2. Change the **List Name** to **VisitClinicalStatus**.
3. Site Address stays the same DEV site.

### 2.3 — Update the Get items action

1. Find the Get items action (currently filtering VisitWorkflow by VisitKey).
2. Rename it to `Get_VCS_parent` (click the title, type the new name).
3. Confirm: List = VisitWorkflow, Filter Query = `VisitKey eq '@{triggerOutputs()?['body/VisitKey/Value']}'`, Top Count = 1.
   *(This filter is the same — VisitClinicalStatus records also have a VisitKey field.)*

### 2.4 — Update the condition

Change the parent-exists condition to reference `Get_VCS_parent`:
```
@greater(length(body('Get_VCS_parent')?['value']),0)
```

### 2.5 — Update the Update item action

In the Update item (VisitWorkflow) action, replace ALL field mappings with the following.
Delete any existing mappings first, then add each field listed.

**ID** (required — do not change):
```
@first(body('Get_VCS_parent')?['value'])?['ID']
```

**VisitOwner:**
```
@triggerOutputs()?['body/VisitOwner/Claims']
```

**ActualVisitDate** (set only when blank on parent):
```
@if(empty(first(body('Get_VCS_parent')?['value'])?['ActualVisitDate']),
    triggerOutputs()?['body/StartedAt'],
    first(body('Get_VCS_parent')?['value'])?['ActualVisitDate'])
```

**Status:**
```
@if(
  and(equals(triggerOutputs()?['body/Status/Value'],'Complete'),
      equals(triggerOutputs()?['body/ReadyForQC'],true),
      or(equals(first(body('Get_VCS_parent')?['value'])?['Status/Value'],'Visit In Progress'),
         equals(first(body('Get_VCS_parent')?['value'])?['Status/Value'],'Visit Complete'))),
  'Ready for QC',
  if(
    and(equals(triggerOutputs()?['body/Status/Value'],'Complete'),
        or(equals(first(body('Get_VCS_parent')?['value'])?['Status/Value'],'Visit In Progress'),
           equals(first(body('Get_VCS_parent')?['value'])?['Status/Value'],'Arrived'))),
    'Visit Complete',
    if(
      and(equals(triggerOutputs()?['body/Status/Value'],'In Progress'),
          equals(first(body('Get_VCS_parent')?['value'])?['Status/Value'],'Arrived')),
      'Visit In Progress',
      first(body('Get_VCS_parent')?['value'])?['Status/Value']
    )
  )
)
```

**QCReadyAt** (stamp only when transitioning to Ready for QC, and only if blank):
```
@if(
  and(equals(triggerOutputs()?['body/Status/Value'],'Complete'),
      equals(triggerOutputs()?['body/ReadyForQC'],true),
      empty(first(body('Get_VCS_parent')?['value'])?['QCReadyAt'])),
  utcNow(),
  first(body('Get_VCS_parent')?['value'])?['QCReadyAt'])
```

**CloseEligible** (set to false — VCS is a prerequisite but we cannot confirm all conditions from this flow alone; Flow 5 will compute the final composite):
```
@false
```
*(Flow 5 is the last to run in the logical sequence and performs the full composite check.)*

### 2.6 — Add WorkflowAudit row

After the Update item action, add: **Create item** (SharePoint) → List = **WorkflowAudit**.

Field values:
- EventType: `Status Change`
- FieldName: `Status`
- OldValue:
  ```
  @first(body('Get_VCS_parent')?['value'])?['Status/Value']
  ```
- NewValue: *(same Status expression as above — paste the full expression)*
- EntityType: `VisitWorkflow`
- EntityKey:
  ```
  @triggerOutputs()?['body/VisitKey/Value']
  ```
- SourceApp: `Power Automate`
- CorrelationID:
  ```
  @workflow().run.name
  ```
- AuditEventID:
  ```
  @guid()
  ```

### 2.7 — Save, check, activate

1. Save. Checker must show 0 errors, 0 warnings.
2. Turn flow **On**.

### 2.8 — Test cases

**VCS-T1:** Set VisitClinicalStatus.Status = "In Progress". Expected: parent Arrived → Visit In Progress.

**VCS-T2:** Set Status = "Complete", ReadyForQC = false. Expected: parent → Visit Complete.

**VCS-T3:** Set Status = "Complete", ReadyForQC = true. Expected: parent → Ready for QC, QCReadyAt stamped.

**VCS-T4:** Save VCS record again (no change). Expected: QCReadyAt unchanged, no double-stamp.

---

## Part 3 — Build Flow 1: VisitAdmin roll-up

**Flow name:** `Trident DEV - VisitAdmin roll-up`
**Copy from:** `Trident DEV - VisitClinicalStatus roll-up` (saves having to re-do the WorkflowAudit step).

### 3.1 — Create the flow

Save As from Flow 2 copy. Name: `Trident DEV - VisitAdmin roll-up`.

### 3.2 — Change the trigger

List Name → **VisitAdmin**.

### 3.3 — Update Get items action

Rename to `Get_VA_parent`. Same VisitWorkflow list, same VisitKey filter.

### 3.4 — Update the condition

```
@greater(length(body('Get_VA_parent')?['value']),0)
```

### 3.5 — Update the Update item action

Replace all mappings:

**ID:**
```
@first(body('Get_VA_parent')?['value'])?['ID']
```

**PlannedDate:**
```
@triggerOutputs()?['body/PlannedDate']
```

**ReceptionOwner:**
```
@triggerOutputs()?['body/ReceptionOwner/Claims']
```

**ActualVisitDate** (set only when arriving for first time, and blank on parent):
```
@if(
  and(equals(triggerOutputs()?['body/AttendanceStatus/Value'],'Arrived'),
      empty(first(body('Get_VA_parent')?['value'])?['ActualVisitDate'])),
  triggerOutputs()?['body/ArrivalTime'],
  first(body('Get_VA_parent')?['value'])?['ActualVisitDate'])
```

**Status:**
```
@if(
  and(equals(triggerOutputs()?['body/AttendanceStatus/Value'],'Arrived'),
      equals(first(body('Get_VA_parent')?['value'])?['Status/Value'],'Scheduled')),
  'Arrived',
  if(
    or(equals(triggerOutputs()?['body/AttendanceStatus/Value'],'No Show'),
       equals(triggerOutputs()?['body/AttendanceStatus/Value'],'Cancelled')),
    'Scheduled',
    first(body('Get_VA_parent')?['value'])?['Status/Value']
  )
)
```

**CloseEligible:** `@false`

### 3.6 — Update WorkflowAudit Create item

Change action names in the OldValue and EntityKey expressions to reference `Get_VA_parent`. Keep the same field structure.

### 3.7 — Save, check, activate

Checker must show 0 errors, 0 warnings. Turn flow On.

### 3.8 — Test cases

**VA-T1:** Set VisitAdmin.AttendanceStatus = "Arrived". Expected: parent Scheduled → Arrived, ActualVisitDate stamped with ArrivalTime value.

**VA-T2:** Set AttendanceStatus = "No Show". Expected: parent → Scheduled.

**VA-T3:** Update PlannedDate only. Expected: parent PlannedDate mirrors the new date, Status unchanged.

---

## Part 4 — Build Flow 3: QCFinding roll-up

**Flow name:** `Trident DEV - QCFinding roll-up`
This flow is more complex — it reads all QCFindings for a visit and computes counts.
**Copy from** the VisitAdmin flow for the basic shell, then make significant changes.

### 4.1 — Create the flow

Save As from Flow 1. Name: `Trident DEV - QCFinding roll-up`. Open to edit.

### 4.2 — Change the trigger

List Name → **QCFinding**.

### 4.3 — Update Get parent action

Rename to `Get_QC_parent`. VisitWorkflow, VisitKey filter, Top = 1.

### 4.4 — Update the parent-exists condition

```
@greater(length(body('Get_QC_parent')?['value']),0)
```

### 4.5 — Add: Get all QCFindings for this VisitKey

**After** the condition true branch begins (after the parent-exists check), add a new **Get items** action.
- List: QCFinding
- Filter Query:
  ```
  VisitKey eq '@{triggerOutputs()?['body/VisitKey/Value']}'
  ```
- Top Count: **leave blank** (need all findings)
- Rename this action: `Get_all_QCFindings`

### 4.6 — Add three Filter array actions

Add three **Filter array** actions (under Data Operations) immediately after `Get_all_QCFindings`:

**Filter_open_findings:**
- From: `@body('Get_all_QCFindings')?['value']`
- Condition: item Status/Value is equal to Open **OR** item Status/Value is equal to Returned **OR** item Status/Value is equal to In Progress.
  Use advanced mode expression:
  ```
  @or(
    equals(item()?['Status/Value'],'Open'),
    equals(item()?['Status/Value'],'Returned'),
    equals(item()?['Status/Value'],'In Progress')
  )
  ```

**Filter_closed_findings:**
- From: `@body('Get_all_QCFindings')?['value']`
- Advanced mode:
  ```
  @or(
    equals(item()?['Status/Value'],'Resolved'),
    equals(item()?['Status/Value'],'Verified'),
    equals(item()?['Status/Value'],'Closed')
  )
  ```

**Filter_returned_findings:**
- From: `@body('Get_all_QCFindings')?['value']`
- Advanced mode:
  ```
  @equals(item()?['Status/Value'],'Returned')
  ```

### 4.7 — Add three Initialize variable actions (place before the Update item)

Add these in the true branch of the parent-exists condition, after the Filter actions:

**Initialize variable — openCount:**
- Name: `openCount`
- Type: Integer
- Value: `@length(body('Filter_open_findings'))`

**Initialize variable — closedCount:**
- Name: `closedCount`
- Type: Integer
- Value: `@length(body('Filter_closed_findings'))`

**Initialize variable — qcStatusValue:**
- Name: `qcStatusValue`
- Type: String
- Value:
  ```
  @if(greater(length(body('Filter_returned_findings')),0),
      'Returned',
      if(greater(length(body('Filter_open_findings')),0),
         'In Progress',
         if(greater(length(body('Filter_closed_findings')),0),
            'Passed',
            'Not Ready')))
  ```

### 4.8 — Update the Update item action

Replace all mappings (reference `Get_QC_parent`):

**ID:**
```
@first(body('Get_QC_parent')?['value'])?['ID']
```

**OpenQueryCount:**
```
@variables('openCount')
```

**QCStatus:**
```
@variables('qcStatusValue')
```

**QCStartedAt** (stamp on first In Progress, only if blank):
```
@if(
  and(equals(variables('qcStatusValue'),'In Progress'),
      empty(first(body('Get_QC_parent')?['value'])?['QCStartedAt'])),
  utcNow(),
  first(body('Get_QC_parent')?['value'])?['QCStartedAt'])
```

**QCPassedAt** (stamp when Passed, only if blank):
```
@if(
  and(equals(variables('qcStatusValue'),'Passed'),
      empty(first(body('Get_QC_parent')?['value'])?['QCPassedAt'])),
  utcNow(),
  first(body('Get_QC_parent')?['value'])?['QCPassedAt'])
```

**Status:**
```
@if(
  and(equals(variables('qcStatusValue'),'Returned'),
      or(equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'QC In Progress'),
         equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'Ready for QC'))),
  'QC Returned',
  if(
    and(equals(variables('qcStatusValue'),'In Progress'),
        or(equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'Ready for QC'),
           equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'QC Returned'))),
    'QC In Progress',
    if(
      and(equals(variables('qcStatusValue'),'Passed'),
          or(equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'QC In Progress'),
             equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'QC Returned'),
             equals(first(body('Get_QC_parent')?['value'])?['Status/Value'],'Ready for QC'))),
      'QC Passed',
      first(body('Get_QC_parent')?['value'])?['Status/Value']
    )
  )
)
```

**CloseEligible:** `@false`

### 4.9 — Update WorkflowAudit Create item

Update action names to `Get_QC_parent`. Keep all other fields the same.

### 4.10 — Save, check, activate

Checker: 0 errors, 0 warnings. Turn flow On.

### 4.11 — Test cases

**QCR-T1:** Create QCFinding for DEV-UAT-20260930-VW-001 with Status = Open. Expected: OpenQueryCount = 1, parent Status → QC In Progress (if parent was at Ready for QC), QCStartedAt stamped.

**QCR-T2:** Set QCFinding.Status = Returned. Expected: QCStatus = Returned, parent Status → QC Returned.

**QCR-T3:** Set QCFinding.Status = Closed (ensure Resolution and ResolvedAt are filled so QCFinding closure guard does not demote it). Expected: OpenQueryCount = 0, QCStatus = Passed, parent Status → QC Passed, QCPassedAt stamped.

**QCR-T4:** Save the record again. Expected: QCPassedAt unchanged.

---

## Part 5 — Build Flow 5: PIAction roll-up

**Flow name:** `Trident DEV - PIAction roll-up`
This flow includes a VisitKey null guard (study-level PIActions must not trigger parent updates).
**Copy from** Flow 3 (QCFinding) as the structure is similar.

### 5.1 — Create the flow

Save As from Flow 3. Name: `Trident DEV - PIAction roll-up`. Open to edit.

### 5.2 — Change the trigger

List Name → **PIAction**.

### 5.3 — Add VisitKey null guard (first action, before everything else)

Add a **Condition** action as the very first step after the trigger.

- Condition expression (advanced mode):
  ```
  @not(empty(triggerOutputs()?['body/VisitKey/Value']))
  ```
- True branch: continue to the rest of the flow.
- False branch: Add **Terminate** action → Status = Succeeded.

### 5.4 — Update Get parent action

Rename to `Get_PIA_parent`. VisitWorkflow, filter by VisitKey, Top = 1.

### 5.5 — Update parent-exists condition

```
@greater(length(body('Get_PIA_parent')?['value']),0)
```

### 5.6 — Update Get all PIActions action

Change list from QCFinding to **PIAction**. Same VisitKey filter. Rename to `Get_all_PIActions`.

### 5.7 — Update Filter array actions

**Filter_pending_PIActions** (replaces Filter_open_findings):
```
@or(
  equals(item()?['Status/Value'],'Pending'),
  equals(item()?['Status/Value'],'In Progress')
)
```

**Filter_required_PIActions** (replaces Filter_closed_findings):
```
@and(
  not(equals(item()?['Status/Value'],'Not Required')),
  not(equals(item()?['Status/Value'],'Entered in Error'))
)
```

Delete the Filter_returned_findings action (not needed for PIAction logic).

### 5.8 — Update variables

**pendingCount:**
- Name: `pendingCount`
- Type: Integer
- Value: `@length(body('Filter_pending_PIActions'))`

**actionRequired:**
- Name: `actionRequired`
- Type: Boolean
- Value: `@greater(length(body('Filter_required_PIActions')),0)`

**piActionStatusValue:**
- Name: `piActionStatusValue`
- Type: String
- Value:
  ```
  @if(greater(variables('pendingCount'),0),
      'Pending',
      if(variables('actionRequired'),
         'Complete',
         'Not Required'))
  ```

### 5.9 — Update the Update item action

**ID:**
```
@first(body('Get_PIA_parent')?['value'])?['ID']
```

**PIActionRequired:**
```
@variables('actionRequired')
```

**PIActionStatus:**
```
@variables('piActionStatusValue')
```

**Status:**
```
@if(
  and(greater(variables('pendingCount'),0),
      or(equals(first(body('Get_PIA_parent')?['value'])?['Status/Value'],'EDC Complete'),
         equals(first(body('Get_PIA_parent')?['value'])?['Status/Value'],'PI Action'))),
  'PI Action',
  first(body('Get_PIA_parent')?['value'])?['Status/Value']
)
```

**CloseEligible** — THIS flow computes the full composite check (Flow 5 is the logical final step):
```
@and(
  equals(first(body('Get_PIA_parent')?['value'])?['EDCStatus/Value'],'Complete'),
  equals(first(body('Get_PIA_parent')?['value'])?['QCStatus/Value'],'Passed'),
  or(
    equals(variables('piActionStatusValue'),'Complete'),
    equals(variables('piActionStatusValue'),'Not Required')
  )
)
```
*(Note: VisitClinicalStatus completion is proxied by QC Passed already being set — if QC is Passed, VCS must have been Complete earlier. This avoids an extra Get items call. If VCS completion needs a strict check, add a Get items for VisitClinicalStatus before the Update.)*

### 5.10 — Update WorkflowAudit Create item

Update action name references to `Get_PIA_parent`. Add a second Create item action for PIActionRequired change (FieldName = "PIActionRequired").

### 5.11 — Save, check, activate

Checker: 0 errors, 0 warnings. Turn flow On.

### 5.12 — Test cases

**PIA-T1:** Create PIAction with no VisitKey (leave VisitKey blank). Expected: flow terminates with Succeeded, no VisitWorkflow update.

**PIA-T2:** Create PIAction for DEV-UAT-20260930-VW-001 with Status = Pending. Expected: parent PIActionRequired = true, PIActionStatus = Pending, parent Status → PI Action (if parent was at EDC Complete).

**PIA-T3:** Set PIAction.Status = Complete with CompletedAt and Outcome filled (so PIAction completion guard passes). Expected: PIActionStatus = Complete, CloseEligible = true (if parent QCStatus = Passed and EDCStatus = Complete).

---

## Part 6 — P0-3: WorkflowAudit append-only permissions

**Gate:** You confirmed this is ready to proceed. If not confirmed yet, skip to Part 7 and return here.

The full step-by-step is in the AI_COLLABORATION_LOG.md seq 10 WU1 entry. Summary:

1. Power Automate → Connections → find the SharePoint connection used by any WorkflowAudit-writing flow → record the account email.
2. SharePoint site → WorkflowAudit list → List Settings → Permissions for this list → **Stop Inheriting Permissions** → OK.
3. Remove all existing inherited groups from the list.
4. Grant **Read** to: tasneem.essop@tridentclinical.co.za, l.pata@tridentclinical.co.za, kyla.ryland@tridentclinical.co.za, info@tridentclinical.co.za.
5. Grant **Contribute** to the flow connection account email from step 1.
6. Verify the permissions page shows exactly those five entries.
7. Test: trigger the EDC guard → flow Run history shows Create item on WorkflowAudit succeeded (HTTP 201).
8. Test: log in as one of the four named users → WorkflowAudit list → **New** button is absent or disabled.

---

## Part 7 — P1-3: Auto-timestamps in Power Apps

These changes go in the **OnSelect** formula of the Save button on each screen.
The `UTCNow()` pattern prevents backdating — a timestamp is written only when the field is blank.

### VisitClinicalStatus screen save button

Replace the Patch call with:

```powerapps
Patch(
    VisitClinicalStatus,
    If(IsBlank(Gallery_VCS.Selected), Defaults(VisitClinicalStatus), Gallery_VCS.Selected),
    {
        Status: Dropdown_VCSStatus.Selected.Value,
        StartedAt: If(
            Dropdown_VCSStatus.Selected.Value = "In Progress"
                And IsBlank(Gallery_VCS.Selected.StartedAt),
            UTCNow(),
            Gallery_VCS.Selected.StartedAt),
        CompletedAt: If(
            Dropdown_VCSStatus.Selected.Value = "Complete"
                And IsBlank(Gallery_VCS.Selected.CompletedAt),
            UTCNow(),
            Gallery_VCS.Selected.CompletedAt)
    }
)
```

### EDCStatus screen save button

```powerapps
Patch(
    EDCStatus,
    If(IsBlank(Gallery_EDC.Selected), Defaults(EDCStatus), Gallery_EDC.Selected),
    {
        Status: Dropdown_EDCStatus.Selected.Value,
        ReadyAt: If(
            Dropdown_EDCStatus.Selected.Value = "Ready"
                And IsBlank(Gallery_EDC.Selected.ReadyAt),
            UTCNow(),
            Gallery_EDC.Selected.ReadyAt),
        StartedAt: If(
            Dropdown_EDCStatus.Selected.Value = "In Progress"
                And IsBlank(Gallery_EDC.Selected.StartedAt),
            UTCNow(),
            Gallery_EDC.Selected.StartedAt),
        CompletedAt: If(
            Dropdown_EDCStatus.Selected.Value = "Complete"
                And IsBlank(Gallery_EDC.Selected.CompletedAt),
            UTCNow(),
            Gallery_EDC.Selected.CompletedAt)
    }
)
```

### PIAction screen save button

```powerapps
Patch(
    PIAction,
    If(IsBlank(Gallery_PIA.Selected), Defaults(PIAction), Gallery_PIA.Selected),
    {
        Status: Dropdown_PIAStatus.Selected.Value,
        RequiredAt: If(
            IsBlank(Gallery_PIA.Selected)
                And IsBlank(Gallery_PIA.Selected.RequiredAt),
            UTCNow(),
            Gallery_PIA.Selected.RequiredAt),
        CompletedAt: If(
            Dropdown_PIAStatus.Selected.Value = "Complete"
                And IsBlank(Gallery_PIA.Selected.CompletedAt),
            UTCNow(),
            Gallery_PIA.Selected.CompletedAt)
    }
)
```

### QCFinding screen save button

```powerapps
Patch(
    QCFinding,
    If(IsBlank(Gallery_QCF.Selected), Defaults(QCFinding), Gallery_QCF.Selected),
    {
        Status: Dropdown_QCFStatus.Selected.Value,
        ResolvedAt: If(
            Or(Dropdown_QCFStatus.Selected.Value = "Resolved",
               Dropdown_QCFStatus.Selected.Value = "Verified")
                And IsBlank(Gallery_QCF.Selected.ResolvedAt),
            UTCNow(),
            Gallery_QCF.Selected.ResolvedAt)
    }
)
```

**Verification:** Save a record as "In Progress" — StartedAt stamps. Save again — StartedAt is unchanged.

---

## Part 8 — P1-4: Duplicate detection in Power Apps

Add this check **before** the Patch call on the New record save button for each screen.
The `IsBlank(Gallery.Selected)` guard ensures the check only fires for new records, not edits.

### VisitAdmin screen (new record save)

```powerapps
If(
    IsBlank(Gallery_VA.Selected)
        And CountRows(Filter(VisitAdmin, VisitAdminID = TextInput_VisitAdminID.Text)) > 0,
    Notify("VisitAdminID already exists. Use a unique identifier.", NotificationType.Error),
    Patch(VisitAdmin, Defaults(VisitAdmin), {VisitAdminID: TextInput_VisitAdminID.Text /*, ...other fields... */})
)
```

### QCFinding screen (new record save)

```powerapps
If(
    IsBlank(Gallery_QCF.Selected)
        And CountRows(Filter(QCFinding, FindingID = TextInput_FindingID.Text)) > 0,
    Notify("FindingID already exists. Use a unique identifier.", NotificationType.Error),
    Patch(QCFinding, Defaults(QCFinding), {FindingID: TextInput_FindingID.Text /*, ...other fields... */})
)
```

### EDCStatus screen (new record save)

```powerapps
If(
    IsBlank(Gallery_EDC.Selected)
        And CountRows(Filter(EDCStatus, DataRecordID = TextInput_DataRecordID.Text)) > 0,
    Notify("DataRecordID already exists. Use a unique identifier.", NotificationType.Error),
    Patch(EDCStatus, Defaults(EDCStatus), {DataRecordID: TextInput_DataRecordID.Text /*, ...other fields... */})
)
```

### PIAction screen (new record save)

```powerapps
If(
    IsBlank(Gallery_PIA.Selected)
        And CountRows(Filter(PIAction, PIActionID = TextInput_PIActionID.Text)) > 0,
    Notify("PIActionID already exists. Use a unique identifier.", NotificationType.Error),
    Patch(PIAction, Defaults(PIAction), {PIActionID: TextInput_PIActionID.Text /*, ...other fields... */})
)
```

**Note:** Replace the control names (`Gallery_VA`, `TextInput_VisitAdminID`, etc.) with the actual names from your Power Apps app. The pattern is the same for all screens.

**Test:** Enter a VisitAdminID that already exists on the New screen → expect error notification, no Patch. Enter a unique ID → expect success.

---

## Part 9 — P1-5: Chronology validation in Power Apps

Add these checks **before** the Patch call on the save button for each screen.
Chain multiple checks using nested If (later conditions only evaluate if earlier ones pass).

### VisitAdmin screen

```powerapps
If(
    Not(IsBlank(DatePicker_DepartureTime.SelectedDate))
        And DatePicker_DepartureTime.SelectedDate < DatePicker_ArrivalTime.SelectedDate,
    Notify("Departure time cannot be before arrival time.", NotificationType.Error),
    Patch(VisitAdmin, /* ... */)
)
```

### QCFinding screen

```powerapps
If(
    Not(IsBlank(DatePicker_ResolvedAt.SelectedDate))
        And DatePicker_ResolvedAt.SelectedDate < DatePicker_RaisedAt.SelectedDate,
    Notify("Resolved date cannot be before raised date.", NotificationType.Error),
    Patch(QCFinding, /* ... */)
)
```

### EDCStatus screen (chain three checks)

```powerapps
If(
    Not(IsBlank(DatePicker_EDCStartedAt.SelectedDate))
        And Not(IsBlank(DatePicker_EDCReadyAt.SelectedDate))
        And DatePicker_EDCStartedAt.SelectedDate < DatePicker_EDCReadyAt.SelectedDate,
    Notify("EDC Started date cannot be before Ready date.", NotificationType.Error),
    Not(IsBlank(DatePicker_EDCCompletedAt.SelectedDate))
        And Not(IsBlank(DatePicker_EDCStartedAt.SelectedDate))
        And DatePicker_EDCCompletedAt.SelectedDate < DatePicker_EDCStartedAt.SelectedDate,
    Notify("EDC Completed date cannot be before Started date.", NotificationType.Error),
    Patch(EDCStatus, /* ... */)
)
```

### PIAction screen

```powerapps
If(
    Not(IsBlank(DatePicker_PIACompletedAt.SelectedDate))
        And Not(IsBlank(DatePicker_PIARequiredAt.SelectedDate))
        And DatePicker_PIACompletedAt.SelectedDate < DatePicker_PIARequiredAt.SelectedDate,
    Notify("Completed date cannot be before required date.", NotificationType.Error),
    Patch(PIAction, /* ... */)
)
```

**Test for VisitAdmin:** Enter DepartureTime 10:00, ArrivalTime 17:00 → error, no save. Enter DepartureTime 18:00, ArrivalTime 17:00 → success.

---

## Part 10 — UAT test cases R-01 through R-15

Run after all five flows are ON and all Power Apps changes are published.
Use the record DEV-UAT-20260930-VW-001 (reset to "Scheduled" status before starting).

| Case | Action | Expected result |
|---|---|---|
| R-01 | Create VisitAdmin for VW-001 with PlannedDate | VisitWorkflow.PlannedDate mirrors |
| R-02 | Set VisitAdmin.AttendanceStatus = Arrived | VisitWorkflow.Status = Arrived, ActualVisitDate stamped |
| R-03 | Set VisitClinicalStatus.Status = In Progress | VisitWorkflow.Status = Visit In Progress |
| R-04 | Set VisitClinicalStatus.Status = Complete, ReadyForQC = false | VisitWorkflow.Status = Visit Complete |
| R-05 | Set VisitClinicalStatus.Status = Complete, ReadyForQC = true | VisitWorkflow.Status = Ready for QC, QCReadyAt stamped |
| R-06 | Create QCFinding with Status = Open | VisitWorkflow.OpenQueryCount = 1, Status = QC In Progress |
| R-07 | Set QCFinding.Status = Closed (valid) | OpenQueryCount = 0, QCStatus = Passed, Status = QC Passed, QCPassedAt stamped |
| R-08 | Set EDCStatus.Status = Ready | VisitWorkflow.EDCStatus = Ready, Status = Ready for EDC |
| R-09 | Set EDCStatus.Status = In Progress | VisitWorkflow.EDCStatus = In Progress, Status = EDC In Progress |
| R-10 | Set EDCStatus.Status = Complete (valid) | VisitWorkflow.EDCStatus = Complete, Status = EDC Complete, EDCCompletedAt stamped |
| R-11 | Create PIAction with Status = Pending | VisitWorkflow.PIActionRequired = true, PIActionStatus = Pending, Status = PI Action |
| R-12 | Set PIAction.Status = Complete (valid) | PIActionStatus = Complete, CloseEligible = true |
| R-13 | Attempt to Close VisitWorkflow when CloseEligible = false | Blocked or warned by app (if guard implemented) |
| R-14 | Close VisitWorkflow when CloseEligible = true | Status = Closed, ClosedAt stamped |
| R-15 | Reopen a closed QCFinding after R-14 | OpenQueryCount increments, CloseEligible reverts to false |

---

## Confirmation items for Claude Code / Codex

After you complete work from this guide, update the collaboration log with:
- Flow IDs for each new flow built
- Run IDs from activation tests
- Which R-xx UAT cases passed
- Any expressions that needed adjustment (so Claude Code can update the specs)

---

*Written by Claude Code 2026-10-02. Codex resumes 2026-10-07.*
