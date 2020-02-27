#!/usr/bin/env python3

import ldap 
import boto3
import logging
import os

class EUALookup:
    """ 
    Class to lookup an EUA using CMS LDAP
    """
    def __init__(self):
        self._ldap = None
        self._logger = None
        self._parms = {}
        self._getLDAPParams()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.__del__()

    def __del__(self):
        if self._ldap:
            self._ldap.unbind()
            self._ldap = None

    def _getLDAPParams(self):
        """ AWS SSM Parameter Store variables """
        ssm_base_path = '/ldap/prod/'
        ssm = boto3.Session().client('ssm')
        ssmparams = ssm.get_parameters_by_path(Path=ssm_base_path,WithDecryption=True)
        self._parms = {}
        for item in ssmparams['Parameters']:
            self._parms[item['Name'].split('/')[3]] = item['Value']
    
    def _getldap(self):
        """ LDAP lazy loader """
        if not self._ldap:
            # https://confluence.cms.gov/display/GDITAQ/EUA+LDAP
            # openssl s_client -showcerts -connect {server} </dev/null 2>/dev/null >ldap_cmssvc_local_chain.crt
            # doesn't really make a difference as this is a private/untrusted cert so you must use ALLOW vs DEMAND to make this work
            # don't know why but for now it is an HTTPS untrusted connection. Come back later
            # leaving code in place for documentation and later testing
            cert = os.getcwd()+"/ldap_cmssvc_local_chain.crt"
            self.log(logging.INFO,f"CA Certificate location: {cert}")
            self.log(logging.INFO,f"Initializing LDAP connecter: {self._parms['server']}")
            username = f"uid={self._parms['username']},ou=system accounts,dc=cms,dc=hhs,dc=gov"
            password = self._parms['password']
            self._ldap = ldap.initialize(self._parms['server'])
            ldap.OPT_X_TLS_CERTFILE = cert
            ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT,ldap.OPT_X_TLS_ALLOW)
            ldap.set_option(ldap.OPT_PROTOCOL_VERSION,ldap.VERSION3)
            # ldap.set_option(ldap.OPT_DEBUG_LEVEL,255)
            self._ldap.simple_bind_s(username, password)
        return self._ldap
 
    @property
    def _server(self):
        self._parms['server']
    
    @property
    def _svcAccountName(self):
        self._parms['username']
    
    @property 
    def _svcAccountPwd(self):
        self._parms['password']

    @property
    def logger(self):
        return self._logger

    @logger.setter
    def logger(self,logger):
        self._logger = logger

    def log(self, loglevel, msg, *args, **kwargs):
        if self._logger:
            self._logger.log(loglevel,msg,*args,**kwargs)
        else:
            print(msg,*args,**kwargs)

    def lookupEUA(self,eua):
        basedn = "dc=cms,dc=hhs,dc=gov"
        attr = ['cn','mail','telephoneNumber']
        # make default blank user dictionay using desired attributes
        # we'll always ensure a complete object
        user = {}
        for k in attr:
            user[k] = ''
            # skip service accounts and only look up valid EUA
        if len(eua) > 4:
            return user
        l = self._getldap()
        self.log(logging.INFO, f"LDAP lookup for EUA: '{eua}'")
        rc = l.search_s(basedn,ldap.SCOPE_SUBTREE, f"uid={eua}", attr)
        if rc:
            dict = rc[0][1]
            for k in dict.keys():
                user[k] = str(dict[k][0],'utf-8')
        else:
            self.log(logging.WARNING,f"User: {eua} not found in AD")
        return user

if __name__ == '__main__':
    import json
    with EUALookup() as f:
        for eua in ['test_service','PW9E','SYPL','SV5F','M0EX','MC4Q']:
            user = f.lookupEUA(eua)
            print(json.dumps(user,indent=4))
