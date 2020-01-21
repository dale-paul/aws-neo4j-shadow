import json
import re
from neo4jhelpers import Neo4jHelper

USERLABEL = "IAM:USER"
GROUPLABEL = "IAM:GROUP"
ROLELABEL = "IAM:ROLE"
POLICYLABEL = "IAM:POLICY"

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
                'arn'           : obj['Arn'],
                'mfa'           : obj['CredentialInfo']['mfa_active'], 
                'active'        : obj['CredentialInfo']['password_enabled'],
                'access_key'   : obj['CredentialInfo']['access_key_1_active'],
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
            { 'label': 'HAS_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for r in acct['Roles'] for p in r['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_user_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': USERLABEL, 'properties': {'name':u['Name'],'account':acct['Account']} },
            { 'label': 'HAS_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for u in acct['Users'] for p in u['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_group_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name':g['Name'],'account':acct['Account']} },
            { 'label': 'HAS_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for g in acct['Groups'] for p in g['Policies'] 
    ]
    neo4j.write_relations(tuples)
    
def dump_group_users(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name': g['Name'],'account':acct['Account']} },
            { 'label': 'HAS_MEMBER', 'properties': {} }, 
            { 'label': USERLABEL, 'properties': {'name':u,'account':acct['Account']} } 
        ) 
        for g in acct['Groups'] for u in g['Users'] 
    ]
    neo4j.write_relations(tuples)

def dump_group_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name':g['Group'],'account':acct['Account']} },
            { 'label': 'HAS_INLINE_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for g in acct['InlinePolicies']['Groups'] for p in g['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_role_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': ROLELABEL, 'properties': {'name':r['Role'],'account':acct['Account']} },
            { 'label': 'HAS_INLINE_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for r in acct['InlinePolicies']['Roles'] for p in r['Policies'] 
    ]
    neo4j.write_relations(tuples)

def dump_user_inline_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': USERLABEL, 'properties': {'name':u['User'],'account':acct['Account']} },
            { 'label': 'HAS_INLINE_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p,'account':acct['Account']} } 
        ) 
        for u in acct['InlinePolicies']['Users'] for p in u['Policies'] 
    ]
    neo4j.write_relations(tuples)

#===================================
with open('test-scripts/QPPFC-1685.json') as f:
    data = json.load(f)

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



