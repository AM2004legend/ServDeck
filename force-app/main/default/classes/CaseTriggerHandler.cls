/**
 * Handler for CaseTrigger.
 *
 * Duplicate guard: a new case for the same Unit + Service Category as an open case created in the
 * last 24 hours is a duplicate.
 *  - Created by staff (phone, manual entry, API): blocked with a clear error, so the agent can add a
 *    comment to the existing case instead.
 *  - Created from Web or Email: linked to the open case as a child (ParentId). Web-to-Case and
 *    Email-to-Case requesters never see an error, so blocking would silently lose their request.
 *
 * Runs WITHOUT sharing and the query WITH SYSTEM_MODE on purpose: duplicates must be found even when
 * the person creating the case cannot see the existing one or the ServDeck fields (an agent in another
 * queue, or the Automated Case User behind Web-to-Case, which has no access to Unit__c). The class only
 * reads Id and CaseNumber of matching cases and never returns records to the caller.
 *
 * Bulk-safe: one SOQL query for the whole batch, no DML (before-insert changes are saved by the platform).
 */
public without sharing class CaseTriggerHandler {
  @TestVisible
  private static final Integer DUPLICATE_WINDOW_HOURS = 24;

  @TestVisible
  private static final Set<String> LINK_INSTEAD_OF_BLOCK_ORIGINS = new Set<String>{
    'Web',
    'Email'
  };

  public void run() {
    switch on Trigger.operationType {
      when BEFORE_INSERT {
        handleDuplicates((List<Case>) Trigger.new);
      }
    }
  }

  public void handleDuplicates(List<Case> newCases) {
    List<Case> candidates = new List<Case>();
    Set<Id> unitIds = new Set<Id>();
    Set<Id> categoryIds = new Set<Id>();
    for (Case c : newCases) {
      // Closed-on-create cases (e.g. migrated history) are not new work, so they are never duplicates.
      if (
        c.Unit__c != null &&
        c.Service_Category__c != null &&
        c.Status != 'Closed'
      ) {
        candidates.add(c);
        unitIds.add(c.Unit__c);
        categoryIds.add(c.Service_Category__c);
      }
    }
    if (candidates.isEmpty()) {
      return;
    }

    // Oldest matching open case per Unit + Category key.
    Map<String, Case> openCaseByKey = new Map<String, Case>();
    Datetime windowStart = Datetime.now().addHours(-DUPLICATE_WINDOW_HOURS);
    for (Case existing : [
      SELECT Id, CaseNumber, Unit__c, Service_Category__c
      FROM Case
      WHERE
        IsClosed = FALSE
        AND Unit__c IN :unitIds
        AND Service_Category__c IN :categoryIds
        AND CreatedDate >= :windowStart
      WITH SYSTEM_MODE
      ORDER BY CreatedDate ASC
    ]) {
      String key = keyOf(existing);
      if (!openCaseByKey.containsKey(key)) {
        openCaseByKey.put(key, existing);
      }
    }

    Set<String> keysSeenInBatch = new Set<String>();
    for (Case c : candidates) {
      String key = keyOf(c);
      Case existing = openCaseByKey.get(key);
      if (existing != null) {
        if (LINK_INSTEAD_OF_BLOCK_ORIGINS.contains(c.Origin)) {
          c.ParentId = existing.Id;
        } else {
          c.addError(
            'Case ' +
              existing.CaseNumber +
              ' is already open for this unit and service category (raised in the last ' +
              DUPLICATE_WINDOW_HOURS +
              ' hours). Add a comment to that case instead of creating a new one.'
          );
        }
      } else if (!keysSeenInBatch.add(key)) {
        // Two new cases for the same unit + category in one insert: keep the first only.
        c.addError(
          'Another case in this request is for the same unit and service category.'
        );
      }
    }
  }

  private static String keyOf(Case c) {
    return String.valueOf(c.Unit__c) +
      '|' +
      String.valueOf(c.Service_Category__c);
  }
}
