/**
 * Proves the security model with real users (System.runAs respects sharing and permission sets):
 *  - Case is Private: agents see only cases owned by their queues.
 *  - Permission sets keep reference data and automation-owned fields read-only for agents.
 *
 * Not tested here: managers seeing their community's cases. That access comes from criteria-based
 * sharing rules, which Salesforce evaluates when a transaction commits, and Apex tests never commit.
 * scripts/apex/verify-security.apex checks it against the real demo users and sample data instead.
 */
@IsTest
private class SecurityModelTest {
  @TestSetup
  static void setup() {
    Community__c society = TestDataFactory.createCommunity(
      'Green Valley Test',
      'GVR',
      'Housing Society'
    );
    Community__c shop = TestDataFactory.createCommunity(
      'UrbanCart Test',
      'UCT',
      'Business'
    );
    Service_Category__c plumbing = TestDataFactory.createCategory(
      'Plumbing',
      'Housing Society',
      24,
      'Maintenance'
    );
    Service_Category__c bill = TestDataFactory.createCategory(
      'Bill Query',
      'Housing Society',
      72,
      'Billing'
    );
    Service_Category__c refund = TestDataFactory.createCategory(
      'Refund',
      'Business',
      72,
      'Billing'
    );
    Unit__c flat = TestDataFactory.createUnits(society.Id, 1)[0];
    Unit__c account = TestDataFactory.createUnits(shop.Id, 1)[0];
    Contact resident = TestDataFactory.createContact('Resident');

    Case maintenanceCase = TestDataFactory.buildCase(
      society.Id,
      flat.Id,
      plumbing.Id,
      resident.Id,
      'Phone'
    );
    maintenanceCase.Subject = 'GVR maintenance';
    Case billingCase = TestDataFactory.buildCase(
      society.Id,
      flat.Id,
      bill.Id,
      resident.Id,
      'Phone'
    );
    billingCase.Subject = 'GVR billing';
    Case shopCase = TestDataFactory.buildCase(
      shop.Id,
      account.Id,
      refund.Id,
      resident.Id,
      'Web'
    );
    shopCase.Subject = 'UCT refund';
    insert new List<Case>{ maintenanceCase, billingCase, shopCase };
  }

  private static Set<String> visibleSubjects() {
    Set<String> subjects = new Set<String>();
    for (Case c : [SELECT Subject FROM Case WITH USER_MODE]) {
      subjects.add(c.Subject);
    }
    return subjects;
  }

  @IsTest
  static void agentSeesOnlyCasesOwnedByTheirQueues() {
    User agent = TestDataFactory.createUser(
      'agentsec',
      'ServDeck_Agent',
      'Maintenance'
    );

    Set<String> subjects;
    Test.startTest();
    System.runAs(agent) {
      subjects = visibleSubjects();
    }
    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'GVR maintenance' },
      subjects,
      'Maintenance agent should see only Maintenance queue cases'
    );
  }

  @IsTest
  static void userWithoutQueueOrGroupSeesNoCases() {
    User outsider = TestDataFactory.createUser(
      'nocase',
      'ServDeck_Agent',
      null
    );

    Set<String> subjects;
    Test.startTest();
    System.runAs(outsider) {
      subjects = visibleSubjects();
    }
    Test.stopTest();

    Assert.isTrue(
      subjects.isEmpty(),
      'Case is Private: no queue, no group, no cases. Saw ' + subjects
    );
  }

  @IsTest
  static void agentCannotEditReferenceData() {
    User agent = TestDataFactory.createUser(
      'agentref',
      'ServDeck_Agent',
      'Maintenance'
    );
    Community__c community = [
      SELECT Id
      FROM Community__c
      WHERE Community_Code__c = 'GVR'
    ];

    Boolean blocked = false;
    Test.startTest();
    System.runAs(agent) {
      try {
        community.City__c = 'Changed';
        Database.update(community, AccessLevel.USER_MODE);
      } catch (Exception e) {
        blocked = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(blocked, 'Agents have read-only access to communities');
  }

  @IsTest
  static void agentCannotSetAutomationOwnedFields() {
    User agent = TestDataFactory.createUser(
      'agentfls',
      'ServDeck_Agent',
      'Maintenance'
    );
    Case c = [SELECT Id FROM Case WHERE Subject = 'GVR maintenance'];

    Boolean blocked = false;
    Test.startTest();
    System.runAs(agent) {
      try {
        Database.update(
          new Case(Id = c.Id, Escalated__c = true),
          AccessLevel.USER_MODE
        );
      } catch (Exception e) {
        blocked = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(
      blocked,
      'Escalated is set by the escalation flow only; agents have read-only field access'
    );
  }

  @IsTest
  static void agentCanResolveTheirQueueCase() {
    User agent = TestDataFactory.createUser(
      'agentok',
      'ServDeck_Agent',
      'Maintenance'
    );
    Case c = [SELECT Id FROM Case WHERE Subject = 'GVR maintenance'];

    Test.startTest();
    System.runAs(agent) {
      Database.update(
        new Case(
          Id = c.Id,
          Status = 'Closed',
          Resolution_Note__c = 'Replaced the valve'
        ),
        AccessLevel.USER_MODE
      );
    }
    Test.stopTest();

    Assert.areEqual(
      'Closed',
      [SELECT Status FROM Case WHERE Id = :c.Id].Status,
      'Agent should be able to close a queue case'
    );
  }
}
