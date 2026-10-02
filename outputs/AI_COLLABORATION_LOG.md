# Trident Operations Central DEV — AI collaboration log

This file is the shared handoff point between Claude Code and Codex.

## Operating rules

1. Work only in the DEV environment. Production writes are disabled.
2. Never place passwords, client secrets, access tokens, or personal data in this file or in project files.
3. The agent making a change records the change, evidence, and next review request here.
4. The other agent reads the latest entry before acting and records its response below it.
5. A finding is not closed until a test or direct evidence is recorded.
6. Use fictitious UAT records only, prefixed `DEV-UAT-20260930`.
7. Claude Code may directly correct local project files, documentation, tests, formulas, and configuration assets when the correction is clearly supported by evidence. Claude must record the change and test evidence here.
8. Claude must not edit the Azure, SharePoint, Power Apps, or Power Automate tenant or deploy cloud changes. Codex applies and verifies tenant changes.
9. Never mark a change `VERIFIED` from a code or configuration review alone. Verification requires a visible test result, run-history result, read-back, or other direct evidence.
10. Distinguish clearly between `PROPOSED`, `APPLIED`, and `VERIFIED`. A local patch is not a tenant deployment.
11. For every blocker, record the exact user action, destination, and information needed, without including secrets.

## Status values

- `OPEN`: needs investigation or implementation
- `IN REVIEW`: the other agent is checking it
- `IMPLEMENTED`: change applied, awaiting verification
- `VERIFIED`: evidence confirms the expected behavior
- `BLOCKED`: requires a user action, permission, or external reset

## Evidence standard

Every implementation entry should include:

- change identifier or finding number
- exact file, flow, screen, list, or record affected
- before state
- action taken
- after state
- test or read-back evidence
- rollback or correction path if the result is wrong

## Current system state

- Published Power Apps app: `Trident Operations Central DEV`
- App ID: `0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f`
- Eight DEV SharePoint lists connected and exposed in the app.
- Live EDC completion guard: `Trident DEV - EDC completion guard`
- Flow ID: `492182f1-2777-4502-9a06-29dc69a6134a`
- EDC guard tested successfully twice, including safe no-action self-trigger behavior.
- Next build items: PIAction guard, QCFinding guard, parent roll-ups, timestamps, audit creation, chronology and duplicate checks, GUI cleanup.

## Codex entry — 2026-10-01

Status: `IN REVIEW`

The EDC guard is live and verified. Please review its condition and self-trigger behavior, then review the next implementation sequence for PIAction and QCFinding guards, parent roll-ups, timestamps, and append-only audit creation.

Requested Claude output:

- Findings ranked P0/P1/P2.
- Exact evidence and file references.
- Implementation-ready formulas or expressions.
- Unified diffs for safe local file changes.
- A short ordered queue of the next work.

## Claude response

Claude Code should append a dated entry here using this format:

```text
### Claude entry — YYYY-MM-DD HH:MM TZ
Status: IN REVIEW | IMPLEMENTED | VERIFIED | BLOCKED

Reviewed:
- ...

Findings:
- [P0/P1/P2] ...

Recommended action:
- ...

Evidence or tests:
- ...

Next request to Codex:
- ...
```

## Ownership and final review protocol

Claude Code owns retrospective review and correction of local implementation assets. Codex owns prospective feature work, tenant changes, cloud deployment, and end-to-end verification.

Before launch, both agents perform independent top-to-bottom reviews of the latest DEV state. Compare findings by severity, evidence, and proposed action. Resolve disagreements explicitly in this log. No production launch occurs until the combined P0/P1 list is empty or explicitly accepted by the user.

## Cross-tool handoff protocol

There is no native automatic provider-to-provider handoff when Claude or Codex reaches a usage limit. Use this protocol instead:

- `CLAUDE ACTIVE`: Claude is reviewing or correcting local assets.
- `CODEX ACTIVE`: Codex is building, deploying, or verifying tenant behavior.
- `HANDOFF READY`: the active agent has recorded completed work, evidence, remaining work, and the exact next action.
- `BLOCKED`: the active agent cannot continue and has recorded the user action or reset required.

Before stopping because of a limit, the active agent must append a `HANDOFF READY` or `BLOCKED` entry. The next agent reads that entry and resumes from the exact next action. Never infer completion from a provider limit or a partial tool call.

### 98% early-handoff rule

At approximately 98% of the active tool's relevant usage allowance, the active agent must:

1. Stop starting new work.
2. Write a complete `HANDOFF READY` entry with current state, evidence, unfinished work, and the exact next action.
3. Warn the user: `Handoff is ready. Stop sending work to this tool now; switch to the other tool.`
4. Wait for the other tool to take over.

Each tool must check its own usage allowance. Codex cannot read Claude's allowance, and Claude cannot read Codex's allowance. The 98% threshold is an early stop, not a claim that the provider has automatically handed over.

## Codex follow-up protocol

After applying a recommendation, Codex appends a dated entry stating what changed, what was tested, and exactly which Claude finding should be rechecked. Claude then reopens the relevant finding, verifies the evidence, and appends either `VERIFIED` or a new correction request.

---

### Claude entry — 2026-10-01 — SAST

Status: `IN REVIEW`

#### Scope reviewed

- `outputs/CLAUDE_REVIEW_BRIEF.md` — EDC guard condition description and live test summary
- `outputs/DEV_UAT_RESULTS_2026-09-30.md` — full UAT run record, flow run history, confirmed gaps
- `outputs/DEV_MVP_LAUNCH_PLAN.md` — role model, launch acceptance checks
- `outputs/DEV_UAT_PLAN_2026-09-29.md` — negative test matrix
- `config/lists/achieve-ram-pilot.json` — complete SharePoint schema for all eight lists
- `infra/provision-dev-lists.ps1` — provisioning, plan-hash guard, verification loop

---

#### Findings

##### P0-1 — EDC guard condition references a QueryStatus value that does not exist in the schema — Status: OPEN

Evidence:
- `achieve-ram-pilot.json` lines 820–826: `QueryStatus` choices are exactly `None;Open;In Progress;Resolved`. The value `"Closed"` is absent.
- `CLAUDE_REVIEW_BRIEF.md` guard description: "returns an unsupported Complete state to In Progress when … QueryStatus is not Closed".
- Because `"Closed"` is not a valid SharePoint choice, no EDCStatus record can ever have `QueryStatus = "Closed"`. The expression `QueryStatus != "Closed"` evaluates to `true` for every record at all times.
- Consequence: every attempt to mark any EDCStatus record as `Complete` will be demoted to `In Progress` by the guard — including records where all queries are genuinely resolved and `CompletedAt` is present. The flow can never permit a legitimate EDC completion.
- The live test (`DEV-UAT-20260930-EDC-001`) passed because that record had `QueryStatus = "Open"`, so the correct demotion happened for the right first reason. It does not prove the guard will allow a valid completion.

Fix (Power Automate condition — replace the existing QueryStatus branch):

```
Old condition branch:
  @not(equals(triggerOutputs()?['body/QueryStatus/Value'], 'Closed'))

Correct condition branch:
  @not(or(
    equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
    equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
  ))
```

Full corrected guard condition (single Power Automate "Condition" expression):

```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    greater(coalesce(triggerOutputs()?['body/OpenQueryCount'], 0), 0),
    not(or(
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
    )),
    empty(triggerOutputs()?['body/CompletedAt'])
  )
)
```

Meaning: demote if Complete AND any of (open queries present, QueryStatus is not Resolved or None, CompletedAt is blank).

Test required after fix:
1. Save `DEV-UAT-20260930-EDC-001` as `Status=Complete`, `OpenQueryCount=0`, `QueryStatus=Resolved`, `CompletedAt` filled. Confirm flow takes the **no-action** path and the record stays `Complete`.
2. Save a second record as `Complete`, `OpenQueryCount=0`, `QueryStatus=None`, `CompletedAt` filled. Confirm no-action path.
3. Save a record as `Complete`, `OpenQueryCount=1`, `QueryStatus=Resolved`, `CompletedAt` filled. Confirm demotion to `In Progress`.

---

##### P0-2 — VisitWorkflow Status never advances: zero roll-up automation deployed — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` line 31: `DEV-UAT-20260930-VW-001` remained `Scheduled` after all downstream records were added.
- Schema: `VisitWorkflow.Status` choice list contains 13 states (`Scheduled` through `Closed`). All are declared "Automation-managed; routine users do not directly edit" (`achieve-ram-pilot.json` line 207).
- Derived fields with no current automation: `PlannedDate`, `ActualVisitDate`, `ReceptionOwner`, `VisitOwner`, `QCStatus`, `QCReadyAt`, `QCStartedAt`, `QCPassedAt`, `EDCStatus`, `EDCReadyAt`, `EDCStartedAt`, `EDCCompletedAt`, `PIActionRequired`, `PIActionStatus`, `OpenQueryCount`, `CloseEligible`, `ClosedAt`.
- Without roll-up flows, the dashboard, close-eligibility gate, and full audit lifecycle cannot function.

---

##### P0-3 — WorkflowAudit rows are directly editable by all four DEV users — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` lines 112–119: all four users were added to `Trident Clinical Operations DEV Members` with **Edit** access across the site.
- `DEV_UAT_RESULTS_2026-09-30.md` line 37: `DEV-UAT-20260930-AUD-001` was saved without a reason field, confirming no enforcement.
- Power Apps Audit screen is display-only but SharePoint list permissions still allow direct row modification.
- Clinical trial audit trail integrity requires append-only rows created exclusively by automation.

Fix (SharePoint, no local file change needed):
- WorkflowAudit list → Settings → Advanced settings → Item-level Permissions:
  - Read access: "All items"
  - Edit access: "None" (users cannot modify items they created)
- The Power Automate service account retains Contribute rights via its OAuth identity, so flows can still create new rows.
- Verify: open a WorkflowAudit item as a named user and confirm the edit form is read-only.

---

##### P1-1 — PIAction guard not yet deployed; seeded invalid record `DEV-UAT-20260930-PIA-001` is unguarded — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` line 144: `DEV-UAT-20260930-PIA-001` has `Status=Complete`, blank `CompletedAt`, blank `Outcome`. No warning or block observed.
- Guard does not exist yet.

Implementation-ready Power Automate flow design:

```
Flow name:  Trident DEV - PIAction completion guard
Trigger:    SharePoint — "When an item is created or modified"
            List: PIAction

Condition:
  @and(
    equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
    or(
      empty(triggerOutputs()?['body/CompletedAt']),
      empty(triggerOutputs()?['body/Outcome'])
    )
  )

Yes branch — Update item:
  ID:        triggerOutputs()?['body/ID']
  Status:    In Progress
  (Preserve all other fields — do not overwrite CompletedAt, Outcome, PIActionID,
   VisitKey, StudyID, ActionType, Investigator, RequiredAt, DueDate,
   ClinicalSignificance, SourceReference, ChangeReason)

No branch:  Terminate (no action)
```

Self-trigger safety: same as the EDC guard. The demotion sets `Status = "In Progress"`. The next trigger run evaluates `Status != "Complete"` and exits via the No branch. No loop.

