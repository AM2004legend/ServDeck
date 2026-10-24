@IsTest
private class CaseTriggerHandlerTest {
  @TestSetup
  static void setup() {
    Community__c community = TestDataFactory.createCommunity(
      'Test Society',
      'TST',
      'Housing Society'
    );
    TestDataFactory.createCategory(
      'Plumbing',
      'Housing Society',
      24,
      'Maintenance'
    );
    TestDataFactory.createCategory(
      'Electrical',
      'Housing Society',
      24,
      'Maintenance'
    );
    TestDataFactory.createUnits(community.Id, 2);
    TestDataFactory.createContact('Resident');
  }

  private class Fixture {
    Id communityId = [SELECT Id FROM Community__c LIMIT 1].Id;
    Id plumbingId = [SELECT Id FROM Service_Category__c WHERE Name = 'Plumbing']
    .Id;
    Id electricalId = [
      SELECT Id
      FROM Service_Category__c
      WHERE Name = 'Electrical'
    ]
    .Id;
    List<Unit__c> units = [SELECT Id FROM Unit__c ORDER BY Name];
    Id contactId = [SELECT Id FROM Contact LIMIT 1].Id;

    Case buildCase(Integer unitIndex, Id categoryId, String origin) {
      return TestDataFactory.buildCase(
        communityId,
        units[unitIndex].Id,
        categoryId,
        contactId,
        origin
      );
    }
  }

  @IsTest
  static void singleCaseIsCreated() {
    Fixture f = new Fixture();

    Test.startTest();
    Case c = f.buildCase(0, f.plumbingId, 'Phone');
    insert c;
    Test.stopTest();

    Case saved = [SELECT Id, ParentId FROM Case WHERE Id = :c.Id];
    Assert.isNull(
      saved.ParentId,
      'A first case must not be linked to anything'
    );
  }

