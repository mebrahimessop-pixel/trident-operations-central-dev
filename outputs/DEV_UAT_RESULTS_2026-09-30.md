# Trident Operations Central DEV UAT results

Run date: 2026-09-30  
Environment: `ClinicalOperationsDEV` only  
Production writes: disabled  
Test data: fictitious, prefixed `DEV-UAT-20260930`

## Executive result

The DEV SharePoint data layer is reachable and all eight provisioned lists can store linked records. A published Power Apps GUI now provides working VisitWorkflow, Reception/VisitAdmin, Clinical/VisitClinicalStatus, Quality/QCFinding, EDC/EDCStatus, PI/PIAction, Study Administration/StudyMaster and read-only Audit/WorkflowAudit screens with two-way navigation. The first Power Automate validation guard is live and verified: an invalid EDC completion was automatically returned to In Progress. The system is not yet launch-ready for unrestricted operational use because the broader validation, roll-up, timestamp and audit layer remains incomplete.

## Platform checks

| Check | Result | Evidence |
| --- | --- | --- |
| OAuth protected-resource metadata | Pass | HTTP 200; custom API resource and fully qualified scopes advertised |
| Unauthenticated MCP challenge | Pass | HTTP 401 with expected protected-resource metadata challenge |
| Entra OpenID discovery | Pass | HTTP 200 |
| MCP root route | Gap | HTTP 404 |
| MCP `/health` route | Gap | HTTP 404; no public health endpoint |
| SharePoint DEV access | Pass | StudyMaster and all seven workflow lists loaded |
| Lookup integrity | Pass | Existing StudyID and VisitKey values could be selected; arbitrary lookup values were not accepted |
| Required primitive fields | Pass | SharePoint blocked blank required text, choice, date, and person values |
| Power Apps | Partial pass | Published DEV GUI loads live VisitWorkflow, VisitAdmin, VisitClinicalStatus, QCFinding, EDCStatus, PIAction, StudyMaster and read-only WorkflowAudit data. Workflow → Reception/Clinical/Quality/EDC/PI Actions/Study Admin/Audit → Workflow navigation passed in the live player. Claude completed the Screen2 formula cleanup and VisitWorkflow system-field locks; visual refinement and final regression testing remain. |
| Power Automate | Partial pass | `Trident DEV - EDC completion guard` is active and verified. Two runs succeeded: the first corrected an invalid EDC completion to In Progress and the second safely took the no-action path after that correction. Broader roll-up, timestamp, validation and audit flows remain. |

## Fictitious records created

| List | Record | Purpose and observed result |
| --- | --- | --- |
| VisitWorkflow | `DEV-UAT-20260930-VW-001` | Baseline parent record; remained `Scheduled` after all downstream records were added |
| VisitAdmin | `DEV-UAT-20260930-VA-001` | Valid baseline saved |
| VisitClinicalStatus | `DEV-UAT-20260930-VCS-001` | Contradictory `In Progress`, `ReadyForQC=Yes`, `CriticalIssueFlag=Yes`, and `DeviationFlag=Yes` saved |
| QCFinding | `DEV-UAT-20260930-QC-001` | `Closed` saved with no resolution or resolved timestamp; required boolean flags were forced to `Yes` |
| EDCStatus | `DEV-UAT-20260930-EDC-001` | `Complete` saved with three open queries, `QueryStatus=Open`, and no completion timestamp |
| PIAction | `DEV-UAT-20260930-PIA-001` | `Complete` saved without completion timestamp, outcome, or change reason |
| WorkflowAudit | `DEV-UAT-20260930-AUD-001` | Correction event saved without a reason; audit rows remain directly editable |
| VisitAdmin | `DEV-UAT-20260930-VA-DUP` | Duplicate `VisitAdminID=DEV-UAT-20260930-VA-001` saved with departure at 10:00 AM before arrival at 5:00 PM |

## Confirmed gaps

### P0 — blocks a working operational system

1. **Required Yes/No fields force `Yes`.** In modern SharePoint forms, an unchecked required checkbox is treated as blank. Users cannot save a legitimate `No`, which forced contradictory test data.
2. **Only the first workflow guard is deployed.** The EDC completion guard now demotes an unsupported Complete state to In Progress, but the parent VisitWorkflow record still does not roll up downstream changes. Derived statuses, timestamps, query counts, close eligibility and audit events are not yet produced.
3. **The minimum generated GUI is not yet a complete operational interface.** The responsive canvas app now covers all eight DEV data sources, including a read-only WorkflowAudit screen, but it still exposes system-managed fields and lacks guided state transitions, role-focused queues and validation messaging.
4. **Conditional state validation is absent.** Closed/complete/correction states can be saved without their required evidence.

