// Creates the ServDeck demo users and their access. Run once per org, as an admin:
//   sf apex run --file scripts/apex/create-demo-users.apex
//
//  - Arjun Mehta (Agent):   ServDeck Agent permission set, member of the Maintenance and Security queues
//  - Neha Kapoor (Manager): ServDeck Manager permission set, member of the Green Valley (GVR) managers group
//  - You (the running admin): ServDeck Admin permission set, member of the UrbanCart (UCT) managers group
//
// Users get fake @example.com emails and no welcome email. To try the app as them, use
// Setup > Users > Login next to the user. Safe to run again: existing users are reused.

String suffix = UserInfo.getOrganizationId().left(15).toLowerCase();
Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

Map<String, Map<String, Object>> demoUsers = new Map<String, Map<String, Object>>{
  'arjun.mehta' => new Map<String, Object>{
    'first' => 'Arjun', 'last' => 'Mehta', 'alias' => 'amehta', 'title' => 'Maintenance Agent',
    'permset' => 'ServDeck_Agent', 'groups' => new List<String>{ 'Maintenance', 'Security' }
  },
  'neha.kapoor' => new Map<String, Object>{
    'first' => 'Neha', 'last' => 'Kapoor', 'alias' => 'nkapoor', 'title' => 'Society Secretary',
    'permset' => 'ServDeck_Manager', 'groups' => new List<String>{ 'Community_GVR' }
  }
};

Database.DMLOptions noWelcomeEmail = new Database.DMLOptions();
noWelcomeEmail.EmailHeader.triggerUserEmail = false;

Map<String, Id> permsetIds = new Map<String, Id>();
for (PermissionSet ps : [SELECT Id, Name FROM PermissionSet WHERE Name LIKE 'ServDeck_%']) {
  permsetIds.put(ps.Name, ps.Id);
}
Map<String, Id> groupIds = new Map<String, Id>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN ('Maintenance', 'Security', 'Billing', 'Support', 'Community_GVR', 'Community_UCT')]) {
  groupIds.put(g.DeveloperName, g.Id);
}

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
List<GroupMember> memberships = new List<GroupMember>();

for (String key : demoUsers.keySet()) {
  Map<String, Object> spec = demoUsers.get(key);
  String username = key + '.' + suffix + '@servdeck.demo';
  List<User> existing = [SELECT Id FROM User WHERE Username = :username];
  User u;
  if (existing.isEmpty()) {
    u = new User(
      FirstName = (String) spec.get('first'),
      LastName = (String) spec.get('last'),
      Alias = (String) spec.get('alias'),
      Title = (String) spec.get('title'),
      Username = username,
      Email = key + '@example.com',
      ProfileId = standardUser.Id,
      TimeZoneSidKey = 'Asia/Kolkata',
      LocaleSidKey = 'en_IN',
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    );
    u.setOptions(noWelcomeEmail);
    insert u;
    System.debug('Created ' + username);
  } else {
    u = existing[0];
    System.debug('Reusing ' + username);
  }
  assignments.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = permsetIds.get((String) spec.get('permset'))));
  for (String groupName : (List<String>) spec.get('groups')) {
    memberships.add(new GroupMember(GroupId = groupIds.get(groupName), UserOrGroupId = u.Id));
  }
}

// The running admin manages UrbanCart.
assignments.add(new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = permsetIds.get('ServDeck_Admin')));
memberships.add(new GroupMember(GroupId = groupIds.get('Community_UCT'), UserOrGroupId = UserInfo.getUserId()));

// allOrNone = false: re-running skips assignments and memberships that already exist.
Integer added = 0;
for (Database.SaveResult r : Database.insert(assignments, false)) {
  added += r.isSuccess() ? 1 : 0;
}
for (Database.SaveResult r : Database.insert(memberships, false)) {
  added += r.isSuccess() ? 1 : 0;
}
System.debug('New permission set assignments and group memberships: ' + added);