  @IsTest
  static void duplicateFromStaffIsBlockedWithClearError() {
    Fixture f = new Fixture();
    Case original = f.buildCase(0, f.plumbingId, 'Phone');
    insert original;
    String originalNumber = [
      SELECT CaseNumber
      FROM Case
      WHERE Id = :original.Id
    ]
    .CaseNumber;

    Test.startTest();
    Database.SaveResult result = Database.insert(
      f.buildCase(0, f.plumbingId, 'Phone'),
      false
    );
    Test.stopTest();

    Assert.isFalse(result.isSuccess(), 'Duplicate case should be blocked');
    String message = result.getErrors()[0].getMessage();
    Assert.isTrue(
      message.contains(originalNumber),
      'Error should name the open case: ' + message
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Case],
      'Only the original case should exist'
    );
  }

  @IsTest
  static void duplicateFromWebIsLinkedAsChild() {
    Fixture f = new Fixture();
    Case original = f.buildCase(0, f.plumbingId, 'Phone');
    insert original;

    Test.startTest();
    Case fromWeb = f.buildCase(0, f.plumbingId, 'Web');
    insert fromWeb;
    Case fromEmail = f.buildCase(0, f.plumbingId, 'Email');
    insert fromEmail;
    Test.stopTest();

    for (Case c : [
      SELECT ParentId
      FROM Case
      WHERE Id IN :new List<Id>{ fromWeb.Id, fromEmail.Id }
    ]) {
      Assert.areEqual(
        original.Id,
        c.ParentId,
        'Web/Email duplicates should be linked to the open case'
      );
    }
  }

  @IsTest
  static void differentUnitOrCategoryIsNotBlocked() {
    Fixture f = new Fixture();
    insert f.buildCase(0, f.plumbingId, 'Phone');

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(
      new List<Case>{
        f.buildCase(1, f.plumbingId, 'Phone'),
        f.buildCase(0, f.electricalId, 'Phone')
      },
      false
    );
    Test.stopTest();

    for (Database.SaveResult r : results) {
      Assert.isTrue(
        r.isSuccess(),
        'Different unit or category must be allowed: ' + r.getErrors()
      );
    }
  }

  @IsTest
  static void closedCaseDoesNotBlock() {
    Fixture f = new Fixture();
    Case closed = f.buildCase(0, f.plumbingId, 'Phone');
    closed.Status = 'Closed';
    closed.Resolution_Note__c = 'Fixed the tap';
    insert closed;

    Test.startTest();
    Database.SaveResult result = Database.insert(
      f.buildCase(0, f.plumbingId, 'Phone'),
      false
    );
    Test.stopTest();

    Assert.isTrue(
      result.isSuccess(),
      'A closed case must not block a new one: ' + result.getErrors()
    );
  }

  @IsTest
  static void openCaseOlderThanWindowDoesNotBlock() {
    Fixture f = new Fixture();
    Case old = f.buildCase(0, f.plumbingId, 'Phone');
    insert old;
    Test.setCreatedDate(
      old.Id,
      Datetime.now().addHours(-(CaseTriggerHandler.DUPLICATE_WINDOW_HOURS + 1))
    );

    Test.startTest();
    Database.SaveResult result = Database.insert(
      f.buildCase(0, f.plumbingId, 'Phone'),
      false
    );
    Test.stopTest();

    Assert.isTrue(
      result.isSuccess(),
      'Cases older than the window must not block: ' + result.getErrors()
    );
  }

  @IsTest
  static void duplicatesInsideOneInsertKeepOnlyTheFirst() {
    Fixture f = new Fixture();

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(
      new List<Case>{
        f.buildCase(0, f.plumbingId, 'Phone'),
        f.buildCase(0, f.plumbingId, 'Phone')
      },
      false
    );
    Test.stopTest();

    Assert.isTrue(
      results[0].isSuccess(),
      'First case in the batch should be saved'
    );
    Assert.isFalse(
      results[1].isSuccess(),
      'Second identical case in the batch should be blocked'
    );
  }

  @IsTest
  static void bulkInsertOf200DistinctCasesSucceeds() {
    Fixture f = new Fixture();
    List<Unit__c> units = TestDataFactory.createUnits(f.communityId, 200);
    List<Case> cases = new List<Case>();
    for (Unit__c u : units) {
      cases.add(
        TestDataFactory.buildCase(
          f.communityId,
          u.Id,
          f.plumbingId,
          f.contactId,
          'Phone'
        )
      );
    }

    Test.startTest();
    insert cases;
    Integer queriesUsed = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Case],
      'All 200 cases should be inserted'
    );
    Assert.isTrue(
      queriesUsed < 20,
      'Insert of 200 cases should use few queries, used ' + queriesUsed
    );
  }

  @IsTest
  static void bulkInsertOf200DuplicatesIsHandledPerRecord() {
    Fixture f = new Fixture();
    insert f.buildCase(0, f.plumbingId, 'Phone');
    List<Case> webDuplicates = new List<Case>();
    List<Case> staffDuplicates = new List<Case>();
    for (Integer i = 0; i < 100; i++) {
      webDuplicates.add(f.buildCase(0, f.plumbingId, 'Web'));
      staffDuplicates.add(f.buildCase(0, f.plumbingId, 'Phone'));
    }
    List<Case> all = new List<Case>();
    all.addAll(webDuplicates);
    all.addAll(staffDuplicates);

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(all, false);
    Test.stopTest();

    Integer saved = 0;
    Integer blocked = 0;
    for (Database.SaveResult r : results) {
      if (r.isSuccess()) {
        saved++;
      } else {
        blocked++;
      }
    }
    Assert.areEqual(
      100,
      saved,
      'All 100 web duplicates should be saved as children'
    );
    Assert.areEqual(100, blocked, 'All 100 staff duplicates should be blocked');
    Assert.areEqual(
      100,
      [SELECT COUNT() FROM Case WHERE ParentId != NULL],
      'Web duplicates should be linked'
    );
  }

  @IsTest
  static void webIntakeUserWithoutLookupAccessGetsDuplicateLinked() {
    // Like the Automated Case User behind Web-to-Case: it can only write the web form text fields.
    // The flow fills Unit/Category in system context, then the guard must still be able to query them.
    Fixture f = new Fixture();
    TestDataFactory.createCommunity('Web Society', 'WEB', 'Housing Society');
    Id webCommunityId = [
      SELECT Id
      FROM Community__c
      WHERE Community_Code__c = 'WEB'
    ]
    .Id;
    insert new Unit__c(
      Name = 'Web Flat',
      Community__c = webCommunityId,
      Unit_Number__c = 'W-1',
      Unit_Type__c = 'Flat'
    );
    User intake = TestDataFactory.createUser(
      'webintk',
      'ServDeck_Web_Intake',
      null
    );

    Case first = webCase();
    Case second = webCase();
    Test.startTest();
    System.runAs(intake) {
      // Web-to-Case inserts the record itself (system mode); triggers and flows still run as this user.
      Database.insert(first, AccessLevel.SYSTEM_MODE);
      Database.insert(second, AccessLevel.SYSTEM_MODE);
    }
    Test.stopTest();

    Case savedFirst = [
      SELECT Unit__r.Name, Service_Category__r.Name, OwnerId
      FROM Case
      WHERE Id = :first.Id
    ];
    Assert.areEqual(
      'Web Flat',
      savedFirst.Unit__r.Name,
      'Flow should resolve the unit from the web form text'
    );
    Assert.areEqual(
      'Plumbing',
      savedFirst.Service_Category__r.Name,
      'Flow should resolve the category'
    );
    Assert.areEqual(
      TestDataFactory.queueId('Maintenance'),
      savedFirst.OwnerId,
      'Web case should be routed'
    );
    Assert.areEqual(
      first.Id,
      [SELECT ParentId FROM Case WHERE Id = :second.Id].ParentId,
      'Web duplicate should be linked'
    );
  }

  private static Case webCase() {
    return new Case(
      Subject = 'Tap dripping',
      Origin = 'Web',
      Status = 'New',
      SuppliedEmail = 'someone@example.com',
      Community_Code__c = 'WEB',
      Web_Unit_Number__c = 'W-1',
      Web_Category__c = 'Plumbing'
    );
  }
}
