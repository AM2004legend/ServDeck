# ServDeck — Product Requirements

## Overview

A configurable service desk on Salesforce for communities and customer-facing businesses. One data
model serves a housing society, hostel/campus, co-working space or a retail business, switched by
**Organisation Type** and its service categories.

**Pattern:** the standard ticketing / helpdesk (ITSM) model — requester → ticket → category → team →
SLA → updates → resolution → feedback — plus a property/membership model (community → units →
occupants). Same shape as Salesforce Service Cloud, Zendesk, Freshdesk, ServiceNow.

**Audience:** recruiters and interviewers for Salesforce developer/admin roles.

**Goals**

1. Correct use of standard objects and a clean, explainable data model.
2. Automation mostly in Flow; Apex only where justified, bulk-safe and well tested.
3. Working security model (permission sets, sharing).
4. Demo-able in 2 minutes: request raised → auto-routed → escalated → resolved → rated → dashboard.

## Personas

| Persona                                       | Does                                                               |
| --------------------------------------------- | ------------------------------------------------------------------ |
| Requester (resident / customer)               | Raises a request by web form or email; gets updates; rates service |
| Agent (maintenance staff / support agent)     | Works cases in their queue; adds comments; resolves                |
| Manager (society secretary / support manager) | Watches SLAs and dashboards; handles escalations                   |
| Admin                                         | Configures communities, categories, SLAs, queues, users            |

## Data model

| Object              | Type                 | Fields and relationships                                                                                                                                                                                                        |
| ------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Community__c        | Custom               | Name; Organisation_Type__c (picklist: Housing Society, Hostel/Campus, Co-working, Business); City__c; Manager__c (lookup User)                                                                                                  |
| Unit__c             | Custom               | Master-detail → Community__c; Unit_Number__c; Floor__c; Unit_Type__c (Flat, Room, Shop, Desk, Customer Account)                                                                                                                 |
| Contact             | Standard             | Name, Email, Phone; optional Account (household or company)                                                                                                                                                                     |
| Occupancy__c        | Custom junction      | Master-detail → Unit__c; master-detail → Contact; Role__c (Owner, Tenant, Member, Customer); Start_Date__c; End_Date__c; Is_Active__c (formula)                                                                                 |
| Service_Category__c | Custom               | Name; Organisation_Type__c; SLA_Hours__c (number); Default_Queue_Name__c (text, the Queue's developer name); Active__c                                                                                                          |
| Case                | Standard             | Lookups: ContactId, Community__c, Unit__c, Service_Category__c. Status, Priority, Origin. Custom: SLA_Due__c (datetime), Escalated__c (checkbox), Resolution_Note__c (long text), Resolution_Hours__c (formula or set on close) |
| Queue               | Standard             | Maintenance, Security, Billing, Support (Case as supported object)                                                                                                                                                              |
| Case Comment        | Standard             | Updates on a case                                                                                                                                                                                                               |
| Feedback__c         | Custom               | Master-detail → Case; Rating__c (1–5); Comment__c                                                                                                                                                                               |
| Notice__c           | Custom (should-have) | Master-detail → Community__c; Title; Body; Publish_Date__c                                                                                                                                                                      |

Note: a Case can't be the detail in a master-detail with Community__c/Unit__c (standard objects
can't be details of custom objects in that way), so those are **lookups**.

## Features and acceptance criteria

| #   | Feature             | Built with                                 | Acceptance criteria                                                                                                                                                                     |
| --- | ------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Data model + app    | Objects, fields, layouts, Lightning app    | All objects visible in a "ServDeck" app; Schema Builder matches the table                                                                                                               |
| 2   | Two demo setups     | Sample data                                | Housing society + retail business loaded via `sf data import tree`                                                                                                                      |
| 3   | Validation          | Validation rules                           | Can't close a case without Resolution_Note__c; Unit must belong to the case's Community; Rating 1–5 only                                                                                |
| 4   | Routing + SLA       | Record-triggered Flow (before/after save)  | New case gets owner = category's queue and SLA_Due__c = created time + SLA_Hours__c                                                                                                     |
| 5   | Auto-acknowledge    | Record-triggered Flow + email template     | Requester gets case number and expected resolution time                                                                                                                                 |
| 6   | Escalation          | Scheduled Flow (e.g. hourly)               | Open cases past SLA_Due__c → Escalated__c = true, Priority = High, community manager notified; never escalated twice                                                                    |
| 7   | Duplicate guard     | Apex trigger + handler                     | A new case with the same Unit + Category as an open case created in the last 24 h is blocked with a clear error (or linked as child — choose one and justify); bulk inserts of 200 work |
| 8   | Feedback            | Record-triggered Flow                      | On close, requester receives a feedback request; Feedback__c records ratings                                                                                                            |
| 9   | Unit 360            | LWC + Apex controller                      | On Unit/Contact pages: active occupants, last 10 cases, avg resolution hours, avg rating; loading/empty/error states                                                                    |
| 10  | Security            | Permission sets + sharing                  | Agent sees only cases owned by their queues; Manager sees all in their community; Admin full                                                                                            |
| 11  | Intake              | Web-to-Case (+ Email-to-Case if available) | Submitting the web form creates a Case with Origin = Web                                                                                                                                |
| 12  | Reports & dashboard | Reports, dashboard                         | Open cases by community and category; SLA breach %; avg resolution time; CSAT average and trend                                                                                         |

**Should-have:** Notice__c announcements; amenity booking; Experience Cloud self-service portal
(check what the Developer Edition allows).

**Non-goals:** payments, real SMS/WhatsApp, AI case classification, managed packages.

## Testing

- Apex: `TestDataFactory`; tests for single insert, duplicate blocked, bulk 200, different
  unit/category allowed, closed case doesn't block; 90%+ coverage target; all tests pass with
  `RunLocalTests`.
- LWC: Jest tests for render with data, empty state, error state.
- Flows: Flow Builder debug runs + saved Flow tests where supported.
- Manual: log in as Agent, Manager and Admin test users and check visibility.

## Deliverables

- GitHub repo with all metadata, sample data plan, README (pitch, ERD image, how each feature works,
  how to deploy to a new org, screenshots), 2-minute demo video.

## Interview story

"I reused standard Case, Contact and Queue, added a junction object for many-to-many occupancy,
built routing, SLA and escalation in Flow, and used Apex only for duplicate detection — bulk-safe,
with a handler class and tests at 90%+ coverage. The same org runs a housing society or a retail
support desk by changing Organisation Type and categories."