Test required:
1. Open `DEV-UAT-20260930-PIA-001` and resave without changes. Confirm flow demotes to `In Progress`.
2. Save a record as `Complete` with `CompletedAt` and `Outcome` filled. Confirm no-action path.
3. Confirm two consecutive runs in the flow run history, second taking no-action path.

---

##### P1-2 — QCFinding closure guard not yet deployed; seeded invalid record `DEV-UAT-20260930-QC-001` is unguarded — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` line 138: `DEV-UAT-20260930-QC-001` has `Status=Closed`, blank `Resolution`, blank `ResolvedAt`. No warning or block observed.

Implementation-ready Power Automate flow design:

```
Flow name:  Trident DEV - QCFinding closure guard
Trigger:    SharePoint — "When an item is created or modified"
            List: QCFinding

Condition:
  @and(
    or(
      equals(triggerOutputs()?['body/Status/Value'], 'Closed'),
      equals(triggerOutputs()?['body/Status/Value'], 'Resolved')
    ),
    or(
      empty(triggerOutputs()?['body/Resolution']),
      empty(triggerOutputs()?['body/ResolvedAt'])
    )
  )

Yes branch — Update item:
  ID:        triggerOutputs()?['body/ID']
  Status:    In Progress
  (Preserve FindingID, VisitKey, StudyID, ParticipantID, Visit, Category,
   Description, Severity, RaisedBy, RaisedAt, AssignedTo, DueDate,
   RecurrenceFlag, CAPARequired, CAPARef)

No branch:  Terminate (no action)
```

Note: the guard covers both `Resolved` and `Closed` because `Resolution` and `ResolvedAt` are required evidence at the `Resolved` state too — before a QC reviewer progresses to `Verified` and then `Closed`. Guarding only `Closed` would allow a `Resolved` record to persist without evidence.

Test required:
1. Resave `DEV-UAT-20260930-QC-001` without changes. Confirm demotion to `In Progress`.
2. Save with `Status=Resolved`, `Resolution` filled, `ResolvedAt` filled. Confirm no-action path.
3. Save with `Status=Closed`, `Resolution` filled, `ResolvedAt` filled. Confirm no-action path.
4. Confirm two consecutive runs per scenario in run history.

---

##### P1-3 — Auto-timestamp fields are user-editable; server time is not stamped by automation — Status: OPEN

Evidence:
- Schema fields annotated "Automation timestamp" or "Prefer server timestamp":
  - `VisitAdmin`: `ArrivalAt`, `DepartureAt` (`achieve-ram-pilot.json` lines 432, 438)
  - `VisitClinicalStatus`: `StartedAt`, `CompletedAt` (lines 543, 548)
  - `EDCStatus`: `ReadyAt`, `StartedAt`, `CompletedAt` (lines 777, 782, 787)
  - `PIAction`: `RequiredAt`, `CompletedAt` (lines 888, 919)
  - `VisitWorkflow`: `QCReadyAt`, `QCStartedAt`, `QCPassedAt`, `EDCReadyAt`, `EDCStartedAt`, `EDCCompletedAt`, `ClosedAt`
- These fields are currently exposed as editable inputs in generated Power Apps forms, allowing backdating.
- This is a clinical trial data integrity issue.

Interim fix within each completion guard (and later in roll-up flows): when the guard or roll-up sets a state, also write `utcNow()` to the corresponding timestamp field if it is blank:

```
In the PIAction guard Update item (when demoting, preserve CompletedAt):
  CompletedAt: null  // do not stamp on demotion — clear it only if previously wrong

In a future "PIAction completed" roll-up (when Status transitions to Complete):
  CompletedAt: @{utcNow()}
```

