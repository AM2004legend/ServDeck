@IsTest
private class Unit360ControllerTest {
  @TestSetup
  static void setup() {
    Community__c community = TestDataFactory.createCommunity(
      'Test Society',
      'TST',
      'Housing Society'
    );
    Service_Category__c plumbing = TestDataFactory.createCategory(
      'Plumbing',
      'Housing Society',
      24,
      'Maintenance'
    );
    Service_Category__c electrical = TestDataFactory.createCategory(
      'Electrical',
      'Housing Society',
      24,
      'Maintenance'
    );
    List<Unit__c> units = TestDataFactory.createUnits(community.Id, 2); // Unit 0 is busy, Unit 1 stays empty

    Contact owner = TestDataFactory.createContact('Owner');
    Contact formerTenant = TestDataFactory.createContact('Former Tenant');
    TestDataFactory.createOccupancy(
      units[0].Id,
      owner.Id,
      'Owner',
      Date.today().addYears(-2),
      null
    );
    TestDataFactory.createOccupancy(
      units[0].Id,
      formerTenant.Id,
      'Tenant',
      Date.today().addYears(-1),
      Date.today().addDays(-10)
    );

    // Two closed cases (4h and 8h to resolve, rated 4 and 5) and one open case.
    Case closedA = TestDataFactory.buildCase(
      community.Id,
      units[0].Id,
      plumbing.Id,
      owner.Id,
      'Phone'
    );
    closedA.Status = 'Closed';
    closedA.Resolution_Note__c = 'Fixed';
    closedA.Resolution_Hours__c = 4;
    Case closedB = TestDataFactory.buildCase(
      community.Id,
      units[0].Id,
      electrical.Id,
      owner.Id,
      'Phone'
    );
    closedB.Status = 'Closed';
    closedB.Resolution_Note__c = 'Fixed';
    closedB.Resolution_Hours__c = 8;
    Case open = TestDataFactory.buildCase(
      community.Id,
      units[0].Id,
      plumbing.Id,
      owner.Id,
      'Web'
    );
    insert new List<Case>{ closedA, closedB, open };
    insert new List<Feedback__c>{
      new Feedback__c(Case__c = closedA.Id, Rating__c = 4),
      new Feedback__c(Case__c = closedB.Id, Rating__c = 5)
    };
  }

  private static Unit__c unit(String name) {
    return [SELECT Id FROM Unit__c WHERE Name = :name];
  }

  @IsTest
  static void unitSummaryShowsActiveOccupantsCasesAndAverages() {
    Test.startTest();
    Unit360Controller.Summary s = Unit360Controller.getSummary(
      unit('Unit 0').Id
    );
    Test.stopTest();

    Assert.areEqual('Unit', s.context);
    Assert.areEqual(
      1,
      s.occupants.size(),
      'Only the active occupancy should be listed'
    );
    Assert.areEqual('Test Owner', s.occupants[0].name);
    Assert.areEqual('Owner', s.occupants[0].role);
    Assert.areEqual(3, s.recentCases.size());
    Assert.areEqual(1, s.openCases);
    Assert.areEqual(6.0, s.avgResolutionHours, 'Average of 4h and 8h');
    Assert.areEqual(4.5, s.avgRating, 'Average of ratings 4 and 5');
  }

  @IsTest
  static void contactSummaryShowsTheirUnitsAndCases() {
    Contact owner = [SELECT Id FROM Contact WHERE LastName = 'Owner'];

    Test.startTest();
    Unit360Controller.Summary s = Unit360Controller.getSummary(owner.Id);
    Test.stopTest();

    Assert.areEqual('Contact', s.context);
    Assert.areEqual(1, s.occupants.size());
    Assert.areEqual(
      'Unit 0',
      s.occupants[0].name,
      'Contact page lists the units the person occupies'
    );
    Assert.areEqual(3, s.recentCases.size());
    Assert.areEqual(1, s.openCases);
    Assert.areEqual(6.0, s.avgResolutionHours);
    Assert.areEqual(4.5, s.avgRating);
  }

  @IsTest
  static void emptyUnitReturnsEmptyListsAndNoAverages() {
    Test.startTest();
    Unit360Controller.Summary s = Unit360Controller.getSummary(
      unit('Unit 1').Id
    );
    Test.stopTest();

    Assert.isTrue(s.occupants.isEmpty());
    Assert.isTrue(s.recentCases.isEmpty());
    Assert.areEqual(0, s.openCases);
    Assert.isNull(s.avgResolutionHours, 'No closed cases means no average');
    Assert.isNull(s.avgRating, 'No feedback means no average');
  }

  @IsTest
  static void recentCasesAreLimitedToTenNewestFirst() {
    Id communityId = [SELECT Id FROM Community__c LIMIT 1].Id;
    Id unitId = unit('Unit 1').Id;
    // Closed-on-create cases skip the duplicate guard, so the same unit + category can repeat.
    Id categoryId = [SELECT Id FROM Service_Category__c WHERE Name = 'Plumbing']
    .Id;
    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 12; i++) {
      Case c = TestDataFactory.buildCase(
        communityId,
        unitId,
        categoryId,
        null,
        'Phone'
      );
      c.Subject = 'Case ' + i;
      c.Status = 'Closed';
      c.Resolution_Note__c = 'Done';
      cases.add(c);
    }
    insert cases;
    for (Integer i = 0; i < 12; i++) {
      Test.setCreatedDate(cases[i].Id, Datetime.now().addDays(-12 + i));
    }

    Test.startTest();
    Unit360Controller.Summary s = Unit360Controller.getSummary(unitId);
    Test.stopTest();

    Assert.areEqual(Unit360Controller.RECENT_CASE_LIMIT, s.recentCases.size());
    Assert.areEqual(
      'Case 11',
      s.recentCases[0].subject,
      'Newest case should come first'
    );
  }

  @IsTest
  static void missingIdIsRejected() {
    try {
      Unit360Controller.getSummary(null);
      Assert.fail('Expected an exception');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  static void unsupportedRecordTypeIsRejected() {
    Id caseId = [SELECT Id FROM Case LIMIT 1].Id;
    try {
      Unit360Controller.getSummary(caseId);
      Assert.fail('Expected an exception for a Case id');
    } catch (AuraHandledException e) {
      Assert.isNotNull(e.getMessage());
    }
  }

  @IsTest
  static void agentWithPermissionSetCanReadSummary() {
    User agent = TestDataFactory.createUser(
      'agent360',
      'ServDeck_Agent',
      'Maintenance'
    );
    Id unitId = unit('Unit 0').Id;

    Unit360Controller.Summary s;
    Test.startTest();
    System.runAs(agent) {
      s = Unit360Controller.getSummary(unitId);
    }
    Test.stopTest();

    Assert.areEqual(
      1,
      s.occupants.size(),
      'Agent can read occupancies of a unit'
    );
    Assert.isTrue(
      s.recentCases.size() > 0,
      'Agent sees the Maintenance queue cases'
    );
  }
}