### P1 — high operational risk

1. Business identifiers are not unique; a duplicate VisitAdminID was accepted.
2. Date chronology is not validated; departure before arrival was accepted.
3. WorkflowAudit is not append-only and does not enforce a reason for corrections or reopening.
4. SharePoint list views initially displayed date fields in `(UTC-08:00) Pacific Time (US and Canada)` instead of the intended South Africa regional setting.
5. No public service health endpoint is available for monitoring.

### P2 — launch usability and coverage

1. No dashboard, role-based navigation, study selector, workload queues, or closeout view exists.
2. No Power Apps controls hide system fields or guide users through valid state transitions.
3. Planned operational domains beyond the eight current lists need confirmation before broader rollout.

## Safe local fixes completed

1. All eleven `Yes/No` fields in `config/lists/achieve-ram-pilot.json` now use `required: false`, allowing both `Yes` and `No` in SharePoint.
2. `infra/provision-dev-lists.ps1` now detects required-setting drift, includes it in the approval plan, applies approved corrections with Microsoft Graph `PATCH`, and verifies the setting after application.
3. `Run-DEV-List-Apply.ps1` now asks for the hash from the latest preview instead of retaining an obsolete approved hash.
4. PowerShell syntax and manifest parsing passed locally: 8 lists, 11 Yes/No columns, 0 still marked required.

## DEV schema remediation applied

The guarded plan `de752dd9f38f0b37b1705721bca5931e14e49f390743d741ab0d68840a6a51d0` was explicitly approved and applied to DEV on 2026-09-30.

- All 11 intended required-setting changes were applied.
- All eight lists passed read-back verification.
- No columns were missing.
- No required-setting mismatches remained.
- No destructive operations ran.
- Production writes remained disabled.

The live VisitWorkflow new-item form was then checked directly. `PIActionRequired`, `LabReviewRequired`, `DeviationFlag`, and `CloseEligible` appeared unchecked without the `Required Field` marker, confirming the correction reached the user interface.

The DEV SharePoint site regional settings were also changed from Pacific Time / English (United States) to `(UTC+02:00) Harare, Pretoria` / English (South Africa). The settings page accepted the change and returned to Site Settings. The list header continued to show the previous Pacific label immediately afterward, so propagation or a user-level regional override still needs verification.

## Minimum GUI milestone

Power Apps was initialized in the tenant environment `9472390 : Trident Clinical (default)`. A responsive canvas app was generated from the DEV `VisitWorkflow` list and saved as `Trident Operations Central DEV`.

Preview verification passed:

- The app opened successfully.
- The DEV VisitWorkflow record was visible.
- Search, new-record, detail, and edit controls rendered.
- The live SharePoint connection resolved the StudyID lookup and workflow fields.

The app was published successfully with app ID `0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f`. Its live player opened at:

`https://apps.powerapps.com/play/e/Default-0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0/a/0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f?tenantId=0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0`

The SharePoint connection was explicitly approved and the published runtime was verified successfully:

- The consent prompt cleared and the app loaded the live DEV data source.
- `DEV-UAT-20260930-VW-001` loaded with the expected VisitKey and StudyID.
- Search removed the record for a deliberately nonexistent identifier and restored it for the exact DEV identifier.
- The repaired Yes/No fields rendered their stored values in the published app.
- No records were created, edited, or deleted during this runtime verification.

The browser console contains Power Apps host/framework warnings, including React lifecycle and component warnings. These did not prevent the tested app or SharePoint data path from working. The generated app is an initial working shell; field restrictions, navigation to the other lists, sharing, and automated workflow rules remain implementation work.

## DEV user access

On 2026-09-30, the published DEV app was shared as **User / can use** with the following tenant accounts:

- Tasneem Essop (`tasneem.essop@tridentclinical.co.za`)
- Dr Lorato Pata (`l.pata@tridentclinical.co.za`)
- Kyla Ryland (`kyla.ryland@tridentclinical.co.za`)
- Reception (`info@tridentclinical.co.za`)

The same four accounts were added to `Trident Clinical Operations DEV Members`, which currently grants Edit access across the fictitious DEV SharePoint site. They were not made app co-owners. Power Apps confirmed the share but did not send automatic notifications. Role-specific data permissions remain a launch-hardening task.

Power Apps Studio initially reopened in read-only mode because a stale editing session held control. Editing control was explicitly overridden, the stale tab was closed, and a clean Studio session opened in **Editing** mode.

