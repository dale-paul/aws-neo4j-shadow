#!/usr/bin/env python3
# QPP Account object module
# Author: D Paul - Flexion

import sys,os
# sys.path.append(os.getcwd())
sys.path.append(os.path.join(os.getcwd(),'lib'))
# sys.path.append(os.path.join(os.getcwd(),'neo4jhelpers'))

import boto3
import argparse
import logging
import time
import datetime
import pytz
import io
import csv
import concurrent.futures
import jmespath
from dateutil import parser as _parser
from botocore.exceptions import ClientError
from qppaccounts import QPPAccounts, QPPAccount

def epoch_str(d1):
    """ return a "days ago" type string for any date relative to today """
    diff = (datetime.datetime.now(pytz.timezone('GMT'))-d1).days
    return "today" if diff == 0 else (f"{diff} days ago" if diff > 0 else f"in {-diff} days")


def try_parse_datestr(datestr):
    try:
        return _parser.parse(datestr)
    except ValueError:
        return datestr


def get_user_credentials_report(acctObj:QPPAccount):
    """ generate and retreive the AWS Credentials Report """
    logging.info(f"*** getting user credentials report for '{acctObj.alias}' ***")

    credentials = {}
    # see if a credential report exists 
    while ( acctObj.api_call('iam','generate_credential_report')['State'] != 'COMPLETE'):
        pass
    aws_report = acctObj.api_call('iam','get_credential_report')
    content = aws_report['Content'].decode('utf-8')
    reader = csv.DictReader(io.StringIO(content))
    for row in reader:
        datarow = dict(row) #result is OrderedDict so convert to dict
        credentials[datarow['user']] = { 
                    k : 'Never' if v in ('N/A',None) 
                        else (
                            v if not isinstance(try_parse_datestr(v),(datetime.datetime)) 
                                else 
                                    epoch_str(_parser.isoparse(v))
                        ) 
                        for k,v in datarow.items() if k not in ('user','arn') #keys to skip
                }
    return credentials

# leaving out for now as there is no immediate use for this data and it is slow to run which would affect lambda execution
def get_service_access_info(acctObj:QPPAccount, arn, retry = 0):
    """ Generate the IAM Access Report for an User, Group, Role, Policy """
    rsp = acctObj.api_call('iam','generate_service_last_accessed_details', Arn=arn)
    jobid = rsp['JobId']
    while True:
        rsp = acctObj.api_call('iam','get_service_last_accessed_details',JobId=jobid,MaxItems=999)
        if rsp['JobStatus'] in ('COMPLETED','FAILED'):
            break

    if ( rsp['JobStatus'] == 'COMPLETED'):
        return [ {'ServiceNamespace':k['ServiceNamespace'],
                    'LastAuthenticated': epoch_str(k['LastAuthenticated']),
                    'TotalAuthenticatedEntities': k['TotalAuthenticatedEntities']} 
                    for k in rsp['ServicesLastAccessed'] if k['TotalAuthenticatedEntities'] > 0]

    logging.error(f"failed to retrieve service access info code: {rsp['Error']['Code']}, msg: {rsp['Error']['Message']}")
    return []


def dump_role_policies(acctObj:QPPAccount, rolename):
    """ retrieve policies attach to a given role """
    policy_names = []
    logging.info(f"dumping role '{rolename}' policies")
    rsp = acctObj.api_call('iam','list_role_policies',RoleName=rolename,MaxItems=999)
    for policy in rsp['PolicyNames']:
        logging.info(f"\tinline: {policy}")
        policy_names.append(policy)
    return policy_names


