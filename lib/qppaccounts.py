#!/usr/bin/env python3
# QPP Account object module
# Author: D Paul - Flexion

import boto3
import datetime
import string
import base64
import ast
import time
import logging
from functools import lru_cache
from random import SystemRandom
from botocore.exceptions import ClientError

LOG_CRITICAL    = 50
LOG_ERROR       = 40
LOG_WARNING     = 30
LOG_INFO        = 20
LOG_DEBUG       = 10
LOG_NOTSET      = 0


@lru_cache(maxsize=None)
def _getAWSClient(client,**args):
    return boto3.Session(**args).client(client)

class QPPAccount():
    """
    QPPAccount class encapsulated in the QPPAccounts collection, used to make AWS Boto3 calls to an account
        This class with also handle assuming roles if needed to work in accounts
    """
    def __init__(self,accountnum='', alias=''):
        self._accountnum = accountnum
        self._alias = alias
        self._creds = None
        self._role = ''
        self._profile = ''
        self._logger = ''

    @property
    def alias(self):
        return self._alias

    @property
    def account_number(self):
        return self._accountnum

    @property
    def profile(self):
        return self._profile

    @profile.setter
    def profile(self, profile):
        self._profile = profile

    @property
    def requested_role(self):
        return self._role

    @requested_role.setter
    def requested_role(self,role):
        self._role = role
        self.get_temp_credentials(role)
    
    @property
    def logger(self):
        return self._logger

    @logger.setter
    def logger(self,logger):
        self._logger = logger

    def log(self, loglevel, msg, *args, **kwargs):
        if self._logger:
            self._logger.log(loglevel,msg,*args,**kwargs)

    def get_temp_credentials(self, role, account=''):
        if self._creds and role == self._role:
            return self._creds
        if account:
            self._accountnum = account
        self._role = role
        roleArn = f"arn:aws:iam::{self._accountnum}:role/{role}"
        roleSession = f"qpp-assume-role-{''.join(SystemRandom().choices(string.ascii_letters+string.digits,k=12) )}"
        sts = boto3.client('sts')
        self._creds = sts.assume_role(RoleArn=roleArn,RoleSessionName=roleSession,DurationSeconds=60*30)['Credentials']
        return self._creds

    @staticmethod
    def _get_sleep_duration(retry, minSleepMs, maxSleepMs):
        """ https://aws.amazon.com/blogs/messaging-and-targeting/how-to-handle-a-throttling-maximum-sending-rate-exceeded-error/ """
        currentTry = max(0,retry)
        currentSleepMs = minSleepMs * pow(2,currentTry)
        return min(currentSleepMs, maxSleepMs)/1000 #make milliseconds

    def api_call(self,client_type, api_call, *args, **kwargs):
        # use default profile by default, or environment variables
        credkwargs = {}
        if self._creds:
            credkwargs = {
                'aws_access_key_id':self._creds['AccessKeyId'],
                'aws_secret_access_key':self._creds['SecretAccessKey'],
                'aws_session_token':self._creds['SessionToken']
                }
        elif self._profile: 
            credkwargs = { 'profile_name' : self._profile}

        cli = _getAWSClient(client_type, **credkwargs)
        currentTry = 0
        maxTries = 10
        while maxTries > 0:
            maxTries -= 1
            try:
                currentTry += 1
                return getattr(cli,api_call)(*args,**kwargs)
            except ClientError as e:
                if e.response['Error']['Code'] == 'Throttling':
                    self.log(LOG_WARNING, f"Retrying ({currentTry}) {e.operation_name} due to API throttling...")
                    backoff = QPPAccount._get_sleep_duration(currentTry,10,5000)
                    time.sleep(backoff)
                else:
                    raise
        raise Exception(f"{client_type}.{api_call} max retry failure.")

class QPPAccounts:
    """
    QPPAccounts collection class used to encapsulate QPPAccount objects for all the FC managed accounts
    """
    _QPPAwsAccounts = [ 
        {'alias':'aws-hhs-cms-mip','accountNum':'968524040713'},
        {'alias':'aws-hhs-cms-ccsq-qpp-semanticbits','accountNum':'375727523534'},
        {'alias':'aws-hhs-cms-ccsq-qpp-navadevops','accountNum':'003384571330'},
        {'alias':'aws-hhs-cms-amg-qpp-costscoring','accountNum':'112637689005'},
        {'alias':'aws-hhs-cms-ccsq-qpp-qppg','accountNum':'941681414890'},
        {'alias':'aws-hhs-cms-amg-qpp-cm','accountNum':'427702624714'},
        {'alias':'aws-hhs-cms-amg-qpp-selfn','accountNum':'513715589246'},
        {'alias':'aws-hhs-cms-amg-qpp-secops','accountNum':'863249929524'}
        ]
    def __init__(self):
        self.iterobj = iter(self._QPPAwsAccounts)
        
    def __iter__(self):
        return self

    def __next__(self):
        n = next(self.iterobj)
        return QPPAccount(n['accountNum'],n['alias'])  

    @staticmethod
    def get_account_by_alias(alias):
        try:
            found = next(x for x in QPPAccounts._QPPAwsAccounts if x['alias'] == alias)
            return QPPAccount(found['accountNum'],found['alias'])
        except StopIteration:
            raise Exception(f"No account found for alias '{alias}''")

    @staticmethod
    def get_account_by_accountnum(accountnum):
        try:
            found = next(x for x in QPPAccounts._QPPAwsAccounts if x['accountNum'] == accountnum)
            return QPPAccount(found['accountNum'],found['alias'])
        except StopIteration:
            raise Exception(f"No account found for account '{accountnum}''")


# Poor mans test and self exampling code. This file is intended to be run as a module
if __name__ == '__main__':

    run_scenarios = [1,2,3,4,5,6]
    user_info = True

    for scenario in run_scenarios:
        print(f"*** Scenario {scenario} ***")
        if scenario == 1:
            a = QPPAccounts.get_account_by_alias('aws-hhs-cms-ccsq-qpp-qppg')
            a.profile = 'fc-long-term'
            rspUsers = a.api_call('iam','list_users')
            for r in rspUsers['Users']:
                print(r['UserName'])
        elif scenario == 2:
            for a in QPPAccounts():
                print(a.alias,a.account_number)
                a.requested_role = "QPPMGMTRole"
                # this call isn't really needed since requested_role acquires the credentials
                # it is here just to test the persistent creds within this method
                print(a.get_temp_credentials('QPPMGMTRole'))
                rspUsers = a.api_call('iam','list_users')
                for r in rspUsers['Users']:
                    print(r['UserName'])
                    # get more details on the user
                    if user_info:
                        rspUser = a.api_call('iam','get_user',UserName=r['UserName'])
                        print(rspUser['User'])
                print()
        elif scenario == 3:
            # just plain old default account stuff
            a = QPPAccount()
            rspUsers = a.api_call('iam','list_users')
            for r in rspUsers['Users']:
                print(r['UserName'])
        elif scenario == 4:
            a = QPPAccount()
            creds = a.get_temp_credentials('QPPMGMTRole','941681414890')
            print(creds)
            rspUsers = a.api_call('iam','list_users')
            for r in rspUsers['Users']:
                print(r['UserName'])
        elif scenario == 5:
            a = QPPAccounts.get_account_by_alias('aws-hhs-cms-ccsq-qpp-qppg')
            print(a.alias,a.account_number)
        elif scenario == 6:
            a = QPPAccounts().get_account_by_accountnum('941681414890')
            print(a.alias,a.account_number)    
        else:
            pass
    print(_getAWSClient.cache_info())
    