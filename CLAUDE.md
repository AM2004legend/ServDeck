# ServDeck — project guide for Claude Code

## What this project is

ServDeck is a configurable service desk built on Salesforce for any organisation that serves a
group of people: a housing society, hostel/campus, co-working space, or a business handling
customer complaints. Requests (standard **Case**) are raised by web form or email, routed to the
right team (**Queue**) by service category, tracked against an SLA, escalated when overdue, and
rated after closing. Managers see dashboards; a Lightning Web Component shows a 360° view of a
unit or customer. Full spec: `docs/PRD.md` — read it before any task.

It's a portfolio project for Salesforce developer/admin roles at consulting firms (Deloitte, IBM,
Accenture, Capgemini, TCS, Infosys). Interviewers care about **good Salesforce judgement**: standard
objects first, clicks (Flow) before code, bulk-safe Apex, real tests, sensible security.

## Who I am and how to work with me

- I'm a 2nd-year BTech CSBS student and **new to Salesforce**. I'm building this to LEARN; I'll be
  asked to explain every object, Flow and class in interviews.
- One phase at a time (see "Phases"). Before a phase: a short plan (what metadata/code, why, and what
  I should do by clicking in Setup myself). Wait for my "go".
- After each phase, explain in plain language: what was built, the Salesforce concepts involved,
  and 2 interview questions I should be able to answer.
- When something is better learned by clicking (Flows, page layouts, reports, queues), **guide me
  step by step in Setup instead of generating XML**, then retrieve it into the repo.
- Never claim something works unless it was deployed and tested. Show command output.
- Ask one short question when unsure. I'm on Windows — give PowerShell commands.
- Don't add features outside the PRD; list ideas at the end instead.

## Tooling

- A free **Salesforce Developer Edition org** (sign-up page may call it "Agentforce Developer
  Edition"), authorised with alias `sd`.
- Salesforce CLI (`sf`), VS Code + Salesforce Extension Pack, Java JDK (for the Apex language
  server), Node.js (for LWC Jest tests).
- Standard SFDX project layout (`force-app/main/default/...`), Git for all metadata.

## Salesforce rules (non-negotiable)

- **Standard objects first:** use Case, Contact, Account, Queue, User, Case Comment. Never create a
  custom "Ticket" object. Custom objects only for what Salesforce lacks (see PRD data model).
- **Clicks before code:** automation in Flow by default. Apex only where Flow is awkward or unsafe
  (the duplicate guard), and say why.
- **Apex quality:**
  - one trigger per object, logic in a handler class (`CaseTriggerHandler`), trigger stays thin
  - bulk-safe: no SOQL or DML inside loops; works for 200 records at once
  - `with sharing` on classes unless there's a stated reason
  - meaningful test classes: positive, negative and bulk (200 records) cases; use `@testSetup` and a
    `TestDataFactory`; assert results, don't just run code. Aim for 90%+ coverage (Salesforce
    requires 75% to deploy to production).
- **LWC quality:** use Lightning Data Service / `@wire` where possible; Apex controller methods are
  `@AuraEnabled(cacheable=true)` for reads; handle loading, empty and error states; Jest tests.
- **Security:** field-level security and object permissions via **permission sets** (Agent,
  Manager, Admin), not by editing profiles heavily. Respect sharing in Apex (`WITH USER_MODE` or
  `with sharing`).
- **Naming:** API names in `Pascal_Case__c`; every custom field has a description and help text.
- **Git is the source of truth:** after any click-built change in Setup, retrieve it into the repo
  and commit. Never leave changes only in the org.
- **Test data only:** fake names, emails and phone numbers. No real people.

## Useful commands

```powershell
sf org login web --alias sd --set-default
sf org open
sf project deploy start --source-dir force-app
sf project retrieve start --metadata "Flow:*" "Layout:*" "Report:*" "Dashboard:*"
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 10
sf data import tree --plan data/sample-plan.json
npm run test:unit        # LWC Jest tests
sf apex tail log         # live debug logs
```

## Phases (build in order, stop after each)

1. **Setup:** check tools (`sf --version`, Java, Node), create SFDX project, authorise org, push an
   empty deploy, `.gitignore`, README skeleton. Guide me through enabling anything needed in Setup.
2. **Data model:** custom objects and fields (Community__c, Unit__c, Occupancy__c,
   Service_Category__c, Feedback__c), custom fields on Case, relationships, page layouts, a
   Lightning app "ServDeck" with tabs. Deploy and show me the ERD in Schema Builder.
3. **Sample data:** two setups — a housing society and a retail business — with communities, units,
   contacts, occupancies, categories and ~30 cases, loadable with `sf data import tree`.
4. **Validation + queues:** validation rules; queues (Maintenance, Security, Billing, Support) with
   members; Service Category → default queue mapping.
5. **Flows (I build them by clicking, you guide):** routing + SLA due date (record-triggered),
   auto-acknowledge email, escalation (scheduled), feedback request on close. Then retrieve into the
   repo. Add Flow tests where possible.
6. **Apex duplicate guard:** `CaseTrigger` + `CaseTriggerHandler` + `TestDataFactory` + tests
   (single, duplicate, bulk 200, different unit/category not blocked).
7. **LWC Unit 360:** component on Unit and Contact pages — occupants, recent cases, average
   resolution time, average rating — with Apex controller, tests for both.
8. **Security:** permission sets Agent / Manager / Admin, sharing so agents see their queue's cases;
   test by logging in as each user.
9. **Intake + reports:** Web-to-Case form (test HTML page), Email-to-Case if available; reports and a
   dashboard (open cases by community/category, SLA breach %, avg resolution time, CSAT).
10. **Ship:** final full test run with coverage, README (pitch, ERD image, feature list, how to
    deploy to a new org, screenshots), 2-minute demo video script.