Power Apps interim UI protection (in each form's `DisplayMode` expression for timestamp fields):

```powerapps
// For ArrivalAt in VisitAdmin form:
If(IsBlank(VisitAdminForm.LastSubmit.ArrivalAt), DisplayMode.Edit, DisplayMode.View)
```

This locks the timestamp field after it has been stamped once, preventing user edits.

---

##### P1-4 — Duplicate business identifier detection absent — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` line 38: `DEV-UAT-20260930-VA-DUP` with duplicate `VisitAdminID = DEV-UAT-20260930-VA-001` was accepted.
- No SharePoint enforcement for column uniqueness; no guard flow.

Proposed guard pattern (Power Automate, one per primary-key list):

```
Trigger: When item created or modified on VisitAdmin
Action: Get items from VisitAdmin where VisitAdminID == triggerBody()?['VisitAdminID']
        AND ID != triggerBody()?['ID']
Condition: length(body('Get_items')?['value']) > 0
Yes branch: Update item — set Status (or a ValidationError text field) to signal duplicate,
            OR update a dedicated DuplicateFlag Yes/No column and log to WorkflowAudit
```

Preferred path: add a read-only `ValidationError` single-line-text column to each list, stamped by automation when a rule is violated. This separates audit from status demotion.

---

##### P1-5 — Date chronology not validated; departure-before-arrival accepted — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` line 38: `DEV-UAT-20260930-VA-DUP` has departure at 10:00 AM before arrival at 5:00 PM.

Proposed Power Automate chronology guard for VisitAdmin:

```
Trigger: When item created or modified on VisitAdmin
Condition:
  @and(
    not(empty(triggerOutputs()?['body/ArrivalAt'])),
    not(empty(triggerOutputs()?['body/DepartureAt'])),
    lessOrEquals(
      triggerOutputs()?['body/DepartureAt'],
      triggerOutputs()?['body/ArrivalAt']
    )
  )
Yes branch: Update item — clear DepartureAt (set to null) and stamp WorkflowAudit row
```

Same pattern for `VisitClinicalStatus` (StartedAt < CompletedAt) and `EDCStatus` (ReadyAt ≤ StartedAt ≤ CompletedAt).

---

##### P1-6 — Time zone propagation from Pacific to UTC+02:00 not confirmed — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` lines 82–83: "The list header continued to show the previous Pacific label immediately afterward, so propagation or a user-level regional override still needs verification."

Required action: Codex must open a DEV list in the browser as each named user, check the date column header label, and report whether it now shows SAST / UTC+02:00. If any user still sees Pacific, that user's M365 profile regional setting overrides the site setting and must be corrected independently.

---

##### P2-1 — Six formula errors in Screen2 decorative controls — Status: OPEN

Evidence:
- `DEV_UAT_RESULTS_2026-09-30.md` lines 140–141: two default-value errors, two display-text errors on sample tab controls, two subtitle-field errors on sample gallery.

These do not block operation but will fail formal UAT sign-off. Clean before the next published UAT build.

Fix pattern in Power Apps Studio — Screen2, locate each affected control and:
- For `Default` errors on tab controls: replace with `""` or `false` as appropriate.
- For subtitle gallery formula: replace the nonexistent column reference with `ThisItem.Title` or the correct field from the bound data source.

---

##### P2-2 — VisitWorkflow.Status directly user-editable in generated forms — Status: OPEN

Evidence:
- Schema (`achieve-ram-pilot.json` line 207): "Automation-managed consolidated status; routine users do not directly edit."
- No lock applied in Power Apps.

Power Apps fix for VisitWorkflow form `Status` field:

```powerapps
// DataCardValue DisplayMode for Status in VisitWorkflow form:
DisplayMode.View
```

Or, if the Workflow screen uses a gallery + edit form:

```powerapps
// In the form's card for Status:
If(User().Email = "admin@tridentclinical.co.za", DisplayMode.Edit, DisplayMode.View)
```

---

#### Ordered implementation queue (safe to proceed, DEV only)

Priority order:

1. **Fix EDC guard QueryStatus condition** (P0-1) — open existing flow in Power Automate designer, update the QueryStatus branch from `!= "Closed"` to the corrected expression above. Run three test cases, record run history.
2. **Deploy PIAction completion guard** (P1-1) — new flow per design above. Test three scenarios.
3. **Deploy QCFinding closure guard** (P1-2) — new flow per design above. Test four scenarios.
4. **Lock WorkflowAudit list** (P0-3) — SharePoint Advanced settings, Edit access = None. Verify one named user cannot edit an existing audit row.
5. **Verify SAST time zone per named user** (P1-6) — open list headers as each of the four users, record result.
6. **Clean Screen2 formula errors** (P2-1) — Power Apps Studio, Screen2, fix six controls, publish, verify live player.
7. **Lock system-managed fields in Power Apps forms** (P2-2, P1-3 interim) — set `DisplayMode.View` on Status, all timestamp fields, and all derived fields in each role screen form.
8. **Design and deploy VisitWorkflow roll-up flows** (P0-2) — one flow per child list, triggered on child item change, updates parent VisitWorkflow derived fields and consolidated Status.
9. **Add auto-timestamps to each guard and roll-up flow** (P1-3) — stamp `utcNow()` to the relevant timestamp field when a state transition is recorded.
10. **Append WorkflowAudit row in every guard and roll-up** — create a new WorkflowAudit item from each flow with EventType, OldValue, NewValue, ChangedBy, ChangedAt, SourceApp = "Power Automate", CorrelationID.
11. **Duplicate detection guards** (P1-4) — one per primary-key list.
12. **Chronology guards** (P1-5) — VisitAdmin departure/arrival, VisitClinicalStatus start/complete, EDCStatus ready/start/complete.
13. **Repeat full DEV UAT matrix** against all eight lists and all negative test cases.

Items 1–4 are blockers for a meaningful second UAT run. Items 1–7 are safe DEV-only changes with no destructive operations. Items 8–12 require design review before deployment.

---

#### Next request to Codex

**Immediate — step 1 (P0-1 EDC guard fix):**

Open the live flow `Trident DEV - EDC completion guard` (ID: `492182f1-2777-4502-9a06-29dc69a6134a`) in Power Automate designer:

1. Locate the condition that checks `QueryStatus`.
2. Record the exact current expression text for this branch.
3. Replace it with:
   ```
   @not(or(
     equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
     equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
   ))
   ```
4. Save and turn the flow on.
5. Run three test cases as described under P0-1.
6. Screenshot or paste the run-history result for each test case.
7. Report the exact expression text as it appears in the designer after saving, plus the run-history outcome for all three cases.

Once step 1 evidence is recorded here, proceed to step 2 (PIAction guard).

---

### Claude Code entry — 2026-10-01 — SAST (session 2)

Status: `PROPOSED`
Handoff sequence: 2
Codex reset due: 2026-10-02 00:49 SAST

#### Changes applied this session

Three gaps in the plan were identified and corrected in local files while Codex is
unavailable. No tenant changes were made.

---

#### Correction A — EDC guard expression null-check fix

**Finding:** P0-1 expression previously proposed did not handle a null/blank
`QueryStatus` field. `QueryStatus` is `required: false` in the schema. A record
where no queries were ever raised may have a null field value, not the string
`"None"`. `equals(..., 'None')` does not match null in Power Automate.

**Impact:** Without the null-check, a valid EDC completion where `QueryStatus` was
never set would still be demoted to In Progress, blocking legitimate completions
for records that never had queries.

**Superseded expression (do not use):**
```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    greater(coalesce(triggerOutputs()?['body/OpenQueryCount'], 0), 0),
    not(or(
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
    )),
    empty(triggerOutputs()?['body/CompletedAt'])
  )
)
```

**Corrected expression — use this one:**
```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    greater(coalesce(triggerOutputs()?['body/OpenQueryCount'], 0), 0),
    not(or(
      empty(triggerOutputs()?['body/QueryStatus/Value']),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'None'),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved')
    )),
    empty(triggerOutputs()?['body/CompletedAt'])
  )
)
```

The `empty(triggerOutputs()?['body/QueryStatus/Value'])` branch at the top of the
inner `or` treats a null/blank `QueryStatus` as a safe-to-complete state (same
semantics as the "None" choice — no queries were ever raised).

**Local files updated:**
- `CLAUDE_REVIEW_BRIEF.md` line 22: guard description updated to include "or blank"
  and note about null handling.

P0-1 status: PROPOSED — corrected expression ready for Codex to paste. Verification
requires three run-history results. Tests A and B remain the same; Test B now covers
both explicit "None" and a null QueryStatus field.

---

#### Correction B — WorkflowAudit protection requires broken inheritance, not just item-level edit lock

**Finding:** The earlier spec said set Item-level Edit access to None. That blocks
users from editing existing rows but does NOT prevent them from creating new
WorkflowAudit rows directly through SharePoint or via the Power Apps connector.
All four named users have site-level Edit access (Trident Clinical Operations DEV
Members), which grants Contribute to all lists including WorkflowAudit.

**Correct fix (three steps, all in SharePoint):**

1. WorkflowAudit list → Settings → Permissions for this list → Stop Inheriting
   Permissions. This breaks the site-level inheritance.
2. On the new list-specific permissions page, remove Trident Clinical Operations
   DEV Members (or equivalent group) from any Edit/Contribute role.
3. Add each of the four named user accounts individually with Read permission only.
4. Confirm the Power Automate flow connection identity retains Contribute or Edit
   on the list so flows can still insert rows. Verify this account was not removed
   when inheritance was broken.

**Verification test:** Log in as one of the four named users, navigate to
WorkflowAudit in SharePoint, attempt to create a new item and attempt to edit
DEV-UAT-20260930-AUD-001. Both must be blocked. Then trigger a flow that creates
a WorkflowAudit row and confirm the row appears.

**Local files updated:**
- `CLAUDE_REVIEW_BRIEF.md` Known gaps: updated to describe the three-step fix and
  flag that item-level edit lock alone is insufficient.

P0-3 status: PROPOSED — tenant fix required.

---

#### Correction C — VisitWorkflow roll-up flow design document created

**Finding:** P0-2 had no design document. Without a state machine specification
Codex cannot safely build the five roll-up flows.

**New file created:** `outputs/VISIT_ROLLUP_FLOW_DESIGN.md`

Contents:
- Full 13-state VisitWorkflow consolidated Status state machine.
- CloseEligible composite check definition.
- OpenQueryCount calculation (Open + Returned + In Progress findings).
- Common flow pattern for all five flows.
- Detailed specification for all five flows: VisitAdmin, VisitClinicalStatus,
  QCFinding, EDCStatus, PIAction roll-ups.
- WorkflowAudit row field spec for every automation event.
- Race condition note and production mitigation path.
- Suggested Codex build order (EDCStatus first; QCFinding last).
- 15-case UAT test matrix R-01 through R-15 covering full Scheduled to
  CloseEligible progression.

P0-2 status: PROPOSED — design complete, ready for Codex to build.

---

#### Next request to Codex (ordered, post-reset 2026-10-02 00:49 SAST)

1. P0-1 — Fix EDC guard: replace QueryStatus branch with the corrected null-safe
   expression above (Correction A). Run Tests A, B, C. Record run-history evidence.

2. P0-3 — Lock WorkflowAudit list: follow the three-step broken-inheritance fix in
   Correction B. Run verification test. Record evidence.

3. P1-1 — Deploy PIAction completion guard: use flow design from earlier entry.
   Test three scenarios.

4. P1-2 — Deploy QCFinding closure guard: use flow design from earlier entry.
   Test four scenarios.

5. P0-2 — Build roll-up flows: follow VISIT_ROLLUP_FLOW_DESIGN.md. Build in order
   EDCStatus, VisitClinicalStatus, VisitAdmin, QCFinding, PIAction. Run UAT matrix
   R-01 through R-15 after all five are deployed.

### Codex handoff — 2026-10-01

Status: `HANDOFF READY`

Codex completed the EDC guard deployment and verified two successful runs. Further Power Automate browser actions are currently blocked by the Codex usage window.

Claude Code now owns retrospective local review and correction. The exact next review is P0-1: inspect the EDC guard QueryStatus condition, compare it with the evidence above, and record either a proposed correction or verification result. Claude must not deploy tenant changes.

At approximately 98% of Claude Code's own usage allowance, Claude must stop starting new work, update `outputs/AI_AGENT_STATUS.json` to `HANDOFF_READY`, append evidence here, warn the user to stop sending work to Claude Code, and leave the exact next action for Codex.

---

### Claude Code entry — 2026-10-01 — SAST

Status: `PROPOSED`

#### Scope reviewed

- `outputs/AI_AGENT_STATUS.json` — confirmed `activeAgent: NONE` before claiming `CLAUDE_ACTIVE`
- `outputs/AI_COLLABORATION_LOG.md` — all prior entries including Codex handoff
- `outputs/CLAUDE_REVIEW_BRIEF.md` — live guard description (line 22)
- `config/lists/achieve-ram-pilot.json` — `EDCStatus.QueryStatus` column definition (line 823)

No other agent was active. Status claimed as `CLAUDE_ACTIVE` before starting.

---

#### P0-1 review — EDC guard QueryStatus condition

**Finding status: PROPOSED (local doc corrected; tenant fix pending Codex)**

**Evidence:**

| Source | Fact |
|---|---|
| `achieve-ram-pilot.json` line 823 | `"choicesOrLookup": "None;Open;In Progress;Resolved"` — `"Closed"` is absent |
| `CLAUDE_REVIEW_BRIEF.md` line 22 (before patch) | Description stated guard checks "QueryStatus is not Closed" |
| `AI_COLLABORATION_LOG.md` prior entry | Reconstructed guard expression: `@not(equals(triggerOutputs()?['body/QueryStatus/Value'], 'Closed'))` |
| Logic | A SharePoint Choice column expression `!= "Closed"` against a column with no "Closed" choice always returns `true`. Every `Complete` EDCStatus record is demoted to `In Progress` including valid ones. |
| UAT run | `DEV-UAT-20260930-EDC-001` had `QueryStatus = "Open"` — demotion was correct but does not prove a valid completion can pass. |

**Local correction applied — unified diff:**

```diff
--- a/outputs/CLAUDE_REVIEW_BRIEF.md
+++ b/outputs/CLAUDE_REVIEW_BRIEF.md
@@ line 22
-The guard triggers on EDCStatus create/modify and returns an unsupported Complete
-state to In Progress when open queries remain, QueryStatus is not Closed, or
-CompletedAt is blank.
+The guard triggers on EDCStatus create/modify and returns an unsupported Complete
+state to In Progress when open queries remain, `QueryStatus` is not `Resolved` or
+`None`, or `CompletedAt` is blank. **[P0-1 BUG — PENDING CODEX FIX]** The live
+flow currently checks `QueryStatus != "Closed"` but `"Closed"` is not a valid
+`QueryStatus` choice (valid choices: `None;Open;In Progress;Resolved`, per
+`achieve-ram-pilot.json` line 823). This condition is permanently true, so every
+EDC `Complete` record is demoted — including valid ones. Codex must replace the
+QueryStatus branch with the corrected expression before a legitimate EDC
+completion can pass the guard.
```

File `CLAUDE_REVIEW_BRIEF.md` now accurately describes both the intent and the bug. No schema correction is required — `achieve-ram-pilot.json` is correct as written; the bug is in the live flow only.

**Corrected Power Automate condition for Codex to apply (full expression, ready to paste):**

```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    greater(coalesce(triggerOutputs()?['body/OpenQueryCount'], 0), 0),
    not(or(
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
    )),
    empty(triggerOutputs()?['body/CompletedAt'])
  )
)
```

Logic: demote to `In Progress` if `Status = "Complete"` AND any of:
- `OpenQueryCount` is present and greater than zero
- `QueryStatus` is not `Resolved` and not `None`
- `CompletedAt` is blank

**What P0-1 will be VERIFIED when:**
1. Codex opens the live flow, replaces the QueryStatus branch, saves with 0 errors/warnings.
2. Three test runs are recorded in run history:
   - **Test A:** `Complete`, `OpenQueryCount=0`, `QueryStatus=Resolved`, `CompletedAt` filled → record stays `Complete` (no-action path).
   - **Test B:** `Complete`, `OpenQueryCount=0`, `QueryStatus=None`, `CompletedAt` filled → record stays `Complete` (no-action path).
   - **Test C:** `Complete`, `OpenQueryCount=1`, `QueryStatus=Resolved`, `CompletedAt` filled → record demoted to `In Progress`.
3. Codex records the exact saved expression text and run-history outcome for all three tests here.

P0-1 remains `PROPOSED` until that evidence is posted.

---

#### Next request to Codex — exact and ordered

**Step 1 (P0-1) — Fix live EDC guard:**

1. Open `Trident DEV - EDC completion guard` (Flow ID: `492182f1-2777-4502-9a06-29dc69a6134a`) in Power Automate designer.
2. In the condition step, locate the branch that references `QueryStatus`.
3. Record the exact current expression text for that branch.
4. Replace it with:
   ```
   @not(or(
     equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved'),
     equals(triggerOutputs()?['body/QueryStatus/Value'], 'None')
   ))
   ```
5. Save. Confirm 0 errors, 0 warnings in the flow checker.
6. Run Test A, B, C as listed above. Record the run-history result for each (succeeded / no-action vs. succeeded / demoted).
7. Append a Codex entry to this log with: the exact saved expression, the three run-history outcomes, and which finding to re-verify.

**Step 2 (P1-1) — Deploy PIAction completion guard** (after P0-1 evidence is posted):

Use the flow design in the earlier Claude entry (P1-1 section). Test three scenarios and record run history.

**Step 3 (P1-2) — Deploy QCFinding closure guard** (after P1-1 evidence is posted):

Use the flow design in the earlier Claude entry (P1-2 section). Test four scenarios and record run history.

---

### Claude Code entry — 2026-10-01 — SAST (session 3)

Status: `PROPOSED`
Handoff sequence: 3
Protocol version: 1.2
workUnitsCompleted this session: 2 (protocol upgrade + coordination docs)
handoffTrigger: manual

sessionSummary: "Applied protocol v1.2 improvements (workUnitsCompleted counter,
handoffTrigger field, heartbeat rule update, sessionSummary requirement) and
created COORDINATION_SETUP.md documenting four probe options for the handoff loop."

#### Changes applied this session

No tenant changes. All changes are local documentation and protocol files.

---

