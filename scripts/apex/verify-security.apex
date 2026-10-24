// Checks the security model against the real demo users and sample data (run as an admin):
//   sf apex run --file scripts/apex/verify-security.apex
//
// Uses UserRecordAccess, which reports what a given user can see, including access granted by
// criteria-based sharing rules (those are evaluated on commit, so Apex tests cannot check them).
// Prints PASS/FAIL lines.

String suffix = UserInfo.getOrganizationId().left(15).toLowerCase();
User agent = [SELECT Id, Name FROM User WHERE Username = :('arjun.mehta.' + suffix + '@servdeck.demo')];
User manager = [SELECT Id, Name FROM User WHERE Username = :('neha.kapoor.' + suffix + '@servdeck.demo')];

Set<Id> agentQueues = new Set<Id>();
for (GroupMember m : [SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :agent.Id AND Group.Type = 'Queue']) {
  agentQueues.add(m.GroupId);
}

Map<Id, Case> cases = new Map<Id, Case>([SELECT Id, CaseNumber, OwnerId, Owner.Name, Community_Code__c FROM Case]);
Set<Id> agentCanRead = new Set<Id>();
Set<Id> managerCanRead = new Set<Id>();
for (UserRecordAccess a : [SELECT RecordId, HasReadAccess FROM UserRecordAccess WHERE UserId = :agent.Id AND RecordId IN :cases.keySet()]) {
  if (a.HasReadAccess) agentCanRead.add(a.RecordId);
}
for (UserRecordAccess a : [SELECT RecordId, HasReadAccess FROM UserRecordAccess WHERE UserId = :manager.Id AND RecordId IN :cases.keySet()]) {
  if (a.HasReadAccess) managerCanRead.add(a.RecordId);
}

Integer failures = 0;
for (Case c : cases.values()) {
  Boolean agentShould = agentQueues.contains(c.OwnerId) || c.OwnerId == agent.Id;
  Boolean managerShould = c.Community_Code__c == 'GVR';
  if (agentCanRead.contains(c.Id) != agentShould) {
    failures++;
    System.debug('FAIL agent access to ' + c.CaseNumber + ' (owner ' + c.Owner.Name + '): expected ' + agentShould);
  }
  if (managerCanRead.contains(c.Id) != managerShould) {
    failures++;
    System.debug('FAIL manager access to ' + c.CaseNumber + ' (' + c.Community_Code__c + '): expected ' + managerShould);
  }
}
System.debug('Agent ' + agent.Name + ' can read ' + agentCanRead.size() + ' of ' + cases.size() + ' cases (Maintenance + Security queues only)');
System.debug('Manager ' + manager.Name + ' can read ' + managerCanRead.size() + ' of ' + cases.size() + ' cases (all Green Valley cases, any queue)');
System.debug(failures == 0 ? 'PASS: security model verified' : 'FAIL: ' + failures + ' unexpected access results');
