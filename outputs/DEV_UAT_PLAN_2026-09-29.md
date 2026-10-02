# Trident Operations Central DEV UAT plan

Run date: 2026-09-29

Scope: ClinicalOperationsDEV only. All records use fictitious identifiers beginning `DEV-UAT-20260929`. Production writes remain disabled.

## Baseline checks completed

- SharePoint StudyMaster row `DEV-ACHIEVE-RAM-001` exists.
- VisitWorkflow StudyID lookup resolves `DEV-ACHIEVE-RAM-001`.
- OAuth protected-resource metadata returns HTTP 200 with the custom API resource and fully qualified scopes.
- Unauthenticated `/mcp` returns HTTP 401 with the expected resource-metadata challenge.
- Tenant OpenID configuration returns HTTP 200.
- `/` and `/health` return HTTP 404; no public health route is exposed.
- Power Apps is not deployed.
- Power Automate flows are not deployed.

## Valid transaction set

Create one linked fictitious record in each workflow list using participant key `DEV-P-0001` and visit `Screening`:

1. VisitWorkflow
2. VisitAdmin
3. VisitClinicalStatus
4. QCFinding
5. EDCStatus
6. PIAction
7. WorkflowAudit

Verify lookup integrity, required fields, choice constraints, people fields, saved display, and any resulting automation or roll-up behavior.

## Deliberately invalid transaction set

Use identifiers beginning `DEV-UAT-20260929-NEG` and test:

1. Missing required fields.
2. Unknown StudyID lookup.
3. VisitWorkflow marked closed while downstream prerequisites are incomplete.
4. VisitAdmin departure earlier than arrival.
5. VisitClinicalStatus ready for QC while incomplete or carrying a critical issue.
6. QCFinding closed without closure evidence.
7. EDCStatus complete without completion timestamp and with open-query state.
8. PIAction complete without completion evidence.
9. WorkflowAudit correction or reopen without a reason.
10. Duplicate business keys where the design calls for unique IDs.

Record whether the GUI blocks, flags, accepts, or automatically corrects each case. Accepted invalid records remain clearly marked as DEV UAT evidence until cleanup is separately approved.

## Fix policy

Apply reversible DEV-only fixes that do not broaden permissions or affect production. Record deployment-dependent gaps separately for one consolidated implementation pass.
