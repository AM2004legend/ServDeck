/**
 * Data for the Unit 360 component (c-unit360), shown on Unit and Contact record pages.
 *
 * Unit page: who lives/works there now, its last 10 cases, average resolution time and rating.
 * Contact page: the units the person occupies now, plus the same case figures for that person.
 *
 * Every query runs WITH USER_MODE, so the user only sees records and fields their sharing and
 * permission sets allow.
 */
public with sharing class Unit360Controller {
  @TestVisible
  private static final Integer RECENT_CASE_LIMIT = 10;

  public class Summary {
    @AuraEnabled
    public String context; // 'Unit' or 'Contact'
    @AuraEnabled
    public List<Occupant> occupants = new List<Occupant>();
    @AuraEnabled
    public List<CaseRow> recentCases = new List<CaseRow>();
    @AuraEnabled
    public Integer openCases = 0;
    @AuraEnabled
    public Decimal avgResolutionHours;
    @AuraEnabled
    public Decimal avgRating;
  }

  public class Occupant {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String name; // contact name on a Unit page, unit name on a Contact page
    @AuraEnabled
    public Id recordId; // the contact or unit to link to
    @AuraEnabled
    public String role;
    @AuraEnabled
    public Date startDate;
  }

  public class CaseRow {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String caseNumber;
    @AuraEnabled
    public String subject;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String priority;
    @AuraEnabled
    public Datetime createdDate;
    @AuraEnabled
    public Boolean escalated;
    @AuraEnabled
    public Boolean slaBreached;
  }

  @AuraEnabled(cacheable=true)
  public static Summary getSummary(Id recordId) {
    if (recordId == null) {
      throw new AuraHandledException('No record id was provided.');
    }
    try {
      SObjectType recordType = recordId.getSObjectType();
      if (recordType == Unit__c.SObjectType) {
        return unitSummary(recordId);
      }
      if (recordType == Contact.SObjectType) {
        return contactSummary(recordId);
      }
    } catch (QueryException e) {
      // e.g. the user lacks access to a field: show a friendly message instead of a stack trace
      throw new AuraHandledException(
        'You do not have access to some of this information: ' + e.getMessage()
      );
    }
    throw new AuraHandledException(
      'Unit 360 only works on Unit and Contact records.'
    );
  }

  private static Summary unitSummary(Id unitId) {
    Summary s = new Summary();
    s.context = 'Unit';
    for (Occupancy__c o : [
      SELECT Id, Contact__c, Contact__r.Name, Role__c, Start_Date__c
      FROM Occupancy__c
      WHERE Unit__c = :unitId AND Is_Active__c = TRUE
      WITH USER_MODE
      ORDER BY Start_Date__c
    ]) {
      s.occupants.add(occupant(o, o.Contact__c, o.Contact__r.Name));
    }
    s.recentCases = toRows(
      [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Status,
          Priority,
          CreatedDate,
          Escalated__c,
          SLA_Breached__c
        FROM Case
        WHERE Unit__c = :unitId
        WITH USER_MODE
        ORDER BY CreatedDate DESC
        LIMIT :RECENT_CASE_LIMIT
      ]
    );
    s.openCases = [
      SELECT COUNT()
      FROM Case
      WHERE Unit__c = :unitId AND IsClosed = FALSE
      WITH USER_MODE
    ];
    s.avgResolutionHours = average(
      [
        SELECT AVG(Resolution_Hours__c) value
        FROM Case
        WHERE Unit__c = :unitId AND IsClosed = TRUE
        WITH USER_MODE
      ]
    );
    s.avgRating = average(
      [
        SELECT AVG(Rating__c) value
        FROM Feedback__c
        WHERE Case__r.Unit__c = :unitId
        WITH USER_MODE
      ]
    );
    return s;
  }

  private static Summary contactSummary(Id contactId) {
    Summary s = new Summary();
    s.context = 'Contact';
    for (Occupancy__c o : [
      SELECT Id, Unit__c, Unit__r.Name, Role__c, Start_Date__c
      FROM Occupancy__c
      WHERE Contact__c = :contactId AND Is_Active__c = TRUE
      WITH USER_MODE
      ORDER BY Start_Date__c
    ]) {
      s.occupants.add(occupant(o, o.Unit__c, o.Unit__r.Name));
    }
    s.recentCases = toRows(
      [
        SELECT
          Id,
          CaseNumber,
          Subject,
          Status,
          Priority,
          CreatedDate,
          Escalated__c,
          SLA_Breached__c
        FROM Case
        WHERE ContactId = :contactId
        WITH USER_MODE
        ORDER BY CreatedDate DESC
        LIMIT :RECENT_CASE_LIMIT
      ]
    );
    s.openCases = [
      SELECT COUNT()
      FROM Case
      WHERE ContactId = :contactId AND IsClosed = FALSE
      WITH USER_MODE
    ];
    s.avgResolutionHours = average(
      [
        SELECT AVG(Resolution_Hours__c) value
        FROM Case
        WHERE ContactId = :contactId AND IsClosed = TRUE
        WITH USER_MODE
      ]
    );
    s.avgRating = average(
      [
        SELECT AVG(Rating__c) value
        FROM Feedback__c
        WHERE Case__r.ContactId = :contactId
        WITH USER_MODE
      ]
    );
    return s;
  }

  private static Occupant occupant(
    Occupancy__c o,
    Id linkedId,
    String linkedName
  ) {
    Occupant result = new Occupant();
    result.id = o.Id;
    result.recordId = linkedId;
    result.name = linkedName;
    result.role = o.Role__c;
    result.startDate = o.Start_Date__c;
    return result;
  }

  private static List<CaseRow> toRows(List<Case> cases) {
    List<CaseRow> rows = new List<CaseRow>();
    for (Case c : cases) {
      CaseRow row = new CaseRow();
      row.id = c.Id;
      row.caseNumber = c.CaseNumber;
      row.subject = c.Subject;
      row.status = c.Status;
      row.priority = c.Priority;
      row.createdDate = c.CreatedDate;
      row.escalated = c.Escalated__c;
      row.slaBreached = c.SLA_Breached__c;
      rows.add(row);
    }
    return rows;
  }

  /** AVG() over no rows returns null, which the component shows as "No data yet". */
  private static Decimal average(List<AggregateResult> results) {
    Decimal value = (Decimal) results[0].get('value');
    return value == null ? null : value.setScale(1);
  }
}