def dump_inline_roles(acctObj:QPPAccount):
    """ retrieve the roles for inlines policies """
    inlines = []
    logging.info(f"dumping roles for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_roles',MaxItems=999)
    for f in rsp['Roles']:
        p = dump_role_policies(acctObj,f['RoleName'])
        inlines.append({'Role': f['RoleName'],'Policies':p})
    return inlines


def dump_user_policies(acctObj:QPPAccount, username):
    """ retrieve policies attached directory to an user """
    logging.info(f"dumping user '{username}' policies")
    rsp = acctObj.api_call('iam','list_user_policies',UserName=username,MaxItems=999)
    policy_names = [policy for policy in rsp['PolicyNames']]
    return policy_names


def dump_inline_users(acctObj:QPPAccount):
    """ retrieve users attached to inline policies """
    inlines = []
    logging.info(f"dumping users for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_users',MaxItems=999)
    for f in rsp['Users']:
        p = dump_user_policies(acctObj,f['UserName'])
        inlines.append({'User': f['UserName'],'Policies':p})
    return inlines


def dump_group_policies(acctObj:QPPAccount, groupname):
    """ retrieve policies attached to a group """
    logging.info(f"dumping group '{groupname}' policies")
    rsp = acctObj.api_call('iam','list_group_policies',GroupName=groupname,MaxItems=999)
    policy_names = [policy for policy in rsp['PolicyNames']]
    return policy_names


def dump_inline_groups(acctObj:QPPAccount):
    """ retrieve groups attached to inline policies """
    inlines = []
    logging.info(f"dumping groups for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_groups',MaxItems=999)
    for f in rsp['Groups']:
        p = dump_group_policies(acctObj,f['GroupName'])
        inlines.append({'Group': f['GroupName'],'Policies':p})
    return inlines


def dump_policies(acctObj:QPPAccount):
    """ retrieve attached managed policies """
    logging.info(f"*** dumping policies for '{acctObj.alias}' ***")
    rsp = acctObj.api_call('iam','list_policies',OnlyAttached=True,Scope='All',MaxItems=999)
    policies = []
    for p in rsp['Policies']:
        policy = {}
        arn = p['Arn']
        policy['Arn'] = arn
        splt = arn.split(':')
        policy['isAWS'] = splt[4] == 'aws'
        policy['Name'] = splt[-1].split('/')[-1]
        x = acctObj.api_call('iam','list_entities_for_policy',PolicyArn=p['Arn'])
        policy['Groups'] = [ i['GroupName'] for i in x['PolicyGroups'] ]
        policy['Users'] = [ i['UserName'] for i in x['PolicyUsers'] ]
        policy['Roles'] = [ i['RoleName'] for i in x['PolicyRoles'] ]
        policy['LastServiceAccess'] = get_service_access_info(acctObj,arn)
        logging.info(f"\t{policy['Arn']}")
        policies.append(policy)
    return policies


def dump_inline_policies(acctObj:QPPAccount):
    """ retrieve unmanage/inline policies """
    policies = {}
    policies['Groups'] = dump_inline_groups(acctObj)
    policies['Roles'] = dump_inline_roles(acctObj)
    policies['Users'] = dump_inline_users(acctObj)
    return policies


def dump_instance_profiles(acctObj:QPPAccount):
    """ retrieve instance profiles """
    logging.info(f"*** dumping instance profiles for '{acctObj.alias}' ***")
    profiles = []
    rsp = acctObj.api_call('iam','list_instance_profiles',MaxItems=999)
    for p in rsp['InstanceProfiles']:
        logging.info(f"\tdumping instance profile '{p['InstanceProfileName']}'")
        profile = {}
        profile['Name'] = p['InstanceProfileName']
        profile['Id'] = p['InstanceProfileId']
        profile['Arn'] = p['Arn']
        profile['Roles'] = [r['RoleName'] for r in p['Roles']]
        profiles.append(profile)
    return profiles


def dump_groups(acctObj:QPPAccount):
    """ retrieve account groups """
    groups = []
    logging.info(f"dumping groups for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_groups',MaxItems=999)
    for f in rsp['Groups']:
        logging.info(f"\tgroup: {f['GroupName']}")
        group = {}
        group['Name'] = f['GroupName']
        group['Arn'] = f['Arn']
        group['Id'] = f['GroupId']
        group['LastServiceAccess'] = get_service_access_info(acctObj,f['Arn'])
        groups.append(group)
    return groups


def dump_roles(acctObj:QPPAccount):
    """ retrieve account roles """
    roles = []
    logging.info(f"dumping roles for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_roles',MaxItems=999)
    for f in rsp['Roles']:
        logging.info(f"\trole: {f['RoleName']}")
        role = {}
        role['Name'] = f['RoleName']
        role['Description'] = f.get('Description','')
        role['Arn'] = f['Arn']
        role['Id'] = f['RoleId']
        role['Trust'] = f['AssumeRolePolicyDocument']['Statement'][0]['Principal']
        role['LastServiceAccess'] = get_service_access_info(acctObj,f['Arn'])        
        roles.append(role)
    return roles


def dump_users(acctObj:QPPAccount):
    """ retrieve account users and credential information """
    users = []
    credentials = get_user_credentials_report(acctObj)
    logging.info(f"\tdumping users for '{acctObj.alias}'")
    rsp = acctObj.api_call('iam','list_users',MaxItems=999)
    for f in rsp['Users']:
        logging.info(f"\tuser: {f['UserName']}")
        user = {}
        user['Name'] = f['UserName']
        user['Arn'] = f['Arn']
        user['Id'] = f['UserId']
        user['CredentialInfo'] = credentials.get(f['UserName'],None)
        user['LastServiceAccess'] = get_service_access_info(acctObj,f['Arn'])
        rsp2 = acctObj.api_call('iam','list_groups_for_user',UserName=user['Name'])
        user['Groups'] = [g['GroupName'] for g in rsp2['Groups']]
        users.append(user)
    return users
    

def do_rollups(report):
    """ Rollup data to allow easy cross reference for data in policies list """
    logging.info(f"Rolling up data for '{report['Alias']}'")
    # Rollup items into groups
    for g in report['Groups']:
        name = g['Name']
        g['Policies'] = jmespath.search(f"Policies[?contains(@.Groups,`{name}`)==`true`].Name[]",report)
        g['InlinePolicies'] = jmespath.search(f"InlinePolicies.Groups[?@.Group==`{name}`].Policies[][]",report)
        g['Users']= jmespath.search(f"Users[?contains(@.Groups,`{name}`)==`true`].Name[]",report)
    for u in report['Users']:
        name = u['Name']
        u['Policies'] = jmespath.search(f"Policies[?contains(@.Users,`{name}`)==`true`].Name[]",report)
        u['InlinePolicies'] = jmespath.search(f"InlinePolicies.Users[?@.User==`{name}`].Policies[][]",report)
    for r in report['Roles']:
        name = r['Name']
        r['Policies'] = jmespath.search(f"Policies[?contains(@.Roles,`{name}`)==`true`].Name[]",report)
        r['InlinePolicies'] = jmespath.search(f"InlinePolicies.Roles[?@.Role==`{name}`].Policies[][]",report)


def build_account_report(acctObj:QPPAccount):
    """ build the report for an account """

    account = {'Account':acctObj.account_number,'Alias':acctObj.alias}
    threadlist = [
        ('Policies',dump_policies),
        ('Users',dump_users),
        ('Roles',dump_roles),
        ('Groups',dump_groups),
        ('InlinePolicies',dump_inline_policies),
        ('InstanceProfiles',dump_instance_profiles)
    ]
    threads = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        for arg in threadlist:
           threads.append( (arg[0], executor.submit(arg[1],acctObj)))

    for k,t in threads:
        account[k] = t.result()
    return account


def generate_iam_report(args:dict):
    logging.basicConfig(format='%(levelname)s: %(message)s', level=args['log_level'])

    """ The main process """
    qppaccounts = []
    if args['account_alias']:
        for a in args['account_alias']:
            qppaccounts.append(QPPAccounts().get_account_by_alias(a))
    elif args['account_number']:
        for a in args['account_number']:
            qppaccounts.append(QPPAccounts().get_account_by_accountnum(a))
    else:
        # Just get the accounts but don't cause any loading of credentials for now
        for a in QPPAccounts():
            qppaccounts.append(a)

    accounts = {'Accounts':[]}
    # who ran the report (also fail fast if user isn't credentialed)
    rsp = QPPAccount().api_call('sts','get_caller_identity')
    accounts['Metadata'] = {'Creator':rsp['Arn'],'Time': datetime.datetime.now(pytz.timezone('US/Eastern')).isoformat()}

    threads = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args['max_threads']) as executor:
        for acct in qppaccounts:
            if ( args['role_name'] ):
                acct.requested_role = args['role_name'] #load the credentials
            elif args['aws_profile']:
                acct.profile = args['aws_profile']
            acct.logger = logging
            threads.append( executor.submit(build_account_report,acct) )

    # join up our threads
    for t in threads:
        accounts['Accounts'].append(t.result())

    # do our rollups after all the thread work to avoid race conditions
    for a in accounts['Accounts']:
        do_rollups(a)
    
    return accounts