All eight DEV SharePoint lists are now connected as app data sources:

- StudyMaster
- VisitWorkflow
- VisitAdmin
- VisitClinicalStatus
- QCFinding
- EDCStatus
- PIAction
- WorkflowAudit

The eight-data-source revision was published successfully at 19:41 SAST on 2026-09-30. The live player was reloaded after publication and again displayed `DEV-UAT-20260930-VW-001` with its expected VisitKey, StudyID and workflow values. This verifies that the published VisitWorkflow screen remained operational after all eight data connections were added. A later Reception-screen revision introduced the six nonblocking generated-template errors documented below.

The GUI now exposes the generated VisitWorkflow screen plus working Reception, Clinical / CTA and Quality / QC screens bound to `VisitAdmin`, `VisitClinicalStatus` and `QCFinding`. The main screen has navigation buttons for all three areas, and each role screen has a **Workflow** return button. The published live player passed all three round trips. No records were changed during these navigation tests.

The live Clinical / CTA screen loaded `DEV-UAT-20260930-VCS-001` and displayed the deliberate contradictory state (`In Progress`, `ReadyForQC=Yes`, `CriticalIssueFlag=Yes`, `DeviationFlag=Yes`). The live Quality / QC screen loaded `DEV-UAT-20260930-QC-001` and displayed `Status=Closed` while `Resolution` and `ResolvedAt` remained blank, with recurrence and CAPA flags set. The GUI surfaces these values but does not yet warn or prevent the invalid combinations, confirming the missing conditional-validation control layer.

The six Screen2 generated-template formula errors and the VisitWorkflow system-managed field exposure were subsequently corrected by Claude Code. The user confirmed completion on 2026-10-02 after Claude's completion dump was missed. Both items are closed in the shared status file and remain subject to the final independent regression review.

EDC is now implemented and published on `Screen5`. The main Workflow screen has an **EDC** button and the EDC screen has a **Workflow** return button. Live-player verification passed in both directions. The screen loaded `DEV-UAT-20260930-EDC-001` with `Status=Complete`, `OpenQueryCount=3`, and `QueryStatus=Open`, proving that the SharePoint data connection works and that the seeded contradiction remains visible. No warning or blocking rule appeared, confirming that conditional EDC validation is still absent. The screen retains generated sample branding/gallery content and needs visual cleanup.

PI Actions is now implemented and published on `Screen6`. The main Workflow screen has a **PI Actions** button and the PI screen has a **Workflow** return button. Editor preview and live-player verification passed in both directions. The screen loaded `DEV-UAT-20260930-PIA-001` with `Status=Complete` while `CompletedAt` and `Outcome` remained blank. The invalid state was displayed without a warning or block, confirming that conditional PI validation is still absent.

Study Administration is now implemented and published on `Screen1`. The main Workflow screen has a **Study Admin** button and the study screen has a **Workflow** return button. Editor preview and live-player verification passed in both directions. The screen loaded the fictitious `StudyMaster` record `DEV-ACHIEVE-RAM-001` with protocol `DEV-AR-001`, study name `ACHIEVE-RAM Fictitious DEV Study`, sponsor `Fictitious Sponsor`, and `Status=Active`. The screen is a functional single-record generated form and still needs a queue or selector, role restrictions, guided actions and visual cleanup.

Audit is now implemented and published on `Screen7` using a display-only form bound to `WorkflowAudit`. The main Workflow screen has an **Audit** button and the Audit screen has a **Workflow** return button. Editor preview and live-player verification passed in both directions. The screen loaded `DEV-UAT-20260930-AUD-001` and displayed the correction from `Scheduled` to `Closed`, its timestamp, source and correlation ID without exposing editable controls. Append-only enforcement is still absent at the SharePoint and automation layers.

## DEV automation milestone

The first live Power Automate guard is deployed and turned on:

- Flow: `Trident DEV - EDC completion guard`
- Flow ID: `492182f1-2777-4502-9a06-29dc69a6134a`
- Trigger: an `EDCStatus` item is created or modified
- Rule: a record cannot remain `Complete` while open queries remain, query status is not Closed, or `CompletedAt` is blank
- Correction: set the record back to `In Progress` while preserving required business fields
- Flow checker: 0 errors and 0 warnings
- Live test: `DEV-UAT-20260930-EDC-001` was deliberately saved as Complete with three open queries, Open query status and no completion timestamp; the flow changed it to In Progress
- Run history: two consecutive runs succeeded. The second run made no update after the first correction, verifying that the self-trigger terminates without an update loop

