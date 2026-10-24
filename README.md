# ServDeck

A configurable service desk built on Salesforce for any organisation that serves a group of
people: a housing society, a hostel or campus, a co-working space, or a business handling customer
complaints.

Requests are raised by web form or email, routed to the right team by service category, tracked
against an SLA, escalated when overdue, and rated after closing. One data model serves every kind of
organisation, switched by **Organisation Type** and its service categories.

> 🚧 Work in progress. Sections marked _TODO_ are filled in as each phase is built.

## Demo

_TODO: 2-minute demo video (request → auto-routed → escalated → resolved → rated → dashboard)._

## Why it's built this way

- **Standard objects first:** Case, Contact, Account, Queue and Case Comment do the heavy lifting.
  There is no custom "Ticket" object.
- **Clicks before code:** routing, SLA, acknowledgement, escalation and feedback are Flows.
- **Apex only where justified:** a bulk-safe duplicate-case guard, with a trigger handler and tests.
- **Security by permission sets:** Agent, Manager and Admin, plus sharing so agents see only their
  queues' cases.

## Data model

_TODO: ERD image from Schema Builder._

| Object                                      | Type                               | Purpose                                           |
| ------------------------------------------- | ---------------------------------- | ------------------------------------------------- |
| Community__c                                | Custom                             | The society, campus, co-working space or business |
| Unit__c                                     | Custom (master-detail → Community) | Flat, room, shop, desk or customer account        |
| Occupancy__c                                | Custom junction (Unit ↔ Contact)   | Who occupies which unit, in what role, and when   |
| Service_Category__c                         | Custom                             | Category with SLA hours and a default queue       |
| Feedback__c                                 | Custom (master-detail → Case)      | 1–5 rating and comment after a case closes        |
| Case, Contact, Account, Queue, Case Comment | Standard                           | Requests, people, teams and updates               |

## Features

| #   | Feature                                   | Built with                             | Status |
| --- | ----------------------------------------- | -------------------------------------- | ------ |
| 1   | Data model + Lightning app                | Objects, fields, layouts               | _TODO_ |
| 2   | Two demo setups (housing society, retail) | `sf data import tree`                  | _TODO_ |
| 3   | Validation                                | Validation rules                       | _TODO_ |
| 4   | Routing + SLA due date                    | Record-triggered Flow                  | _TODO_ |
| 5   | Auto-acknowledge email                    | Record-triggered Flow + email template | _TODO_ |
| 6   | Escalation of overdue cases               | Flow                                   | _TODO_ |
| 7   | Duplicate case guard                      | Apex trigger + handler                 | _TODO_ |
| 8   | Feedback request on close                 | Record-triggered Flow                  | _TODO_ |
| 9   | Unit 360                                  | LWC + Apex controller                  | _TODO_ |
| 10  | Security                                  | Permission sets + sharing              | _TODO_ |
| 11  | Intake                                    | Web-to-Case, Email-to-Case             | _TODO_ |
| 12  | Reports and dashboard                     | Reports, dashboard                     | _TODO_ |

## Deploy to your own org

Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli), Node.js, and
a free [Developer Edition org](https://developer.salesforce.com/signup).

```powershell
git clone <this repo>
cd ServDeck
npm install
sf org login web --alias sd --set-default
sf project deploy start --source-dir force-app
```

> If login fails with `OAUTH_APPROVAL_ERROR_GENERIC`, open Setup → **Connected Apps OAuth Usage**,
> click **Install** next to **Salesforce CLI**, and log in again.

_TODO: permission set assignment, sample data load, and post-deploy setup steps._

## Testing

```powershell
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10
npm run test:unit
```

_TODO: coverage results._

## Screenshots

_TODO._
