/**
 * Tests the declarative automation on Case (Flows + validation rules) by doing what a user would do
 * and asserting the outcome. Escalation runs on a scheduled path, which Apex tests cannot fire; it is
 * verified in the org with the sample data instead.
 */
@IsTest
private class CaseAutomationTest {
  @TestSetup
  static void setup() {
    Community__c society = TestDataFactory.createCommunity(
      'Test Society',
      'TST',
      'Housing Society'
    );
    Community__c shop = TestDataFactory.createCommunity(
      'Test Shop',
      'SHP',
      'Business'
    );
    TestDataFactory.createCategory(
      'Plumbing',
      'Housing Society',
      24,
      'Maintenance'
    );
    TestDataFactory.createCategory(
      'Unrouted',
      'Housing Society',
      8,
      'No_Such_Queue'
    );
    TestDataFactory.createCategory('Refund', 'Business', 72, 'Billing');
    TestDataFactory.createUnits(society.Id, 1);
    TestDataFactory.createUnits(shop.Id, 1);
    TestDataFactory.createContact('Resident');
  }

  private static Community__c community(String code) {
    return [SELECT Id FROM Community__c WHERE Community_Code__c = :code];
  }

  private static Id categoryId(String name) {
    return [SELECT Id FROM Service_Category__c WHERE Name = :name].Id;
  }

  private static Id unitIn(Id communityId) {
    return [SELECT Id FROM Unit__c WHERE Community__c = :communityId LIMIT 1]
    .Id;
  }

  private static Case newSocietyCase(String categoryName) {
    Id societyId = community('TST').Id;
    return TestDataFactory.buildCase(
      societyId,
      unitIn(societyId),
      categoryId(categoryName),
      [SELECT Id FROM Contact LIMIT 1].Id,
      'Phone'
    );
  }

  // ---------- Routing + SLA (Case - Before Save flow) ----------

  @IsTest
  static void newCaseIsRoutedToCategoryQueueWithSlaDue() {
    Case c = newSocietyCase('Plumbing');
    Datetime before = Datetime.now();

    Test.startTest();
    insert c;
    Test.stopTest();

    Case saved = [
      SELECT OwnerId, SLA_Due__c, Community_Code__c
      FROM Case
      WHERE Id = :c.Id
    ];
    Assert.areEqual(
      TestDataFactory.queueId('Maintenance'),
      saved.OwnerId,
      'Owner should be the Maintenance queue'
    );
    Assert.isNotNull(saved.SLA_Due__c, 'SLA Due should be set');
    Long minutesFromExpected =
      Math.abs(saved.SLA_Due__c.getTime() - before.addHours(24).getTime()) /
      60000;
    Assert.isTrue(
      minutesFromExpected <= 2,
      'SLA Due should be about 24h after creation, off by ' +
        minutesFromExpected +
        ' min'
    );
    Assert.areEqual(
      'TST',
      saved.Community_Code__c,
      'Community Code should be copied for sharing rules'
    );
  }

  @IsTest
  static void presetSlaDueIsKept() {
    Case c = newSocietyCase('Plumbing');
    Datetime preset = Datetime.newInstance(2030, 1, 1, 9, 0, 0);
    c.SLA_Due__c = preset;

    Test.startTest();
    insert c;
    Test.stopTest();

    Assert.areEqual(
      preset,
      [SELECT SLA_Due__c FROM Case WHERE Id = :c.Id].SLA_Due__c,
      'Preset SLA Due must not be overwritten'
    );
  }

  @IsTest
  static void categoryWithUnknownQueueKeepsCreatorAsOwner() {
    Case c = newSocietyCase('Unrouted');

    Test.startTest();
    insert c;
    Test.stopTest();

    Case saved = [SELECT OwnerId, SLA_Due__c FROM Case WHERE Id = :c.Id];
    Assert.areEqual(
      UserInfo.getUserId(),
      saved.OwnerId,
      'No queue found: owner should stay the creator'
    );
    Assert.isNotNull(saved.SLA_Due__c, 'SLA Due should still be set');
  }

  @IsTest
  static void caseWithoutCategoryIsNotRouted() {
    Case c = newSocietyCase('Plumbing');
    c.Service_Category__c = null;

    Test.startTest();
    insert c;
    Test.stopTest();

    Case saved = [SELECT OwnerId, SLA_Due__c FROM Case WHERE Id = :c.Id];
    Assert.areEqual(
      UserInfo.getUserId(),
      saved.OwnerId,
      'Uncategorised case stays with its creator'
    );
    Assert.isNull(saved.SLA_Due__c, 'No category means no SLA');
  }

  @IsTest
  static void changingCommunityUpdatesCommunityCode() {
    Case c = newSocietyCase('Plumbing');
    c.Unit__c = null;
    c.Service_Category__c = null;
    insert c;

    Test.startTest();
    c.Community__c = community('SHP').Id;
    update c;
    Test.stopTest();

    Assert.areEqual(
      'SHP',
      [SELECT Community_Code__c FROM Case WHERE Id = :c.Id].Community_Code__c
    );
  }

  // ---------- Resolution time (Case - Before Save flow) ----------

