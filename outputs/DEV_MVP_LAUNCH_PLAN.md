# Trident Operations Central DEV — MVP Launch Plan

## Current usable scope

- Published Power Apps canvas app: `Trident Operations Central DEV`
- App ID: `0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f`
- Published URL: `https://apps.powerapps.com/play/e/Default-0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0/a/0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f?tenantId=0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0`
- Live screens: DEV `VisitWorkflow`, Reception/`VisitAdmin`, Clinical/`VisitClinicalStatus`, Quality/`QCFinding`, EDC/`EDCStatus`, PI/`PIAction`, Study Administration/`StudyMaster`, and read-only Audit/`WorkflowAudit`
- Live two-way navigation: **Reception**, **Clinical / CTA**, **Quality / QC**, **EDC**, **PI Actions**, **Study Admin**, and **Audit** from Workflow, with **Workflow** return navigation from each role screen
- Shared as app users with Tasneem Essop, Dr Lorato Pata, Kyla Ryland and Reception.
- All four are members of the fictitious DEV SharePoint site with Edit access.
- Active Power Automate guards: EDC completion, PIAction completion and QCFinding closure guards automatically return unsupported terminal states to In Progress. Invalid, valid and safe self-trigger paths have been verified in DEV.
- Production writes remain disabled.
- DEV regional settings are verified as `(UTC+02:00) Harare, Pretoria` with `English (South Africa)` locale; live QCFinding timestamps display in SAST.

## Immediate blocker

There is no editor-lock blocker in the published app. The latest live revision was saved, published and verified through all seven role-screen round trips. EDC, PIAction and QCFinding terminal-state guards are live and verified. The immediate functional blocker is completion of parent workflow roll-ups, automatic timestamps, duplicate and chronology validation, plus append-only audit enforcement. The remaining GUI backlog is cleanup of generated sample content, role-focused actions and button placement.

## MVP screens

**Data-source readiness:** all eight DEV SharePoint lists are connected and exposed in the published app. VisitWorkflow plus Reception/VisitAdmin, Clinical/VisitClinicalStatus, Quality/QCFinding, EDC/EDCStatus, PI/PIAction, Study Administration/StudyMaster and read-only Audit/WorkflowAudit are implemented. Live two-way navigation and seeded DEV-record loading passed for all seven role areas.

1. **Operations dashboard**
   - Today’s visits, overdue visits, open QC findings, open EDC queries and PI actions.
   - Filter by study, participant, owner and status.
2. **Reception queue**
   - Implemented as a working VisitAdmin gallery and record form with return navigation to VisitWorkflow.
   - Next refinement: replace generated sample labels/tabs, restrict system fields, and present arrival, departure, attendance and administrative-readiness as guided actions.
3. **Clinical / CTA queue**
   - Implemented as a live VisitClinicalStatus gallery and record form with return navigation.
   - Next refinement: convert clinical progress, source completion, lab-review and deviation fields into guided actions and block contradictory states.
4. **QC queue**
   - Implemented as a live QCFinding gallery and record form with return navigation.
   - Resolution evidence and resolved timestamp are now enforced by the live QCFinding closure guard. Next refinement: add guided pass/return-for-correction actions.
5. **EDC queue**
   - Implemented as a live EDCStatus record form with return navigation to VisitWorkflow.
   - Seeded record loading passed, including `Status=Complete`, three open queries and `QueryStatus=Open`.
   - Next refinement: remove generated sample content, add a real queue/gallery, and block completion while queries remain open or evidence is missing.
6. **PI actions**
   - Implemented as a live PIAction record form with return navigation to VisitWorkflow.
   - Seeded record loading passed, including a deliberate invalid `Complete` state with blank `CompletedAt` and `Outcome`.
   - Next refinement: add a real queue, assigned-action filtering, guided outcomes and completion validation.
7. **Study administration**
   - Implemented as a live StudyMaster record form with return navigation to VisitWorkflow.
   - Seeded record loading passed for `DEV-ACHIEVE-RAM-001`, including protocol, study name, sponsor and Active status.
   - Next refinement: add a study selector or queue, planned-visit management, role restrictions and guided actions.
8. **Audit view**
   - Implemented as a read-only WorkflowAudit display form with return navigation to VisitWorkflow.
   - Seeded record loading passed for `DEV-UAT-20260930-AUD-001`, including the correction event, old and new values, timestamp, source and correlation ID.
   - Next refinement: add a filterable history gallery and enforce append-only behavior in SharePoint and automation.

## Minimum validation and automation

1. Reject duplicate business identifiers.
2. Reject departure before arrival and completion before start.
3. Require evidence fields for Closed, Complete, Passed and Correction states.
4. Recalculate open findings, open query counts and close eligibility.
5. Stamp state-transition timestamps automatically.
6. Create append-only WorkflowAudit rows for changes, corrections and reopening.
7. Prevent users from editing calculated or system-managed fields.
8. Alert the responsible role when work becomes ready or overdue.

## Current GUI cleanup

- Claude Code completed the six generated Screen2 formula corrections; final regression testing will confirm they remain cleared in the published build.
- The working VisitAdmin gallery, selected-record form, Reception button and Workflow return button are unaffected.
- The EDC screen still displays generated `Contoso Art Studio` sample branding and sample gallery rows around the working EDCStatus form.
- The PI screen is a functional generated record form and still needs a queue, role-focused field layout and validation messaging.
- The Study Administration screen is a functional generated record form and still needs a selector or queue, role-focused field layout and validation messaging.
- Navigation buttons use default placement and need a single consistent header or menu layout.

## Role access target

| Role | User | Intended app scope |
| --- | --- | --- |
| Managerial / SSC / HR / Finance | Tasneem Essop | Dashboard, oversight and administration |
| PI | Dr Lorato Pata | PI queue and related visit context |
| Senior CTA | Kyla Ryland | Clinical, QC and EDC operational queues |
| Reception / Clinical Operations Assistant | Reception | Reception queue and visit context |

The current DEV permissions are intentionally broader than this target: every named tester has Edit access across the DEV SharePoint site. Replace this with role-specific access before production.

## Launch acceptance checks

- Each user can open the app and connect to SharePoint.
- Each role sees its intended home screen and actions.
- Each role can edit permitted records and cannot edit restricted fields.
- Deliberately invalid chronology, duplicate identifiers and unsupported close states are blocked.
- Parent VisitWorkflow status and counts update after valid downstream changes.
- Every material change creates an audit entry.
- Search and filters return the expected DEV records.
- Mobile and desktop layouts are usable.
- No production site, list or record is changed during DEV testing.