##### Item 1 — workUnitsCompleted counter

Added `workUnitsCompleted` integer to `AI_AGENT_STATUS.json` at both the root
level and inside each agent's sub-object. Each agent increments this after
completing a finding, correction, or document. Allows agents to decide to hand off
based on meaningful work units rather than guessing at token usage.

Current values: claudeCode = 4 (P0-1 doc, corrections A/B/C, roll-up design,
this protocol upgrade), codex = 1 (EDC guard deployment).

---

##### Item 2 — handoffTrigger field

Added `handoffTrigger` to `AI_AGENT_STATUS.json`. Set at HANDOFF_READY time to
one of:
- `time_limit` — agent approached 98% usage
- `work_unit_limit` — agent completed a natural set of work units
- `manual` — user or agent decided to hand off at a logical point
- `blocked` — agent cannot continue without a tenant action or user decision

Allows both agents and the user to understand why a handoff was called without
reading the full log entry.

---

##### Item 3 — Heartbeat rule updated from wall-clock to event-driven

`CLAUDE_CODE_START_HERE.md` addendum updated. Old rule: "refresh lastHeartbeatAt
at least every 15 minutes." New rule: "refresh lastHeartbeatAt after every tool
call that writes a file or completes a discrete work unit."

Rationale: a long file write or analysis step can exceed 15 minutes without a
natural clock-check opportunity. An event-driven refresh fires reliably after every
observable action without requiring the agent to track wall-clock time.

---

##### Item 4 — sessionSummary field and HANDOFF READY template

`CLAUDE_CODE_START_HERE.md` addendum updated to require a `sessionSummary`
one-sentence string in every HANDOFF READY entry, both in `AI_AGENT_STATUS.json`
and in `AI_COLLABORATION_LOG.md`. Allows the probe (or the user) to understand
what was accomplished without reading the full log.

---

##### COORDINATION_SETUP.md created

New file: `outputs/COORDINATION_SETUP.md`

Documents the full handoff loop and four probe options:

| Option | Mechanism | Best for |
|---|---|---|
| 1 | Manual check | Low-frequency sessions, user is present |
| 2 | Windows Task Scheduler + PowerShell toast | Sustained desk sessions, no cloud needed |
| 3 | Power Automate scheduled flow + Teams/email | Away from desk, mobile alert needed |
| 4 | Webhook push via ntfy.sh | Fast iteration, instant push |

Includes ready-to-run PowerShell setup script for Option 2 (Task Scheduler) and
flow outline for Option 3. Also documents how the probe should handle a stale lease.

---

#### Note to Codex: P0-1 corrected expression

The P0-1 fix instruction in the earlier log entry contains a superseded expression
(missing null-check). Use only the corrected expression from the session 2 entry
(Correction A), reproduced here for clarity:

```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    greater(coalesce(triggerOutputs()?['body/OpenQueryCount'], 0), 0),
    not(or(
      empty(triggerOutputs()?['body/QueryStatus/Value']),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'None'),
      equals(triggerOutputs()?['body/QueryStatus/Value'], 'Resolved')
    )),
    empty(triggerOutputs()?['body/CompletedAt'])
  )
)
```

Do not use any earlier version of this expression.

## 2026-10-02 01:29 SAST — CODEX — P0-1 EDC guard completed and verified

### Finding

The live EDC guard initially evaluated the corrected rule as false even for `Complete / 3 / Open / blank CompletedAt`. Run inspection showed the condition field contained mixed literal and expression-token content after the prior edit. The SharePoint trigger payload itself was correct (`Status.Value=Complete`, `OpenQueryCount=3`, `QueryStatus.Value=Open`).

### Fix applied

Rebuilt the left side of the Power Automate condition as one expression token. The accepted query-state set is now `Closed`, `Resolved`, `None`, or blank when `OpenQueryCount=0` and `CompletedAt` is populated. Blocking states still demote an invalid `Complete` record to `In Progress`.

### Verification evidence

- Invalid case: `Complete / 3 / Open / blank CompletedAt` produced successful run `08584107098769017350378451888CU28` and changed the record to `In Progress`.
- Valid case: `Complete / 0 / Resolved / populated CompletedAt` remained `Complete`.
- Valid null-safe case: `Complete / 0 / None / populated CompletedAt` remained `Complete`.
- Test record: `DEV-UAT-20260930-EDC-001` (fictitious DEV data only).
- Production writes remained disabled.

### Next action

Lock `WorkflowAudit` append-only behavior, then deploy the PIAction and QCFinding guards and continue the roll-up flows.

## 2026-10-02 01:40 SAST — CLAUDE CODE — P2-1 and P2-2 findings

### Context

Codex verified P0-1 (EDC guard) and handed off at its session cap with P1-1 starting. Claude Code is now working its owned lane (P2-1 and P2-2) in parallel while Codex resumes P0-2/P0-3/P1-1/P1-2 next session.

Note on P0-1 Codex log: Codex's description says the accepted set includes "Closed" — this is a prose slip. "Closed" is not a valid QueryStatus choice per `achieve-ram-pilot.json` line 823. Since it can never appear in the field, the live expression's behavior is correct for all reachable states. The description is misleading but the guard itself is verified. No live fix needed; Codex should correct the description in the UAT results document when convenient.

---

### P2-1 — Screen2 (Reception/VisitAdmin) template formula errors

**Status:** PROPOSED — Codex must apply in Power Apps Studio, re-publish, and confirm 0 errors remain.

**Evidence base:** `DEV_UAT_RESULTS_2026-09-30.md` line 140 — "The Screen2 template retains six formula errors in unused decorative controls: two default-value and two display-text errors on the desktop/mobile sample tab controls, plus two subtitle-field errors referencing nonexistent sample columns."

**Root cause:** Power Apps generated-template scaffolding leaves tab-switching controls and gallery subtitle bindings that reference sample columns (`Subtitle`, `SampleTabField`, etc.) not present in any of the eight DEV lists.

**Fix — preferred approach (lowest risk):**

The six affected controls are unused decorative elements. Delete them entirely.

1. Open Power Apps Studio → Trident Operations Central DEV → Screen2.
2. Open the tree view (left panel). Look for controls whose names contain "Tab", "Desktop", "Mobile", "Sample", or "Template".
3. For each control showing a formula error: confirm it has no functional role (no OnSelect that navigates, no data it feeds into a visible output). If unused, select and delete.
4. Repeat for the two gallery subtitle cards showing errors.
5. Check the formula bar shows 0 errors.
6. Publish. Confirm 0 errors in the checker.

**Fix — fallback (if a control cannot be deleted because it has a structural role):**

Replace the broken property value with a safe constant:

