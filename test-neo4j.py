import json
from neo4jhelpers import Neo4jHelper

USERLABEL = "IAM:USER"
GROUPLABEL = "IAM:GROUP"
ROLELABEL = "IAM:ROLE"
POLICYLABEL = "IAM:POLICY"


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
                'account'     : acct['Account'],
                'id'          : obj['Id'],
                'name'        : obj['Name'],
                'arn'         : obj['Arn'],
                'mfa'         : obj['CredentialInfo']['mfa_active'], 
                'active'      : obj['CredentialInfo']['password_enabled'],
                'access_keys' : obj['CredentialInfo']['access_key_1_active'],
            }
        }
        for obj in acct['Users'] 
    ]
    neo4j.write_nodes(nodes)

def dump_user_policies(neo4j,acct):
    tuples = [ 
        (
            { 'label': USERLABEL, 'properties': {'name':u['Name']} },
            { 'label': 'HAS_POLICY', 'properties': {} }, 
            { 'label': POLICYLABEL, 'properties': {'name': p} } 
        ) 
        for u in acct['Users'] for p in u['Policies'] 
    ]
    neo4j.write_relations(tuples)


def dump_group_users(neo4j,acct):
    tuples = [ 
        (
            { 'label': GROUPLABEL, 'properties': {'name': g['Name']} },
            { 'label': 'HAS_MEMBER', 'properties': {} }, 
            { 'label': USERLABEL, 'properties': {'name':u} } 
        ) 
        for g in acct['Groups'] for u in g['Users'] 
    ]
    neo4j.write_relations(tuples)

#===================================
with open('test-scripts/QPPFC-1685.json') as f:
    data = json.load(f)

with Neo4jHelper() as neo4j:
    for acct in data['Accounts']:
        dump_policies(neo4j,acct)
        dump_roles(neo4j,acct)
        dump_groups(neo4j,acct)
        dump_users(neo4j,acct)
        dump_group_users(neo4j,acct)
        dump_user_policies(neo4j,acct)



