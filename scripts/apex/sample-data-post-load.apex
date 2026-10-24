// Finishes the sample data after `sf data import tree --plan data/sample-plan.json`.
// Run after scripts/apex/create-demo-users.apex:
//   sf apex run --file scripts/apex/sample-data-post-load.apex
//
//  1. Sets community managers (escalation notifications go to them):
//     Green Valley Residency -> Neha Kapoor, UrbanCart -> you (the running admin).
//  2. Submits one duplicate request through the "web" so the duplicate guard can be seen linking it
//     to the open case as a child instead of blocking it.

String suffix = UserInfo.getOrganizationId().left(15).toLowerCase();
List<User> neha = [SELECT Id FROM User WHERE Username = :('neha.kapoor.' + suffix + '@servdeck.demo')];

List<Community__c> communities = [SELECT Id, Community_Code__c FROM Community__c WHERE Community_Code__c IN ('GVR', 'UCT')];
for (Community__c c : communities) {
  if (c.Community_Code__c == 'GVR' && !neha.isEmpty()) {
    c.Manager__c = neha[0].Id;
  } else if (c.Community_Code__c == 'UCT') {
    c.Manager__c = UserInfo.getUserId();
  }
}
update communities;
System.debug('Managers set on ' + communities.size() + ' communities' + (neha.isEmpty() ? ' (Neha Kapoor not found: run create-demo-users.apex first)' : ''));

// Duplicate demo: Divya already has an open "Payment Failed" case for CUST-1006.
Case original = [
  SELECT Id, CaseNumber, Community__c, Unit__c, Service_Category__c, ContactId
  FROM Case
  WHERE Subject = 'UPI payment failed twice' AND IsClosed = FALSE
  LIMIT 1
];
if ([SELECT COUNT() FROM Case WHERE ParentId = :original.Id] == 0) {
  Case duplicate = new Case(
    Subject = 'Payment failed again - please help',
    Description = 'Tried to pay again and it failed. Submitted through the web form.',
    Origin = 'Web',
    Status = 'New',
    Priority = 'Medium',
    Community__c = original.Community__c,
    Unit__c = original.Unit__c,
    Service_Category__c = original.Service_Category__c,
    ContactId = original.ContactId
  );
  insert duplicate;
  System.debug('Web duplicate linked to ' + original.CaseNumber + ': ParentId = ' + [SELECT ParentId FROM Case WHERE Id = :duplicate.Id].ParentId);
}