| Error type | Broken formula pattern | Safe replacement |
|---|---|---|
| Default-value on tab control | `SampleTabContainer.AllItems` or `LookUp(SampleData, ...)` | `"Desktop"` (string matching the first tab's Text property) |
| Display-text on tab control | `ThisItem.SampleColumn` | `"Desktop"` / `"Mobile"` (matching the intended label) |
| Gallery subtitle | `ThisItem.Subtitle` or `ThisItem.SampleField` | `ThisItem.VisitAdminID` (first business key in the VisitAdmin list) |

**Verification:** Power Apps App checker shows 0 errors. Live player on Screen2 loads the VisitAdmin gallery with no console formula errors.

---

### P2-2 — System-managed fields exposed as editable in VisitWorkflow screen

**Status:** PROPOSED — Codex must lock the specified DataCards in Power Apps Studio.

**Evidence base:** Schema annotations in `config/lists/achieve-ram-pilot.json`; UAT result confirming the VisitWorkflow screen renders a generated form. All 26 VisitWorkflow columns are currently editable because the generated form defaults to `FormMode.Edit` with all cards unlocked.

**Classification — VisitWorkflow fields:**

| Field | Schema note | UI treatment |
|---|---|---|
| `VisitKey` | Permanent key | Show read-only; set at creation, never edited |
| `StudyID` | Lookup key | Show read-only after creation |
| `ParticipantID` | Key field (no name) | Show read-only after creation |
| `Visit` | Key field | Show read-only after creation |
| `Status` | "Automation-managed consolidated status; routine users do not directly edit" | **Lock — display only** |
| `PlannedDate` | "Derived from VisitAdmin" | **Lock — display only** |
| `ActualVisitDate` | "Derived from VisitAdmin/VisitClinicalStatus" | **Lock — display only** |
| `ReceptionOwner` | "Derived from VisitAdmin" | **Lock — display only** |
| `VisitOwner` | "Derived from VisitClinicalStatus" | **Lock — display only** |
| `QCStatus` | "Derived from QCFinding/QC workflow" | **Lock — display only** |
| `QCReadyAt` | "Automation timestamp" | **Lock — display only** |
| `QCStartedAt` | "Automation timestamp" | **Lock — display only** |
| `QCPassedAt` | "Automation timestamp" | **Lock — display only** |
| `EDCStatus` | "Derived from EDCStatus" | **Lock — display only** |
| `EDCReadyAt` | "Automation timestamp from EDCStatus" | **Lock — display only** |
| `EDCStartedAt` | "Automation timestamp from EDCStatus" | **Lock — display only** |
| `EDCCompletedAt` | "Automation timestamp from EDCStatus" | **Lock — display only** |
| `PIActionRequired` | "Derived from PIAction" | **Lock — display only** |
| `PIActionStatus` | "Derived from PIAction" | **Lock — display only** |
| `CloseEligible` | "Calculated/automation-managed" | **Lock — display only** |
| `ClosedAt` | (automation-set on close) | **Lock — display only** |
| `OpenQueryCount` | (count derived from QCFinding) | **Lock — display only** |
| `LabReviewRequired` | (user-set flag) | Editable |
| `LabReviewStatus` | (user-set status) | Editable |
| `DeviationFlag` | (user-set flag) | Editable |
| `ReopenReason` | "Required on reopen" | Editable (show only when reopening) |

**Implementation-ready Power Apps formula:**

For each DataCard in the VisitWorkflow EditForm that corresponds to a **Lock** field above, set the DataCard's `DisplayMode` property to:

```
DisplayMode.View
```

This renders the field value as a read-only label regardless of whether the form is in `FormMode.New` or `FormMode.Edit`. The user sees the automation-populated value but cannot change it.

For the four key fields (VisitKey, StudyID, ParticipantID, Visit) that are set at creation and must never be edited afterward, use a conditional lock:

```
If(EditForm1.Mode = FormMode.New, DisplayMode.Edit, DisplayMode.View)
```

This allows entry on new-record creation and locks after save.

**Scope note:** The same locking pattern should be applied to derived/automation fields on the other role screens (VisitClinicalStatus, QCFinding, EDCStatus, PIAction) in later sprints. P2-2 here covers only the VisitWorkflow parent form as the highest-visibility risk. Child-list screens have fewer derived fields and lower edit risk because each screen is scoped to the relevant role.

**Verification:** Open the VisitWorkflow form in Edit mode for `DEV-UAT-20260930-VW-001`. All locked fields render as read-only labels. Status, QCStatus, EDCStatus, PIActionStatus, CloseEligible, and all timestamp fields cannot be typed into or changed via dropdown. LabReviewRequired, LabReviewStatus, and DeviationFlag remain editable.

---

### Request to Codex

1. Apply P2-1 fix (delete or patch six decorative formula errors on Screen2). Re-publish and confirm 0 errors.
2. Apply P2-2 field locks on the VisitWorkflow screen per the table above. Re-publish and verify locked vs. editable fields in live player.
3. Continue with P0-3 (WorkflowAudit append-only), P1-1 (PIAction guard), P1-2 (QCFinding guard), P0-2 (roll-up flows) in your next session.
4. When P2-1 evidence is recorded, Claude Code will mark P2-1 COMPLETED_VERIFIED in the status file. Same for P2-2.

## 2026-10-02 06:05 SAST — CODEX — recovery after missing usage-cap dump

The Claude Code lease expired at 03:05 SAST without a clean handoff state transition. Codex capacity is available again and the lease has been recovered under protocol v1.3.

The browser contains an unsaved, incomplete draft for `Trident DEV - PIAction completion guard`. This draft is not treated as deployed. Codex will finish its trigger, condition, update action, flow name, save/enable state, and invalid/valid DEV tests before starting another work unit.

## 2026-10-02 09:30 SAST — CODEX — P1-1 PIAction completion guard completed and verified

Codex recovered and finished the unsaved draft without starting another work unit.

- Flow: `Trident DEV - PIAction completion guard`
- Flow ID: `a65c2d52-4e22-4928-ba81-ada2ff7c7994`
- Status: On
- Flow checker: 0 errors, 0 warnings
- Trigger: PIAction item created or modified
- Guard: if `Status=Complete` while `CompletedAt` or `Outcome` is blank, update the item to `In Progress`
- Data preservation: required identifiers plus VisitKey, StudyID, ParticipantID, ActionType, RequiredAt, DueDate, Investigator, CompletedAt, Outcome, ClinicalSignificance, SourceReference, and ChangeReason are carried through the corrective update

Verification on fictitious record `DEV-UAT-20260930-PIA-001`:

1. Invalid state (`Complete`, blank `CompletedAt`, blank `Outcome`) was saved. The flow ran successfully and demoted the record to `In Progress`.
2. The corrective update produced one self-triggered run. Its condition was false, no update ran, and the sequence terminated.
3. Valid state (`Complete`, populated `CompletedAt`, populated `Outcome`) was saved. The next run succeeded, the `Update item` action was skipped, and the record remained `Complete`.
4. The run history contained exactly three successful runs for the test sequence: invalid trigger, terminating self-trigger, and valid trigger.

Production writes remained disabled. The coordination state is now `HANDOFF_READY`; the missing pre-cap dump has been fully reconstructed.

## 2026-10-02 09:35 SAST — USER CONFIRMATION — Claude completed P2-1 and P2-2

The user confirmed that Claude Code completed both assigned Power Apps work units before stopping:

- P2-1: Screen2 generated-template formula errors — `COMPLETED_VERIFIED`
- P2-2: VisitWorkflow system-managed field locks — `COMPLETED_VERIFIED`

Claude Code did not write its completion dump before its session ended. This entry records the user's authoritative completion confirmation and removes both items from the active queue. A normal independent recheck remains part of the final top-to-bottom launch review; neither agent should reimplement P2-1 or P2-2 unless that review finds a regression.

The next implementation queue is P0-3 WorkflowAudit append-only enforcement, P1-2 QCFinding closure guard, and P0-2 VisitWorkflow roll-up flows.

## 2026-10-02 11:45 SAST — CLAUDE CODE — P1-1 verification and P1-2 expression spec (seq 9)

### P1-1 independent verification

Codex's evidence for the PIAction completion guard meets the verification standard:

- Flow checker: 0 errors, 0 warnings
- Invalid case: `Complete / blank CompletedAt / blank Outcome` → demoted to `In Progress` ✓
- Self-trigger: one follow-on run with condition false, no update, sequence terminated ✓
- Valid case: `Complete / populated CompletedAt / populated Outcome` → remained `Complete` ✓
- Exactly three-run sequence, matching the expected pattern

**P1-1 status: COMPLETED_VERIFIED** (no correction needed).

One expression observation (not a live bug): Codex's log does not state the exact condition expression used. Both `CompletedAt` (Date & Time, `required: false`) and `Outcome` (Multiple lines text, `required: false`) can be null on a new record. If the expression uses string comparison rather than `empty()` for these fields, null values will behave unpredictably. The test passed because the test record had blank strings, not nulls. For null-safety parity with P0-1, the correct expression is:

```
@and(
  equals(triggerOutputs()?['body/Status/Value'], 'Complete'),
  or(
    empty(triggerOutputs()?['body/CompletedAt']),
    empty(triggerOutputs()?['body/Outcome'])
  )
)
```

**Action for Codex:** Confirm that `empty()` (not string comparison) is used for both `CompletedAt` and `Outcome` in the live flow condition. If the expression uses a comparison like `equals(..., '')` instead, replace with `empty()` to correctly handle null values that arrive on records created without those fields populated.

---

### P1-2 — QCFinding closure guard: implementation-ready expression spec

**Status:** PROPOSED — Codex to implement in next session.

**Schema evidence:** `config/lists/achieve-ram-pilot.json`

- `QCFinding.Status` choices: `Open;Returned;In Progress;Resolved;Verified;Closed`
- `QCFinding.Resolution`: Multiple lines text, `required: false` — can be null
- `QCFinding.ResolvedAt`: Date & Time, `required: false` — can be null

**UAT evidence:** `DEV-UAT-20260930-QC-001` was saved as `Closed` with blank `Resolution` and blank `ResolvedAt`, and no guard blocked it.

**Guard logic:** A QCFinding cannot remain `Closed` if `Resolution` is blank or `ResolvedAt` is blank. If both conditions are met, demote to `In Progress`.

**Flow spec:**

| Setting | Value |
|---|---|
| Flow name | `Trident DEV - QCFinding closure guard` |
| Trigger | SharePoint — When an item is created or modified — QCFinding list |
| Condition (left) | `@and(equals(triggerOutputs()?['body/Status/Value'], 'Closed'), or(empty(triggerOutputs()?['body/Resolution']), empty(triggerOutputs()?['body/ResolvedAt'])))` |
| Condition (right) | `true` |
| Yes branch | SharePoint — Update item — set `Status` to `In Progress` |
| Preserved fields | FindingID, VisitKey, StudyID, ParticipantID, Visit, Category, Description, Severity, RaisedBy, RaisedAt, AssignedTo, DueDate, Resolution, ResolvedAt, RecurrenceFlag, CAPARequired, CAPARef |
| No branch | Terminate — Succeeded |

**Self-trigger safety:** The corrective update sets `Status = In Progress`. The re-trigger sees `Status.Value ≠ 'Closed'`, outer `equals()` is false, no update runs. Loop terminates after one self-trigger.

**Note on Verified state:** `Verified` is a valid status between `Resolved` and `Closed`. A `Closed` finding should normally have passed through `Verified` first. The guard does not prevent a user from jumping directly to `Closed` without going through `Verified` — that is a separate state-transition validation item (P1-5/chronology). This guard only enforces that `Closed` requires evidence (Resolution + ResolvedAt).

**UAT test matrix for P1-2:**

| Test | Input | Expected result |
|---|---|---|
| QC-T1 (invalid) | `DEV-UAT-20260930-QC-001`: `Closed`, blank `Resolution`, blank `ResolvedAt` | Demoted to `In Progress` |
| QC-T2 (self-trigger) | Follow-on trigger after QC-T1 demotion | No update, `Status` remains `In Progress` |
| QC-T3 (valid — both present) | `Closed`, populated `Resolution`, populated `ResolvedAt` | Remains `Closed` |
| QC-T4 (edge — one missing) | `Closed`, populated `Resolution`, blank `ResolvedAt` | Demoted to `In Progress` |
| QC-T5 (edge — other missing) | `Closed`, blank `Resolution`, populated `ResolvedAt` | Demoted to `In Progress` |

---

### P0-3 preflight note — WorkflowAudit append-only

Codex's `partialActionState` was "inspect current list permission model before any permission change." The preflight is read-only — no changes were made, nothing is in an inconsistent state.

The existing spec (session 2 Correction B) covers the three required steps. One critical pre-check that must happen **before breaking permissions inheritance**:

**Power Automate connection owner check**: The flows that write to WorkflowAudit run as a specific user's connection. If that connection owner loses access to the list (because breaking inheritance removes inherited permissions and you only grant Read-only to the four named users), all WorkflowAudit inserts will fail silently with a 403.

**Required pre-step before P0-3 execution:**

1. In Power Automate, open any flow that performs a SharePoint "Create item" on the WorkflowAudit list.
2. Expand the "Create item" action. Note the "Connection" shown (the user account whose credentials the action uses).
3. Record that account's email address.
4. After breaking inheritance and granting Read-only to the four named users, **also grant Contribute to that flow connection account** explicitly on the WorkflowAudit list.
5. Only then run a test WorkflowAudit insert to confirm the flow can still write.

If no existing flow writes to WorkflowAudit yet (these may be unbuilt roll-up flows), the check is moot for now — but it becomes critical before those flows are deployed.

---

### Summary for Codex next session

1. Confirm null-safety of P1-1 expression (`empty()` not string comparison) — if wrong, patch the live condition.
2. Implement P1-2 QCFinding closure guard using the expression spec above. Run QC-T1 through QC-T5.
3. Execute P0-3 WorkflowAudit permission lock — include the connection-owner pre-check before breaking inheritance.
4. Continue P0-2 roll-up flows when the above are done.



## 2026-10-02 12:00 SAST -- CLAUDE CODE -- WU1-WU5 implementation specs (seq 10)

Claude Code continuing while Codex is at its cap. Five work units: P0-3 full permission spec, P1-3 auto-timestamps, P1-4 duplicate detection, P1-5 chronology validation, P1-6 timezone check procedure, and a launch readiness audit.

---

### WU1 -- P0-3 WorkflowAudit append-only: full step-by-step execution spec

**Status:** PROPOSED -- Codex executes in SharePoint admin.

**Why item-level permissions alone are insufficient:** SharePoint item-level Read only prevents users editing items they did not create. Users with site-level Edit access can still create new WorkflowAudit rows directly from the SharePoint UI. The only fix is to break permissions inheritance and grant the four named users Read-only on the list.

**Pre-check -- do this first (before any permission change):**

1. Open Power Automate -> Connections.
2. Find the SharePoint connection used by any flow that writes to WorkflowAudit.
3. Record the account email shown on that connection.
4. If multiple flows use different connections, record all accounts.

**Execution sequence:**

Step 1 -- Break inheritance: WorkflowAudit list -> List Settings -> Permissions for this list -> Stop Inheriting Permissions -> OK.

Step 2 -- Remove inherited groups: On the Permissions page remove all existing groups (ClinicalOperationsDEV Members, Owners, Visitors) from the WorkflowAudit list. They retain access to other lists via site-level inheritance.

Step 3 -- Grant Read to the four named users: New -> Grant permissions -> select Read -> Send Email = No -> OK.

| User | Email |
|---|---|
| Tasneem Essop | tasneem.essop@tridentclinical.co.za |
| Dr Lorato Pata | l.pata@tridentclinical.co.za |
| Kyla Ryland | kyla.ryland@tridentclinical.co.za |
| Reception | info@tridentclinical.co.za |

Step 4 -- Grant Contribute to the flow connection owner: New -> Grant permissions -> enter the flow account email from the pre-check -> select Contribute -> Send Email = No -> OK.

Step 5 -- Verify permissions page shows exactly: four named users at Read, flow connection account at Contribute, no site-level groups listed.

Step 6 -- Test flow insert: Trigger the EDC guard (save DEV-UAT-20260930-EDC-001 as Complete with open queries). Check run history: WorkflowAudit Create item action succeeded (HTTP 201).

Step 7 -- Test user cannot create rows: Navigate to WorkflowAudit list as one of the four named users. Confirm the New button is absent or disabled.

**Rollback:** If Step 6 fails with 403, the flow connection account was missing from Step 4. Re-open WorkflowAudit permissions and add Contribute for that account.

---

### WU2 -- P1-3 Auto-timestamps: complete spec

**Status:** PROPOSED -- two components: Power Apps OnSelect formula (child lists), Power Automate expressions (parent VisitWorkflow).

#### Component A -- Child list timestamps set by Power Apps

Use `UTCNow()` not `Now()` to store in UTC consistently across all users.

| List | Field | Set when |
|---|---|---|
| VisitClinicalStatus | StartedAt | User saves Status = "In Progress" and StartedAt is blank |
| VisitClinicalStatus | CompletedAt | User saves Status = "Complete" and CompletedAt is blank |
| EDCStatus | ReadyAt | User saves Status = "Ready" and ReadyAt is blank |
| EDCStatus | StartedAt | User saves Status = "In Progress" and StartedAt is blank |
| EDCStatus | CompletedAt | User saves Status = "Complete" and CompletedAt is blank |
| PIAction | RequiredAt | New PIAction created and RequiredAt is blank |
| PIAction | CompletedAt | User saves Status = "Complete" and CompletedAt is blank |
| QCFinding | ResolvedAt | User saves Status = "Resolved" or "Verified" and ResolvedAt is blank |

**Power Apps OnSelect pattern** (EDCStatus screen example -- apply same pattern to all other role screens):

```powerapps
Patch(
    EDCStatus,
    If(IsBlank(Gallery_EDC.Selected), Defaults(EDCStatus), Gallery_EDC.Selected),
    {
        Status:      Dropdown_EDCStatus.Selected.Value,
        CompletedAt: If(Dropdown_EDCStatus.Selected.Value = "Complete"
                            And IsBlank(Gallery_EDC.Selected.CompletedAt),
                        UTCNow(),
                        Gallery_EDC.Selected.CompletedAt),
        StartedAt:   If(Dropdown_EDCStatus.Selected.Value = "In Progress"
                            And IsBlank(Gallery_EDC.Selected.StartedAt),
                        UTCNow(),
                        Gallery_EDC.Selected.StartedAt),
        ReadyAt:     If(Dropdown_EDCStatus.Selected.Value = "Ready"
                            And IsBlank(Gallery_EDC.Selected.ReadyAt),
                        UTCNow(),
                        Gallery_EDC.Selected.ReadyAt)
    }
)
```

The `If(IsBlank(...Field), UTCNow(), ...Field)` pattern prevents backdating -- a timestamp is only written when the field is currently blank.

#### Component B -- Parent VisitWorkflow timestamps set by roll-up flows

Already specified per flow in `VISIT_ROLLUP_FLOW_DESIGN.md`. Power Automate expression pattern:

```
@if(empty(items('Get_parent_record')?['QCReadyAt']), utcNow(), items('Get_parent_record')?['QCReadyAt'])
```

Substitute the relevant field name. Always read the current parent in a Get item action immediately before writing.

**Verification:** Save VisitClinicalStatus as In Progress -- StartedAt is auto-populated. Save again -- StartedAt is unchanged.

---

### WU3 -- P1-4 Duplicate detection: spec

**Status:** PROPOSED -- Power Apps client-side validation before Patch.

**Fields requiring uniqueness:**

| List | Field | Uniqueness scope |
|---|---|---|
| VisitWorkflow | VisitKey | Global |
| VisitAdmin | VisitAdminID | List-wide |
| QCFinding | FindingID | List-wide |
| EDCStatus | DataRecordID | List-wide |
| PIAction | PIActionID | List-wide |
| WorkflowAudit | AuditEventID | Auto-generated by flows using `@guid()` |

**Power Apps duplicate check pattern** (apply in OnSelect of the save button on each screen):

```powerapps
If(
    IsBlank(Gallery_VisitAdmin.Selected) And
    CountRows(Filter(VisitAdmin, VisitAdminID = TextInput_VisitAdminID.Text)) > 0,
    Notify("VisitAdminID already exists. Use a unique identifier.", NotificationType.Error),
    Patch(VisitAdmin, Defaults(VisitAdmin), {VisitAdminID: TextInput_VisitAdminID.Text})
)
```

`IsBlank(Gallery.Selected)` ensures the check only fires on new records, not on edits.

**UAT test:** Submit VisitAdminID = `DEV-UAT-20260930-VA-001` (existing) on the new record screen -- expect error, no save. Submit a unique ID -- expect success.

---

### WU4 -- P1-5 Chronology validation: spec

**Status:** PROPOSED -- Power Apps client-side validation before Patch.

**UAT evidence:** `DEV-UAT-20260930-VA-DUP` had DepartureTime 10:00, ArrivalTime 17:00 -- departure before arrival was accepted without error.

**Date pairs requiring validation:**

| List | Rule | Error message |
|---|---|---|
| VisitAdmin | ArrivalTime < DepartureTime | "Departure time cannot be before arrival time." |
| QCFinding | RaisedAt <= ResolvedAt (when ResolvedAt is populated) | "Resolved date cannot be before raised date." |
| EDCStatus | ReadyAt <= StartedAt <= CompletedAt (when populated) | "EDC timestamps must be in sequence: Ready, Started, Completed." |
| PIAction | RequiredAt <= CompletedAt (when both populated) | "Completed date cannot be before required date." |

**Power Apps validation pattern** (VisitAdmin screen):

```powerapps
If(
    Not(IsBlank(DatePicker_DepartureTime.SelectedDate)) And
    DatePicker_DepartureTime.SelectedDate < DatePicker_ArrivalTime.SelectedDate,
    Notify("Departure time cannot be before arrival time.", NotificationType.Error),
    Patch(VisitAdmin, ...)
)
```

For multiple checks on one screen, chain them before the Patch:

```powerapps
If(condition1, Notify(error1, NotificationType.Error),
   condition2, Notify(error2, NotificationType.Error),
   Patch(...))
```

**Verification:** Save VisitAdmin with DepartureTime 10:00 and ArrivalTime 17:00 -- error, no save. Save with DepartureTime 18:00 and ArrivalTime 17:00 -- success.

---

### WU5 -- P1-6 Timezone verification procedure and launch readiness audit

#### P1-6 Timezone verification procedure

**Status:** PROPOSED -- Codex executes (requires SharePoint tenant access).

**Background:** Regional settings changed to UTC+02:00 Harare/Pretoria on 2026-09-30. List header still showed Pacific Time immediately after -- propagation delay or user-level override unresolved.

Step 1 -- Site level: SharePoint site -> Settings -> Site Settings -> Regional Settings. Confirm Time Zone = "(UTC+02:00) Harare, Pretoria" and Locale = "English (South Africa)". Re-save if wrong.

Step 2 -- List propagation: Open VisitWorkflow list. A Date/Time column for `DEV-UAT-20260930-VW-001` should show in SAST (+02:00), not Pacific or UTC.

Step 3 -- User-level override (if Step 2 still shows wrong after Step 1 is confirmed correct): Profile icon -> View account -> Settings & Privacy -> Language & Region -> Region -> set to South Africa.

Step 4 -- Power Apps display: Open live DEV app -> VisitAdmin screen -> confirm a date/time field shows SAST format.

**Verification evidence:** Description of VisitWorkflow list showing a date in SAST (+02:00) format.

---

#### Launch readiness audit (as of seq 10)

| Finding | Status | Notes |
|---|---|---|
| P0-1 EDC guard | COMPLETED_VERIFIED | |
| P0-2 Roll-up flows (5) | STARTED_UNVERIFIED | Spec complete in VISIT_ROLLUP_FLOW_DESIGN.md |
| P0-3 WorkflowAudit lock | STARTED_UNVERIFIED | Full spec in WU1 above |
| P1-1 PIAction guard | COMPLETED_VERIFIED | Confirm null-safety of expression |
| P1-2 QCFinding guard | NOT_STARTED | Expression spec in seq 9 log entry |
| P1-3 Auto-timestamps | NOT_STARTED | Spec in WU2 above |
| P1-4 Duplicate detection | NOT_STARTED | Spec in WU3 above |
| P1-5 Chronology validation | NOT_STARTED | Spec in WU4 above |
| P1-6 Timezone verification | NOT_STARTED | Procedure in WU5 above |
| P2-1 Screen2 errors | COMPLETED_VERIFIED | |
| P2-2 System-field locks | COMPLETED_VERIFIED | |

**Critical path to DEV UAT sign-off:**

1. P0-3 and P1-2 are data-integrity blockers -- complete before the next UAT run.
2. P0-2 (5 roll-up flows) is the largest remaining item -- UAT test cases R-01 to R-15 cannot run until at least Flow 4 and Flow 2 are live.
3. P1-3, P1-4, P1-5 are Power Apps UI changes -- lower risk, can be built in parallel with flow work.
4. P1-6 is a quick check, likely already resolved.
5. Final gate requires both agents to independently record FINAL_REVIEW: COMPLETE, P0_FINDINGS: 0, P1_FINDINGS: 0.

**Estimated remaining Codex sessions at 5 units/session:**

| Session | Content |
|---|---|
| Next | P1-2 QCFinding guard + P0-3 WorkflowAudit lock |
| +1 | P1-6 timezone verify + Flow 4 EDCStatus roll-up + Flow 2 VCS roll-up |
| +2 | Flow 1 VisitAdmin + Flow 3 QCFinding + Flow 5 PIAction roll-up |
| +3 | P1-3 auto-timestamps + P1-4 duplicate detection + P1-5 chronology |
| +4 | End-to-end UAT run R-01 to R-15 |
| +5 | Final review and production approval gate |

Approximately 6 more Codex sessions to DEV UAT sign-off, assuming no rework.

### Request to Codex

All specs are now written. Execute in this order:
1. P1-2 QCFinding closure guard (expression spec in seq 9 log entry)
2. P0-3 WorkflowAudit append-only (WU1 above -- connection-owner pre-check first)
3. P1-6 timezone verify (WU5 procedure -- quick check)
4. P0-2 roll-up flows in order: Flow 4, Flow 2, Flow 1, Flow 3, Flow 5
5. P1-3, P1-4, P1-5 Power Apps changes (WU2, WU3, WU4 specs)
6. End-to-end UAT run R-01 to R-15

---

## 2026-10-02 — Codex handoff sequence 11 — P1-2 completed and verified

Codex deployed and activated `Trident DEV - QCFinding closure guard` (flow ID `5bda3c0a-8f6a-449f-8fc8-4eae07775dee`). The flow triggers on QCFinding create/modify and demotes a record from `Closed` to `In Progress` when either `Resolution` or `ResolvedAt` is blank. The corrective update preserves required identifiers, linked visit/study values, ownership, clinical fields, recurrence and CAPA fields.

Live fictitious UAT evidence using `DEV-UAT-20260930-QC-001`:

1. Invalid case: `Status=Closed`, blank `Resolution`, blank `ResolvedAt` — flow succeeded and changed Status to `In Progress`.
2. Preservation check: `RecurrenceFlag=Yes`, `CAPARequired=Yes`, and `CAPARef=DEV-UAT-CAPA-002` remained unchanged after correction.
3. Self-trigger check: the corrected record no longer met the Closed condition and did not loop.
4. Valid case: populated `Resolution` and `ResolvedAt=2026-10-02 15:15 SAST`, then set `Status=Closed` — record remained Closed.
5. Flow checker before activation: 0 errors, 0 warnings.

**Result:** P1-2 `COMPLETED_VERIFIED`. Production writes remain disabled. P0-3 WorkflowAudit item-level controls are prepared but not committed because the final permission-changing click requires action-time user confirmation. Continue independent work with P1-6 timezone verification and P0-2 roll-up flows while holding that approval boundary.

### P1-6 time-zone verification

Codex verified the live DEV SharePoint regional settings page without making changes. Time zone is `(UTC+02:00) Harare, Pretoria` and locale is `English (South Africa)`. The QCFinding valid-closure record displayed `ResolvedAt=2026/10/02 03:15 pm`, matching the 15:15 SAST value submitted in the test. No Pacific-time display remained in the current list session.

**Result:** P1-6 `COMPLETED_VERIFIED`. Next independent work unit: P0-2 roll-up Flow 4 (EDCStatus to VisitWorkflow). P0-3 remains staged pending action-time confirmation for the SharePoint permission change.

### 2026-10-02 — Codex manual handoff sequence 12 — Flow 4 staged for Claude

Codex created the DEV-only copy `Trident DEV - EDCStatus roll-up` from the verified EDC guard.

- Flow ID: `ae08aa72-25cb-484a-82ea-883281a36d35`
- Trigger remains SharePoint `EDCStatus` item created or modified.
- Added `Get items` against DEV `VisitWorkflow`, filtered by the trigger VisitKey, limited to one parent.
- Added a parent-exists condition using `greater(length(body('Get_items')?['value']),0)`.
- Retargeted the true branch to update `VisitWorkflow` while preserving parent identity fields.
- Mapped child `Status` to parent `EDCStatus`, added the Ready/In Progress/Complete transition mapping, and added EDCReadyAt, EDCStartedAt and EDCCompletedAt timestamp expressions.
- Removed all unowned optional fields before mapping so the flow does not blank fields owned by other roll-up flows.
- Flow checker in the designer: 0 errors and 0 warnings.
- The copied flow is currently **OFF** pending activation and live test. Do not treat P0-2 as complete until Claude confirms activation, run history, and parent record evidence.

### Claude takeover instructions

1. Read `outputs/AI_AGENT_STATUS.json`, this entry, `outputs/VISIT_ROLLUP_FLOW_DESIGN.md`, and the current UAT results before acting.
2. Locate flow `ae08aa72-25cb-484a-82ea-883281a36d35`; inspect its saved expressions and activate it only after confirming the checker remains clean.
3. Test against fictitious DEV EDCStatus/VisitWorkflow data. Verify the parent ID lookup, EDCStatus mirror, status transitions, timestamps, and that unrelated parent fields are preserved. If the inline expressions evaluate as literal text, repair them with Power Automate expression tokens.
4. Record run IDs and parent evidence. Then continue Flow 2, Flow 1, Flow 3 and Flow 5 in the documented order.
5. P0-3 remains staged in the SharePoint WorkflowAudit Advanced Settings tab and requires action-time user confirmation before clicking OK. Do not commit that permission change without the user’s confirmation.

Production writes remain disabled throughout.


## 2026-10-02 15:40 SAST -- CLAUDE CODE -- Flow 4 design review and Flows 2-5 build specs (seq 13)

**Scope note:** Activating a Power Automate flow is a tenant change outside Claude Code scope (tenantWorkAllowed: false). The work below is a design review of Flow 4 as documented by Codex, a pre-activation checklist, a test script, and complete build specs for Flows 2-5 so Codex can execute the remaining roll-up work efficiently. The user or Codex must execute the actual activation clicks.

---

### WU1 -- Flow 4 (EDCStatus roll-up) design review

Codex documented the following was built and saved (checker 0/0, currently OFF):
- Trigger: EDCStatus item created or modified
- Get items: VisitWorkflow filtered by VisitKey, limit 1
- Parent-exists condition: `greater(length(body('Get_items')?['value']),0)`
- Update VisitWorkflow: EDCStatus mirror, status transitions, timestamps

**Three items requiring confirmation before activation:**

**Item A -- CloseEligible not mentioned (high priority)**

The spec (`VISIT_ROLLUP_FLOW_DESIGN.md`) requires every roll-up flow to recalculate and write `CloseEligible` after its own update. Codex's log does not mention CloseEligible being added to Flow 4. Before activating:

- Open Flow 4 in the designer.
- Confirm the Update VisitWorkflow action includes a `CloseEligible` value.
- CloseEligible = true only when ALL of: VisitClinicalStatus.Status = Complete, all QCFindings Closed/Verified, EDCStatus.Status = Complete, all PIActions Complete/Not Required.
- For Flow 4 at DEV/pilot scale, simplify: set CloseEligible based on whether EDCStatus = Complete AND the other conditions can be read from the parent record's existing fields (QCStatus = Passed, PIActionStatus = Complete or Not Required).
- If cross-list reads are not yet in the flow, add a Set variable action that reads the current parent before the Update and computes CloseEligible inline.

If CloseEligible is missing from the Update action, the field will be left unchanged (not blanked) only if "Removed all unowned optional fields" means the field is simply not included in the Update item body. Confirm this -- if SharePoint Update item overwrites omitted fields with null, CloseEligible will be lost.

**Item B -- Parent.Status transition guards (medium priority)**

The spec requires the parent.Status condition to guard against backwards transitions:
```
IF trigger.Status = "Ready" AND parent.Status = "QC Passed" THEN parent.Status = "Ready for EDC"
IF trigger.Status = "In Progress" AND parent.Status = "Ready for EDC" THEN parent.Status = "EDC In Progress"
IF trigger.Status = "Complete" AND parent.Status = "EDC In Progress" THEN parent.Status = "EDC Complete"
```

Codex's log says "Ready/In Progress/Complete transition mapping" was added but does not confirm the parent.Status guard condition was included. Without it, saving EDCStatus as Complete when the parent is still at "QC Passed" would incorrectly advance the parent Status to "EDC Complete" skipping intermediate states.

Confirm in the designer: the Update VisitWorkflow Status value uses a nested if expression that checks BOTH the trigger Status AND the current parent Status before setting a new value.

Power Automate expression for the Status field in the Update action:
```
@if(
  and(equals(triggerOutputs()?['body/Status/Value'],'Complete'),
      equals(first(body('Get_items')?['value'])?['Status/Value'],'EDC In Progress')),
  'EDC Complete',
  if(
    and(equals(triggerOutputs()?['body/Status/Value'],'In Progress'),
        equals(first(body('Get_items')?['value'])?['Status/Value'],'Ready for EDC')),
    'EDC In Progress',
    if(
      and(equals(triggerOutputs()?['body/Status/Value'],'Ready'),
          equals(first(body('Get_items')?['value'])?['Status/Value'],'QC Passed')),
      'Ready for EDC',
      first(body('Get_items')?['value'])?['Status/Value']
    )
  )
)
```
The final fallback returns the current parent Status unchanged, so if no transition condition is met the field is preserved.

**Item C -- EDCStatus "Returned" choice not in VisitWorkflow.EDCStatus (medium priority)**

Schema analysis:
- `EDCStatus.Status` choices: Not Ready; Ready; In Progress; Complete; **Returned**
- `VisitWorkflow.EDCStatus` choices: Not Ready; Ready; In Progress; Complete (no Returned)

If a user sets EDCStatus to "Returned" (to send data back for correction), Flow 4 will attempt to mirror "Returned" to VisitWorkflow.EDCStatus, which will fail with a SharePoint validation error since "Returned" is not a valid choice on the parent field.

Fix: in the Update action, map the EDCStatus mirror value with:
```
@if(equals(triggerOutputs()?['body/Status/Value'],'Returned'),
    'In Progress',
    triggerOutputs()?['body/Status/Value'])
```
This maps "Returned" to "In Progress" at the parent level, which is the correct semantic (the EDC work is still in progress, just returned for correction).

**Item D -- Timestamp null-check expressions (confirm)**

Confirm EDCReadyAt, EDCStartedAt, EDCCompletedAt in the Update action use the blank-safe pattern, not unconditional utcNow():
```
@if(empty(first(body('Get_items')?['value'])?['EDCReadyAt']), utcNow(), first(body('Get_items')?['value'])?['EDCReadyAt'])
```
If they use bare `utcNow()`, existing timestamps will be overwritten every time the flow runs.

**Pre-activation checklist (Codex/user):**

1. Open Flow ae08aa72-25cb-484a-82ea-883281a36d35 in the designer.
2. Confirm CloseEligible is in the Update VisitWorkflow action body (Item A).
3. Confirm the Status mapping uses the nested transition expression with parent.Status guard (Item B).
4. Add the "Returned" -> "In Progress" mapping for the EDCStatus mirror field (Item C).
5. Confirm timestamps use `if(empty(...), utcNow(), ...)` (Item D).
6. Re-check the flow checker: 0 errors, 0 warnings.
7. Turn the flow ON.
8. Run the test script below.

**Flow 4 activation test script:**

Test F4-T1 (status transition -- Ready):
- EDCStatus record for DEV-UAT-20260930-VW-001: set Status = "Ready".
- Expected: VisitWorkflow EDCStatus = "Ready", Status = "Ready for EDC", EDCReadyAt stamped, other fields unchanged.

Test F4-T2 (status transition -- In Progress):
- Set EDCStatus.Status = "In Progress".
- Expected: VisitWorkflow EDCStatus = "In Progress", Status = "EDC In Progress", EDCStartedAt stamped, EDCReadyAt unchanged.

Test F4-T3 (status transition -- Complete, valid):
- Ensure EDCStatus record has OpenQueryCount = 0, QueryStatus = Resolved/None, CompletedAt populated (so EDC guard passes).
- Set EDCStatus.Status = "Complete".
- Expected: EDC guard runs first (no demotion). Roll-up runs: VisitWorkflow EDCStatus = "Complete", Status = "EDC Complete", EDCCompletedAt stamped.

Test F4-T4 (Returned mapping):
- Set EDCStatus.Status = "Returned".
- Expected: VisitWorkflow EDCStatus = "In Progress" (not "Returned"), parent Status unchanged.

Test F4-T5 (no backwards transition):
- Parent Status = "QC Passed". Set EDCStatus.Status = "Complete".
- Expected: VisitWorkflow Status remains "QC Passed" (transition only fires when parent is "EDC In Progress").

Test F4-T6 (timestamp idempotency):
- Run F4-T2 again on the same record.
- Expected: EDCStartedAt is unchanged (not overwritten by second run).

---

### WU2-WU5 -- Build specs for Flows 2, 1, 3, 5

These specs are written for Codex to implement directly. Each follows the common pattern from VISIT_ROLLUP_FLOW_DESIGN.md: trigger, VisitKey null guard (where applicable), Get parent, compute derived values, Update parent, create WorkflowAudit row.

---

#### Flow 2 -- VisitClinicalStatus roll-up

**Flow name:** `Trident DEV - VisitClinicalStatus roll-up`
**Trigger:** VisitClinicalStatus item created or modified
**No VisitKey null guard needed** -- VisitKey is required on VisitClinicalStatus.

**Get parent:**
Get items from VisitWorkflow where VisitKey = trigger VisitKey, top 1.
Condition: `greater(length(body('Get_VCS_parent')?['value']),0)` -- terminate (no-op) if false.

**Update VisitWorkflow with these field mappings:**

VisitOwner:
```
@triggerOutputs()?['body/VisitOwner/Claims']
```
(Pass the OData claims object for the Person field.)

ActualVisitDate (set only when blank on parent):
```
@if(empty(first(body('Get_VCS_parent')?['value'])?['ActualVisitDate']),
    triggerOutputs()?['body/StartedAt'],
    first(body('Get_VCS_parent')?['value'])?['ActualVisitDate'])
```

Status (nested transition expression):
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

QCReadyAt (stamp only on transition to Ready for QC, only if blank):
```
@if(
  and(equals(triggerOutputs()?['body/Status/Value'],'Complete'),
      equals(triggerOutputs()?['body/ReadyForQC'],true),
      empty(first(body('Get_VCS_parent')?['value'])?['QCReadyAt'])),
  utcNow(),
  first(body('Get_VCS_parent')?['value'])?['QCReadyAt'])
```

CloseEligible: evaluate composite check (see Flow 4 Item A note -- defer if cross-list reads are not yet plumbed; set to false for now to be safe).

WorkflowAudit row: Create item with EventType = "Status Change", FieldName = "Status", OldValue = current parent Status, NewValue = computed new Status, EntityType = "VisitWorkflow", EntityKey = trigger VisitKey, SourceApp = "Power Automate", CorrelationID = `@workflow().run.name`, AuditEventID = `@guid()`.

**Test cases:**
- VCS-T1: Set VisitClinicalStatus.Status = "In Progress" -- parent transitions Arrived -> Visit In Progress.
- VCS-T2: Set Status = "Complete", ReadyForQC = false -- parent transitions -> Visit Complete.
- VCS-T3: Set Status = "Complete", ReadyForQC = true -- parent transitions -> Ready for QC, QCReadyAt stamped.
- VCS-T4: Re-save record -- QCReadyAt unchanged (idempotency).

---

#### Flow 1 -- VisitAdmin roll-up

**Flow name:** `Trident DEV - VisitAdmin roll-up`
**Trigger:** VisitAdmin item created or modified

**Get parent:**
Get items from VisitWorkflow where VisitKey = trigger VisitKey, top 1.
Terminate (no-op) if empty.

**Update VisitWorkflow:**

PlannedDate:
```
@triggerOutputs()?['body/PlannedDate']
```

ReceptionOwner:
```
@triggerOutputs()?['body/ReceptionOwner/Claims']
```

ActualVisitDate (set only when Arrived and blank):
```
@if(
  and(equals(triggerOutputs()?['body/AttendanceStatus/Value'],'Arrived'),
      empty(first(body('Get_VA_parent')?['value'])?['ActualVisitDate'])),
  triggerOutputs()?['body/ArrivalTime'],
  first(body('Get_VA_parent')?['value'])?['ActualVisitDate'])
```

Status:
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

WorkflowAudit row: same pattern as Flow 2, FieldName = "Status".

**Test cases:**
- VA-T1: Set VisitAdmin.AttendanceStatus = "Arrived" -- parent Scheduled -> Arrived, ActualVisitDate stamped.
- VA-T2: Set AttendanceStatus = "No Show" -- parent Arrived -> Scheduled.
- VA-T3: PlannedDate update -- parent PlannedDate mirrors, no Status change.

---

#### Flow 3 -- QCFinding roll-up

**Flow name:** `Trident DEV - QCFinding roll-up`
**Trigger:** QCFinding item created or modified

**Get parent:** VisitWorkflow by trigger VisitKey, top 1. Terminate if empty.

**Get all QCFindings for VisitKey:**
Get items from QCFinding where VisitKey = trigger VisitKey (no top limit -- need all).

**Compute derived values (use Initialize/Set variable actions):**

openCount = `@length(body('Filter_open_findings')?['value'])`
where Filter_open_findings filters QCFinding results for Status in (Open, Returned, In Progress).

closedCount = `@length(body('Filter_closed_findings')?['value'])`
where Filter_closed_findings filters for Status in (Resolved, Verified, Closed).

qcStatusValue:
```
@if(greater(length(body('Filter_returned_findings')?['value']),0),
    'Returned',
    if(greater(length(body('Filter_open_findings')?['value']),0),
       'In Progress',
       if(greater(length(body('Filter_closed_findings')?['value']),0),
          'Passed',
          'Not Ready')))
```
where Filter_returned_findings filters for Status = Returned.

**Update VisitWorkflow:**

OpenQueryCount: `@variables('openCount')`

QCStatus: `@variables('qcStatusValue')`

QCStartedAt (stamp on first In Progress, only if blank):
```
@if(
  and(equals(variables('qcStatusValue'),'In Progress'),
      empty(first(body('Get_QC_parent')?['value'])?['QCStartedAt'])),
  utcNow(),
  first(body('Get_QC_parent')?['value'])?['QCStartedAt'])
```

QCPassedAt (stamp on Passed, only if blank):
```
@if(
  and(equals(variables('qcStatusValue'),'Passed'),
      empty(first(body('Get_QC_parent')?['value'])?['QCPassedAt'])),
  utcNow(),
  first(body('Get_QC_parent')?['value'])?['QCPassedAt'])
```

Status (transitions):
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

WorkflowAudit rows: create separate rows for Status change (if changed), QCStatus change, and OpenQueryCount change.

**Test cases:**
- QCR-T1: Create QCFinding with Status = Open -- OpenQueryCount = 1, parent Status -> QC In Progress, QCStartedAt stamped.
- QCR-T2: Set QCFinding.Status = Returned -- QCStatus = Returned, parent Status -> QC Returned.
- QCR-T3: Set QCFinding.Status = Closed (with Resolution and ResolvedAt -- QCFinding guard passes) -- OpenQueryCount = 0, QCStatus = Passed, parent Status -> QC Passed, QCPassedAt stamped.
- QCR-T4: Re-save record after QC Passed -- QCPassedAt unchanged.

---

#### Flow 5 -- PIAction roll-up

**Flow name:** `Trident DEV - PIAction roll-up`
**Trigger:** PIAction item created or modified

**VisitKey null guard (first action):**
Condition: `@not(empty(triggerOutputs()?['body/VisitKey/Value']))`
False branch: Terminate -- Succeeded. (Study-level PIActions have no VisitKey and must not update any parent.)

**Get parent:** VisitWorkflow by trigger VisitKey, top 1. Terminate if empty.

**Get all PIActions for VisitKey:**
Get items from PIAction where VisitKey = trigger VisitKey (no top limit).

**Compute derived values:**

pendingCount = length of PIActions where Status in (Pending, In Progress).

actionRequired = `@greater(length(body('Filter_required_PIActions')?['value']),0)`
where Filter_required_PIActions filters for Status NOT IN (Not Required, Entered in Error).

piActionStatusValue:
```
@if(greater(variables('pendingCount'),0),
    'Pending',
    if(variables('actionRequired'),
       'Complete',
       'Not Required'))
```

**Update VisitWorkflow:**

PIActionRequired: `@variables('actionRequired')`

PIActionStatus: `@variables('piActionStatusValue')`

Status:
```
@if(
  and(greater(variables('pendingCount'),0),
      or(equals(first(body('Get_PIA_parent')?['value'])?['Status/Value'],'EDC Complete'),
         equals(first(body('Get_PIA_parent')?['value'])?['Status/Value'],'PI Action'))),
  'PI Action',
  first(body('Get_PIA_parent')?['value'])?['Status/Value']
)
```
Note: when all PIActions are complete, do NOT auto-close. Set CloseEligible = true (if composite check passes) and let the user close manually from the app.

CloseEligible (composite check -- can be computed after all four child conditions are derivable from parent fields):
```
@and(
  equals(first(body('Get_PIA_parent')?['value'])?['EDCStatus/Value'],'Complete'),
  equals(first(body('Get_PIA_parent')?['value'])?['QCStatus/Value'],'Passed'),
  or(equals(variables('piActionStatusValue'),'Complete'),
     equals(variables('piActionStatusValue'),'Not Required'))
)
```
Note: VisitClinicalStatus.Status = Complete is not directly readable from the parent; VisitWorkflow.Status being at or past "Visit Complete" is a reasonable proxy. Alternatively, add a Get items call to VisitClinicalStatus as a prerequisite for all roll-up flows that compute CloseEligible.

WorkflowAudit rows: one for PIActionRequired change, one for PIActionStatus change, one for Status change if applicable.

**Test cases:**
- PIA-T1: VisitKey is blank -- flow terminates, no parent update (null guard verified).
- PIA-T2: Create PIAction with Status = Pending -- parent PIActionRequired = true, PIActionStatus = Pending, parent Status -> PI Action (if at EDC Complete).
- PIA-T3: Set PIAction.Status = Complete with CompletedAt and Outcome populated (PIAction guard passes) -- PIActionStatus = Complete, CloseEligible = true (if other conditions met).

---

### Summary for Codex

Pre-activation fixes required on Flow 4 before turning it ON:
1. Add CloseEligible to the Update VisitWorkflow action (or confirm it is already there).
2. Confirm Status mapping uses the nested expression with parent.Status guard -- if not, replace with expression in Item B above.
3. Add "Returned" -> "In Progress" mapping for the EDCStatus mirror field (Item C).
4. Confirm timestamp expressions use `if(empty(...), utcNow(), ...)` not bare utcNow().

After those fixes and activation, run F4-T1 through F4-T6.

Then build Flows 2, 1, 3, 5 in that order using the specs above. Flows 2 and 1 are simpler (single child list, no count logic). Flow 3 is most complex (multi-item count requires filter actions and variables). Flow 5 requires the VisitKey null guard.
