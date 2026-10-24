/**
 * Builds ServDeck test records. Methods named create* insert; methods named build* do not,
 * so tests can change fields before inserting.
 */
@IsTest
public class TestDataFactory {
  public static Community__c createCommunity(
    String name,
    String code,
    String organisationType
  ) {
    Community__c community = new Community__c(
      Name = name,
      Community_Code__c = code,
      Organisation_Type__c = organisationType,
      City__c = 'Testville'
    );
    insert community;
    return community;
  }

  public static Service_Category__c createCategory(
    String name,
    String organisationType,
    Integer slaHours,
    String queueName
  ) {
    Service_Category__c category = new Service_Category__c(
      Name = name,
      Organisation_Type__c = organisationType,
      SLA_Hours__c = slaHours,
      Default_Queue_Name__c = queueName,
      Active__c = true
    );
    insert category;
    return category;
  }

  public static List<Unit__c> createUnits(Id communityId, Integer count) {
    List<Unit__c> units = new List<Unit__c>();
    for (Integer i = 0; i < count; i++) {
      units.add(
        new Unit__c(
          Name = 'Unit ' + i,
          Community__c = communityId,
          Unit_Number__c = 'U-' + i,
          Unit_Type__c = 'Flat',
          Floor__c = Math.mod(i, 10)
        )
      );
    }
    insert units;
    return units;
  }

  /**
   * Contact inside a household Account. A contact without an account is a "private contact"
   * that only its owner and admins can see, whatever the Contact sharing default says.
   */
  public static Contact createContact(String lastName) {
    Account household = new Account(Name = lastName + ' Household');
    insert household;
    Contact person = new Contact(
      AccountId = household.Id,
      FirstName = 'Test',
      LastName = lastName,
      Email = lastName.toLowerCase().replaceAll('[^a-z0-9]', '') +
        '@example.com'
    );
    insert person;
    return person;
  }

  public static Occupancy__c createOccupancy(
    Id unitId,
    Id contactId,
    String role,
    Date startDate,
    Date endDate
  ) {
    Occupancy__c occupancy = new Occupancy__c(
      Unit__c = unitId,
      Contact__c = contactId,
      Role__c = role,
      Start_Date__c = startDate,
      End_Date__c = endDate
    );
    insert occupancy;
    return occupancy;
  }

  public static Case buildCase(
    Id communityId,
    Id unitId,
    Id categoryId,
    Id contactId,
    String origin
  ) {
    return new Case(
      Subject = 'Test request',
      Description = 'Created by a unit test',
      Status = 'New',
      Origin = origin,
      Community__c = communityId,
      Unit__c = unitId,
      Service_Category__c = categoryId,
      ContactId = contactId
    );
  }

  public static Id queueId(String developerName) {
    return [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = :developerName
      LIMIT 1
    ]
    .Id;
  }

  /** User with the Standard User profile. Not inserted. */
  public static User buildUser(String alias) {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String unique =
      alias + String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    return new User(
      Alias = alias.left(8),
      Email = alias + '@example.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Test',
      LastName = alias,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_IN',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'Asia/Kolkata',
      Username = unique + '@servdeck.test'
    );
  }

  /** Inserts users, assigns the permission set and adds them to the given queue (null = no queue). */
  public static User createUser(
    String alias,
    String permissionSetName,
    String queueDeveloperName
  ) {
    User u = buildUser(alias);
    // Setup objects (User, PermissionSetAssignment, GroupMember) must not share a transaction
    // with normal records, so they run in their own runAs block.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      Id permissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = :permissionSetName
        LIMIT 1
      ]
      .Id;
      insert new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = permissionSetId
      );
      if (queueDeveloperName != null) {
        insert new GroupMember(
          GroupId = queueId(queueDeveloperName),
          UserOrGroupId = u.Id
        );
      }
    }
    return u;
  }
}
