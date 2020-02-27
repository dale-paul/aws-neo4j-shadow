import re
from neo4jhelpers import Neo4jHelper

USERLABEL = "IAM:USER"
GROUPLABEL = "IAM:GROUP"
ROLELABEL = "IAM:ROLE"
POLICYLABEL = "IAM:POLICY"
ILPOLICYLABEL = "IAM:INLINE_POLICY"
SERVICELABEL ="IAM:SERVICE"
HASMEMBERLABEL = "HAS_MEMBER"
HASPOLICYLABEL = "HAS_POLICY"
HASILPOLICYLABEL = "HAS_INLINE_POLICY"
SERVICEACCESSLABEL = "ACCESSED_BY"

def parse_epic_string(str):
    m = re.match(r'[^0-9-]*(?P<days>-?\d+)',str)
    return int(m.group(1)) if m else 0 if str == "today" else None

################################################
def dump_policies(neo4j,acct):
    nodes = [ 
        {
            'label':POLICYLABEL,
            'properties' : {
                'account'   : acct['Account'],
                'name'      : obj['Name'],
                'arn'       : obj['Arn'],
                'isAWS'     : obj['isAWS']
            }
        }
        for obj in acct['Policies'] 
    ]
    neo4j.write_nodes(nodes)

def dump_roles(neo4j,acct):
    nodes = [
        {
            'label':ROLELABEL,
            'properties' : {
                'account'   : acct['Account'],
                'id'        : obj['Id'],
                'name'      : obj['Name'],
                'arn'       : obj['Arn']
            }
        }
        for obj in acct['Roles']
    ]
    neo4j.write_nodes(nodes)

def dump_groups(neo4j,acct):
    nodes = [
        {
            'label':GROUPLABEL,
            'properties' : {
                'account'   : acct['Account'],
                'id'        : obj['Id'],
                'name'      : obj['Name'],
                'arn'       : obj['Arn']
            }
        }
        for obj in acct['Groups']
    ]
    neo4j.write_nodes(nodes)

def dump_users(neo4j, acct):
    nodes = [ 
        {
            'label':USERLABEL,
            'properties': {
                'account'       : acct['Account'],
                'id'            : obj['Id'],
                'name'          : obj['Name'],
                'fullname'      : obj['Fullname'],
                'email'         : obj['Email'],
                'phone'         : obj['Phone'],
                'arn'           : obj['Arn'],
                'mfa'           : obj['CredentialInfo']['mfa_active'], 
                'console_access'        : obj['CredentialInfo']['password_enabled'],
                'api_access'   : obj['CredentialInfo']['access_key_1_active'],
                'account_age_days'
                                : parse_epic_string(obj['CredentialInfo']['user_creation_time']),
                'last_login_days' 
                                : parse_epic_string(obj['CredentialInfo']['password_last_used']),
                'last_password_change_days' 
                                : parse_epic_string(obj['CredentialInfo']['password_last_changed']),
                'accesskey_last_rotated_days' 
                                : parse_epic_string(obj['CredentialInfo']['access_key_1_last_rotated']),
                'accesskey_last_used_days' 
                                : parse_epic_string(obj['CredentialInfo']['access_key_1_last_used_date']),
                'password_rotation_due_days'
                                : parse_epic_string(obj['CredentialInfo']['password_next_rotation']),
            }
        }
        for obj in acct['Users'] 
    ]
    neo4j.write_nodes(nodes)

def dump_role_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': ROLELABEL, 'properties': {'name':r['Name'],'account':acct['Account']} },
            { 'label': HASPOLICYLABEL, 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for r in acct['Roles'] for p in r['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_user_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': USERLABEL, 'properties': {'name':u['Name'],'account':acct['Account']} },
            { 'label': HASPOLICYLABEL, 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for u in acct['Users'] for p in u['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_group_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name':g['Name'],'account':acct['Account']} },
            { 'label': HASPOLICYLABEL, 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for g in acct['Groups'] for p in g['Policies'] 
    ]
    neo4j.write_relations(tuples)
    
def dump_group_users(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name': g['Name'],'account':acct['Account']} },
            { 'label': HASMEMBERLABEL, 'properties': {} }, 
            { 'label': USERLABEL, 'properties': {'name':u,'account':acct['Account']} } 
        ) 
        for g in acct['Groups'] for u in g['Users'] 
    ]
    neo4j.write_relations(tuples)

