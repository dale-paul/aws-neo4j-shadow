:param Account => "863249929524"
:param File => "QPPFC-1685.json"

:begin
// Load Policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Policies[*]") YIELD value as row
MERGE(p:POLICY {name:row.Name, arn:row.Arn, isAWS: row.isAWS, account:$Account})
;

// Load Roles
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Roles[*]") YIELD value as row
MERGE(r:ROLE {id:row.Id, name:row.Name, arn:row.Arn, account:$Account})
;

// Load Role policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Roles[*]") YIELD value as row
UNWIND row.Policies as policies
MATCH(p:POLICY {name:policies})
MATCH(r:ROLE {name:row.Name})
MERGE((r)-[:HAS_POLICY]->(p))
;

// Inline Role Policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].InlinePolicies") YIELD value as row
UNWIND row.Roles as roles
UNWIND roles.Policies as p 
MATCH (r:ROLE {name:roles.Role})
MERGE (il:Inline_Policy {name:p})
MERGE (r)-[:HAS_INLINE_POLICY]->(il)
;

// Load Users 
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Users[*]") YIELD value as row
MERGE(u:USER 
{
    id:row.Id, 
    name:row.Name, 
    arn:row.Arn, 
    mfa:row.CredentialInfo.mfa_active, 
    active:row.CredentialInfo.password_enabled,
    access_keys: row.CredentialInfo.access_key_1_active,
    account:$Account
})
;

// Load Users policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Users[*]") YIELD value as row
UNWIND CASE WHEN row.Policies=[] THEN [null] ELSE row.Policies END as pol
MATCH(u:USER {name:row.Name})
MATCH(p:POLICY {name:pol})
MERGE((u)-[:HAS_POLICY]->(p))
;

// Inline User Policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].InlinePolicies") YIELD value as row
UNWIND row.Users as users
UNWIND users.Policies as p 
MATCH (u:USER {name:users.User})
MERGE (il:Inline_Policy {name:p})
MERGE (u)-[:HAS_INLINE_POLICY]->(il)
;

// Load Groups
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Groups[*]") YIELD value as row
MERGE(g:GROUP {id:row.Id, name:row.Name, arn:row.Arn, account:$Account})
;

// Load Groups users
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Groups[*]") YIELD value as row
UNWIND row.Users as users
MATCH(g:GROUP {name:row.Name})
MATCH(u:USER {name:users})
MERGE((g)-[:HAS_MEMBER]->(u))
;

// Load Groups policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Groups[*]") YIELD value as row
UNWIND row.Policies as policies 
MATCH(g:GROUP {name:row.Name})
MATCH(p:POLICY {name:policies})
MERGE((g)-[:HAS_POLICY]->(p))
;

// Inline Group Policies
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].InlinePolicies") YIELD value as row
UNWIND row.Groups as groups
UNWIND groups.Policies as p 
MATCH (g:GROUP {name:groups.Group})
MERGE (pl:Inline_Policy {name:p})
MERGE (g)-[:HAS_INLINE_POLICY]->(pl)
;

// Load Policie service accessed
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Policies[*]") YIELD value as row
UNWIND row.LastServiceAccess as lstsvc
MATCH (n:POLICY {name:row.Name})
MERGE(svc:SERVICE {name:lstsvc.ServiceNamespace})
MERGE(svc)-[:ACCESSED_BY {when:lstsvc.LastAuthenticated}]->(n)
;

// Load Users service accessed
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Users[*]") YIELD value as row
UNWIND row.LastServiceAccess as lstsvc
MATCH (n:USER {name:row.Name})
MERGE(svc:SERVICE {name:lstsvc.ServiceNamespace})
MERGE(svc)-[:ACCESSED_BY {when:lstsvc.LastAuthenticated}]->(n)
;

// Load Roles service accessed
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Roles[*]") YIELD value as row
UNWIND row.LastServiceAccess as lstsvc
MATCH (n:ROLE {name:row.Name})
MERGE(svc:SERVICE {name:lstsvc.ServiceNamespace})
MERGE(svc)-[:ACCESSED_BY {when:lstsvc.LastAuthenticated}]->(n)
;

// Load Groups service accessed
CALL apoc.load.json("file:/"+$File,".Accounts[?(@.Account=="+$Account+")].Groups[*]") YIELD value as row
UNWIND row.LastServiceAccess as lstsvc
MATCH (n:GROUP {name:row.Name})
MERGE(svc:SERVICE {name:lstsvc.ServiceNamespace})
MERGE(svc)-[:ACCESSED_BY {when:lstsvc.LastAuthenticated}]->(n)
;

:commit