  @IsTest
  static void closingCaseStoresResolutionHours() {
    Case c = newSocietyCase('Plumbing');
    insert c;
    Test.setCreatedDate(c.Id, Datetime.now().addHours(-10));

    Test.startTest();
    c.Status = 'Closed';
    c.Resolution_Note__c = 'Replaced the washer';
    update c;
    Test.stopTest();

    Case saved = [
      SELECT Resolution_Hours__c, SLA_Breached__c
      FROM Case
      WHERE Id = :c.Id
    ];
    Assert.isTrue(
      saved.Resolution_Hours__c >= 9.9 && saved.Resolution_Hours__c <= 10.1,
      'Expected about 10 hours, got ' + saved.Resolution_Hours__c
    );
    Assert.isFalse(saved.SLA_Breached__c, '10 hours is inside a 24 hour SLA');
  }

  @IsTest
  static void closingAfterSlaMarksBreached() {
    Case c = newSocietyCase('Plumbing');
    insert c;
    Test.setCreatedDate(c.Id, Datetime.now().addHours(-30));

    Test.startTest();
    c.Status = 'Closed';
    c.Resolution_Note__c = 'Fixed late';
    update c;
    Test.stopTest();

    Assert.isTrue(
      [SELECT SLA_Breached__c FROM Case WHERE Id = :c.Id].SLA_Breached__c,
      '30 hours breaches a 24 hour SLA'
    );
  }

  // ---------- Validation rules ----------

  @IsTest
  static void cannotCloseWithoutResolutionNote() {
    Case c = newSocietyCase('Plumbing');
    insert c;

    Test.startTest();
    c.Status = 'Closed';
    Database.SaveResult result = Database.update(c, false);
    Test.stopTest();

    Assert.isFalse(
      result.isSuccess(),
      'Closing without a resolution note should fail'
    );
    Assert.isTrue(
      result.getErrors()[0].getMessage().contains('Resolution Note'),
      result.getErrors()[0].getMessage()
    );
  }

  @IsTest
  static void unitMustBelongToCaseCommunity() {
    Case c = newSocietyCase('Plumbing');
    c.Unit__c = unitIn(community('SHP').Id);

    Test.startTest();
    Database.SaveResult result = Database.insert(c, false);
    Test.stopTest();

    Assert.isFalse(
      result.isSuccess(),
      'A unit from another community should be rejected'
    );
    Assert.isTrue(
      result.getErrors()[0].getMessage().contains('different community'),
      result.getErrors()[0].getMessage()
    );
  }

  @IsTest
  static void categoryMustMatchCommunityType() {
    Case c = newSocietyCase('Plumbing');
    c.Service_Category__c = categoryId('Refund');

    Test.startTest();
    Database.SaveResult result = Database.insert(c, false);
    Test.stopTest();

    Assert.isFalse(
      result.isSuccess(),
      'A Business category on a Housing Society case should be rejected'
    );
  }

  @IsTest
  static void ratingMustBeBetweenOneAndFive() {
    Case c = newSocietyCase('Plumbing');
    insert c;

    Test.startTest();
    List<Database.SaveResult> results = Database.insert(
      new List<Feedback__c>{
        new Feedback__c(Case__c = c.Id, Rating__c = 0),
        new Feedback__c(Case__c = c.Id, Rating__c = 6),
        new Feedback__c(Case__c = c.Id, Rating__c = 5, Comment__c = 'Great')
      },
      false
    );
    Test.stopTest();

    Assert.isFalse(results[0].isSuccess(), 'Rating 0 should be rejected');
    Assert.isFalse(results[1].isSuccess(), 'Rating 6 should be rejected');
    Assert.isTrue(results[2].isSuccess(), 'Rating 5 should be accepted');
  }

  @IsTest
  static void occupancyCannotEndBeforeItStarts() {
    Id unitId = unitIn(community('TST').Id);
    Id contactId = [SELECT Id FROM Contact LIMIT 1].Id;

    Test.startTest();
    Database.SaveResult result = Database.insert(
      new Occupancy__c(
        Unit__c = unitId,
        Contact__c = contactId,
        Role__c = 'Tenant',
        Start_Date__c = Date.today(),
        End_Date__c = Date.today().addDays(-1)
      ),
      false
    );
    Test.stopTest();

    Assert.isFalse(
      result.isSuccess(),
      'End date before start date should be rejected'
    );
  }

  @IsTest
  static void slaHoursMustBePositive() {
    Test.startTest();
    Database.SaveResult result = Database.insert(
      new Service_Category__c(
        Name = 'Broken',
        Organisation_Type__c = 'Business',
        SLA_Hours__c = 0,
        Default_Queue_Name__c = 'Support'
      ),
      false
    );
    Test.stopTest();

    Assert.isFalse(result.isSuccess(), 'Zero SLA hours should be rejected');
  }

  // ---------- Acknowledgement and feedback flows ----------

  @IsTest
  static void createAndCloseRunEmailFlowsWithoutErrors() {
    Case c = newSocietyCase('Plumbing');

    Test.startTest();
    insert c; // acknowledgement email alert (async path)
    c.Status = 'Closed';
    c.Resolution_Note__c = 'Done';
    update c; // feedback request email alert (async path)
    Test.stopTest(); // async paths run here

    Assert.areEqual(
      'Closed',
      [SELECT Status FROM Case WHERE Id = :c.Id].Status,
      'Email flows must not block the case'
    );
  }
}
