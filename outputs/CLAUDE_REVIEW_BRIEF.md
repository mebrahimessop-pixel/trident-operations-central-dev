# Trident Operations Central DEV — co-builder brief

Work as a second engineering partner on this DEV-only build. Inspect the current design, identify concrete improvements, and return implementation-ready recommendations or patches for the primary build agent to apply and verify. Do not request, copy, or transmit any credentials, client secrets, access tokens, or personal data. Treat all records below as fictitious UAT data.

## Scope

Platform inventory: `outputs/PLATFORM_STACK_INVENTORY.md`. Use it as the current licensing and architecture baseline, while treating the reported 42 apps as an unverified inventory item until tenant-level app metadata is collected.

- SharePoint site: `https://tridentclinical.sharepoint.com/sites/ClinicalOperationsDEV`
- Published Power Apps app: `Trident Operations Central DEV`
- App URL: `https://apps.powerapps.com/play/e/Default-0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0/a/0ec0cc2b-da98-4cd8-8160-5b17cd4b5e5f?tenantId=0ce9148a-fd30-4ca7-8e88-e3d4f1cc54a0`
- Data lists: StudyMaster, VisitWorkflow, VisitAdmin, VisitClinicalStatus, QCFinding, EDCStatus, PIAction, WorkflowAudit
- Production writes: disabled

## What is working

- All eight DEV lists are connected to the published app.
- Workflow navigation round-trips to Reception, Clinical/CTA, Quality/QC, EDC, PI Actions, Study Admin and Audit, with return navigation.
- Audit is displayed read-only in the app.
- DEV SharePoint required Yes/No settings were corrected so legitimate No values can be stored.
- Site regional settings were changed to South Africa (UTC+02:00); propagation still needs verification.
- Live Power Automate guards: `Trident DEV - EDC completion guard`, `Trident DEV - PIAction completion guard`, and `Trident DEV - QCFinding closure guard`.
- Flow ID: `492182f1-2777-4502-9a06-29dc69a6134a`.
- The corrected EDC guard now accepts `Resolved`, `None`, or blank query status when no open queries remain and `CompletedAt` is populated. Invalid and accepted cases have passed live DEV tests.
- PIAction completion is blocked when `CompletedAt` or `Outcome` is blank. QCFinding closure is blocked when `Resolution` or `ResolvedAt` is blank. Both guards passed invalid, valid and terminating self-trigger tests.
- Live test: fictitious `DEV-UAT-20260930-EDC-001` was deliberately saved as Complete with three open queries, Open query status and no completion timestamp. The flow corrected it to In Progress.
- Two consecutive runs succeeded; the second took the no-action path, confirming no self-trigger loop.

## Known gaps

- PIAction and QCFinding completion guards are deployed and verified.
- Parent VisitWorkflow roll-ups, derived counts, close eligibility and timestamps are not yet automated. Full roll-up design is in `outputs/VISIT_ROLLUP_FLOW_DESIGN.md`.
- Append-only WorkflowAudit creation is not yet enforced. **Item-level Edit permissions alone are insufficient** — users with site Edit access can still create new WorkflowAudit rows directly. Fix requires: (1) break permissions inheritance on the WorkflowAudit list, (2) grant the four named users Read-only on that list, (3) confirm the Power Automate service identity retains Contribute so flows can still insert rows.
- Duplicate business identifiers and date chronology are not yet blocked automatically.
- Claude Code completed the six nonblocking Screen2 formula corrections; generated visual branding still needs final design refinement.
- Role permissions are broader than the intended production role model.

## Deliberate UAT records

- `DEV-UAT-20260930-EDC-001`: invalid Complete state corrected by the live guard.
- `DEV-UAT-20260930-PIA-001`: invalid completion was demoted; a valid completion remained Complete.
- `DEV-UAT-20260930-QC-001`: invalid closure was demoted; a valid closure with resolution evidence and resolved timestamp remained Closed.
- `DEV-UAT-20260930-VA-DUP`: duplicate VisitAdminID and departure before arrival; should be flagged by later validation.

## Collaboration request

Assess the architecture, security boundaries, Power Apps data-source design, Power Automate guard logic, SharePoint schema, and release risks. Return:

1. Findings ranked P0/P1/P2 with concrete evidence from this brief.
2. Any flaw in the EDC guard condition or its safe self-trigger behavior.
3. The smallest sequence of changes required for a safe DEV UAT.
4. Any production-readiness blocker that is missing from this brief.
5. A test matrix for PIAction, QCFinding, roll-ups, timestamps, audit and permissions.
6. Concrete Power Apps formulas, Power Automate expressions, schema edits, or UI changes where you can improve the build.
7. A short ordered queue of the next changes, distinguishing safe DEV changes from anything that needs human approval.

Keep your inspection read-only unless the user explicitly authorizes you to edit the shared project. Send proposed changes back to the primary build agent for implementation and verification. The goal is an iterative two-agent build loop: inspect, propose, implement, test, then review again.
