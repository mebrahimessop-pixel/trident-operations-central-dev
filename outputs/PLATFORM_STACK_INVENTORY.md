# Microsoft 365 and Power Platform stack inventory

Observed from the user's Microsoft 365 license panel on 2026-10-01. This is a baseline, not a complete tenant inventory.

## Confirmed assigned or available licenses

| License | Observed state | Relevant use in this build |
| --- | --- | --- |
| Microsoft 365 Business Basic | 7 of 7 assigned | Exchange Online, SharePoint, OneDrive, Teams and the Microsoft 365 identity layer used by the DEV app |
| Microsoft Defender for Office 365 Plan 1 | 7 of 7 assigned | Email and collaboration threat protection; useful for operational notifications and security monitoring |
| Microsoft Fabric (Free) | Unlimited available | Development analytics and report prototyping; production sharing and capacity still require a separate entitlement or capacity check |
| Power Apps for Developer | 10,000 of 10,000 available | DEV app and Dataverse experimentation; intended for development and test, not production deployment |
| Power Automate Free | 9,997 of 10,000 available | Standard-connector cloud flows and attended local automation; premium/shared/production automation licensing must be checked separately |
| Exchange Online Archiving for Exchange Online | Not individually assigned | Archive entitlement shown in the panel; confirm mailbox/archive eligibility if required |

## Current Trident use

- SharePoint DEV site is the current operational data layer.
- Power Apps canvas app is the current GUI.
- Power Automate standard SharePoint flow is the current automation layer.
- Azure Container Apps hosts the protected MCP service.
- Microsoft Entra ID provides OAuth and identity.
- Fabric is not yet connected to the Trident DEV data model.
- Defender is not yet connected to an operational alerting or incident workflow.

## Highest-value opportunities

1. Keep SharePoint + Power Apps + standard Power Automate as the DEV MVP path.
2. Use Dataverse only for capabilities SharePoint cannot safely provide, such as richer relational rules, audit modeling, or environment-managed solution packaging.
3. Use Fabric for read-only DEV analytics after the workflow roll-ups and audit data are stable.
4. Use Defender signals for security operations and alerting, not for clinical workflow decisions.
5. Use Business Basic identity, SharePoint groups and Entra groups for role separation, then verify least privilege before production.
6. Inventory the reported 42 apps before consolidating or reusing anything. Capture app name, environment, owner, data sources, connectors, sharing, last-used date, and whether it is production or DEV.

## Required tenant inventory before architecture decisions

- Power Apps: all environments, apps, owners, connections, connectors, sharing and last-used dates.
- Power Automate: all flows, owners, triggers, connectors, run history, failures and premium dependencies.
- SharePoint: sites, lists, permissions, retention, regional settings and audit configuration.
- Entra ID: groups, app registrations, enterprise applications, service principals and conditional access relevant to the solution.
- Fabric: workspaces, capacities, semantic models, gateways and sharing state.
- Defender: available alerts, incidents, policies and export/integration options.
- Microsoft 365: Teams, groups, mailboxes, shared mailboxes, OneDrive and archive status relevant to operations.

## Licensing cautions

- The Power Apps Developer Plan is a development and test entitlement; do not treat it as the production license for the four named users.
- Power Automate Free is suitable for standard-connector development flows, but production sharing, premium connectors, higher run volume and unattended automation need a separate licensing review.
- Fabric Free is suitable for prototyping; confirm capacity and sharing rights before treating reports as an operational production surface.
- The screenshot does not prove that all 42 apps are licensed, healthy, owned, supported or safe to reuse.