def dump_group_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name':g['Group'],'account':acct['Account']} },
            { 'label': HASILPOLICYLABEL, 'properties': {} }, 
            { 'label': ILPOLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for g in acct['InlinePolicies']['Groups'] for p in g['Policies'] 
    ]
    # first create the inline policy node
    neo4j.write_nodes([n[2] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_role_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': ROLELABEL, 'properties': {'name':r['Role'],'account':acct['Account']} },
            { 'label': HASILPOLICYLABEL, 'properties': {} }, 
            { 'label': ILPOLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for r in acct['InlinePolicies']['Roles'] for p in r['Policies'] 
    ]
    # first create the inline policy node
    neo4j.write_nodes([n[2] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_user_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': USERLABEL, 'properties': {'name':u['User'],'account':acct['Account']} },
            { 'label': HASILPOLICYLABEL, 'properties': {} }, 
            { 'label': ILPOLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for u in acct['InlinePolicies']['Users'] for p in u['Policies'] 
    ]
     # first create the inline policy node
    neo4j.write_nodes([n[2] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_group_access(neo4j,acct):
    tuples = [ 
        (
            { 'label': SERVICELABEL, 'properties': {'name':u['ServiceNamespace'],'account':acct['Account']} },
            { 'label': SERVICEACCESSLABEL, 'properties': {'last_access_days':parse_epic_string(u['LastAuthenticated'])} }, 
            { 'label': GROUPLABEL, 'properties': {'name': g['Name'],'account':acct['Account']} } 
        ) 
        for g in acct['Groups'] for u in g['LastServiceAccess'] 
    ]
     # first create the service node
    neo4j.write_nodes([n[0] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_role_access(neo4j,acct):
    tuples = [ 
        (
            { 'label': SERVICELABEL, 'properties': {'name':u['ServiceNamespace'],'account':acct['Account']} },
            { 'label': SERVICEACCESSLABEL, 'properties': {'last_access_days':parse_epic_string(u['LastAuthenticated'])} }, 
            { 'label': ROLELABEL, 'properties': {'name': g['Name'],'account':acct['Account']} } 
        ) 
        for g in acct['Roles'] for u in g['LastServiceAccess'] 
    ]
     # first create the service node
    neo4j.write_nodes([n[0] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_user_access(neo4j,acct):
    tuples = [ 
        (
            { 'label': SERVICELABEL, 'properties': {'name':u['ServiceNamespace'],'account':acct['Account']} },
            { 'label': SERVICEACCESSLABEL, 'properties': {'last_access_days':parse_epic_string(u['LastAuthenticated'])} }, 
            { 'label': USERLABEL, 'properties': {'name': g['Name'],'account':acct['Account']} } 
        ) 
        for g in acct['Users'] for u in g['LastServiceAccess'] 
    ]
     # first create the service node
    neo4j.write_nodes([n[0] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_policy_access(neo4j,acct):
    tuples = [ 
        (
            { 'label': SERVICELABEL, 'properties': {'name':u['ServiceNamespace'],'account':acct['Account']} },
            { 'label': SERVICEACCESSLABEL, 'properties': {'last_access_days':parse_epic_string(u['LastAuthenticated'])} }, 
            { 'label': POLICYLABEL, 'properties': {'name': g['Name'],'account':acct['Account']} } 
        ) 
        for g in acct['Policies'] for u in g['LastServiceAccess'] 
    ]
     # first create the service node
    neo4j.write_nodes([n[0] for n in tuples])
    # then add the relationship
    neo4j.write_relations(tuples)

def dump_service_access(neo4j,acct):
    dump_group_access(neo4j,acct)
    dump_role_access(neo4j,acct)
    dump_user_access(neo4j,acct)
    dump_policy_access(neo4j,acct)

def import_to_neo4j(data):
    if 'Accounts' not in data.keys():
        raise KeyError("Incorrect import data format")
    with Neo4jHelper() as neo4j:
        neo4j.clear_database()
        for acct in data['Accounts']:
            dump_policies(neo4j,acct)
            dump_roles(neo4j,acct)
            dump_groups(neo4j,acct)
            dump_users(neo4j,acct)
            dump_user_policies(neo4j,acct)
            dump_role_policies(neo4j,acct)
            dump_group_policies(neo4j,acct)
            dump_group_users(neo4j,acct)
            dump_group_inline_policies(neo4j,acct)
            dump_role_inline_policies(neo4j,acct)
            dump_user_inline_policies(neo4j,acct)
            dump_service_access(neo4j,acct)

#===================================
if __name__ == '__main__':
    import json
    import os
    os.environ['NEO4J_URI'] = 'bolt://localhost:7687'
    with open('test-scripts/QPPFC-1685.json') as f:
        data = json.load(f)

    import_to_neo4j(data)