Remaining automation includes chronology and duplicate checks, parent workflow roll-ups, automatic timestamps and append-only audit creation. PI and QC completion guards are now deployed and verified below.

### PIAction completion guard — 2026-10-02

The second live Power Automate guard is deployed and turned on:

- Flow: `Trident DEV - PIAction completion guard`
- Flow ID: `a65c2d52-4e22-4928-ba81-ada2ff7c7994`
- Trigger: a `PIAction` item is created or modified
- Rule: a record cannot remain `Complete` if `CompletedAt` or `Outcome` is blank
- Correction: set the record back to `In Progress` while preserving its required and clinical business fields
- Flow checker: 0 errors and 0 warnings

Verified against fictitious record `DEV-UAT-20260930-PIA-001`:

- Invalid `Complete` record with blank `CompletedAt` and `Outcome`: demoted to `In Progress`.
- Corrective self-trigger: condition evaluated false, no second update ran, and the sequence terminated.
- Valid `Complete` record with populated `CompletedAt` and `Outcome`: remained `Complete`; the corrective update action was skipped.
- Run history: three successful runs matching the invalid trigger, one terminating self-trigger, and the valid trigger.

P1-1 is `COMPLETED_VERIFIED`. Production writes remain disabled.

### QCFinding closure guard — 2026-10-02

The third live Power Automate guard is deployed and turned on:

- Flow: `Trident DEV - QCFinding closure guard`
- Flow ID: `5bda3c0a-8f6a-449f-8fc8-4eae07775dee`
- Trigger: a `QCFinding` item is created or modified
- Rule: a record cannot remain `Closed` if `Resolution` or `ResolvedAt` is blank
- Correction: set the record back to `In Progress` while preserving required business fields, recurrence, CAPA requirement and CAPA reference
- Flow checker: 0 errors and 0 warnings

Verified against fictitious record `DEV-UAT-20260930-QC-001`:

- Invalid `Closed` record with blank `Resolution` and `ResolvedAt`: demoted to `In Progress`.
- The correction preserved `RecurrenceFlag=Yes`, `CAPARequired=Yes` and `CAPARef=DEV-UAT-CAPA-002`.
- Corrective self-trigger terminated because the record was no longer Closed.
- Valid `Closed` record with populated `Resolution` and `ResolvedAt=2026-10-02 15:15 SAST`: remained `Closed`.

P1-2 is `COMPLETED_VERIFIED`. Production writes remain disabled.

### Time-zone and locale verification — 2026-10-02

The DEV SharePoint site regional settings were re-opened and verified without modification:

- Time zone: `(UTC+02:00) Harare, Pretoria`
- Locale: `English (South Africa)`
- Live list evidence: the valid QCFinding test displayed `ResolvedAt=2026/10/02 03:15 pm`, matching the SAST test value entered at 15:15 local time.

P1-6 is `COMPLETED_VERIFIED`. No user-level Pacific-time override was observed in the current DEV list session. Production writes remain disabled.

### EDC guard correction and expanded verification — 2026-10-02

The live `Trident DEV - EDC completion guard` was corrected after run inspection showed the edited condition had been inserted as mixed literal/expression content. The condition was rebuilt as a single Power Automate expression token. It now accepts `Closed`, `Resolved`, `None`, or blank query status when the open-query count is zero and a completion timestamp is present; any other query status remains blocking.

Verified against `DEV-UAT-20260930-EDC-001` using fictitious DEV data:

- `Complete`, `OpenQueryCount=3`, `QueryStatus=Open`, blank `CompletedAt`: flow run `08584107098769017350378451888CU28` succeeded and demoted the record to `In Progress`.
- `Complete`, `OpenQueryCount=0`, `QueryStatus=Resolved`, populated `CompletedAt`: record remained `Complete`.
- `Complete`, `OpenQueryCount=0`, `QueryStatus=None`, populated `CompletedAt`: record remained `Complete`.

The guard is now verified for both blocking and accepted query states. Production writes remain disabled.

## Required implementation sequence

1. Recheck the list time-zone label after propagation and inspect the current user's regional override if it remains Pacific.
2. Extend the live Power Automate layer with parent roll-ups, timestamps and audit creation; PI and QC completion guards are complete.
3. Complete visual refinement and extend the system-field lock audit to the remaining role screens during final hardening.
4. Repeat the same UAT matrix and require all contradictory cases to be blocked or flagged.
5. Keep production disabled until the DEV rerun passes and release approval is recorded.

## Test evidence retention

The fictitious rows remain in DEV as reproducible UAT evidence. They were not deleted because cleanup is a separate destructive action. No production data or permissions were changed.
