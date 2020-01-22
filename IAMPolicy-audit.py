#!/usr/bin/env python3
# QPP Account object module
# Author: D Paul - Flexion


import argparse
import json
import logging
from importers import generate_iam_report
from neo4jhelpers import import_to_neo4j

parser = argparse.ArgumentParser(description="IAM Policy Usage Report")
parser.add_argument("--role-name", help="Role to assume in each account")
parser.add_argument("-o","--output", type=argparse.FileType('w+'), help="JSON formatted file to write results to")
parser.add_argument("--account-alias", nargs='*', help="Restrict output to this account alias")
parser.add_argument("--account-number", nargs='*',help="Restrict output to this account number")
parser.add_argument("--aws-profile", help="AWS Profile to use for credentials")
parser.add_argument("--log-level", choices=['CRITICAL','ERROR','WARNING','INFO','DEBUG'],default='WARNING',help="Set the logging level")
parser.add_argument("--max-threads", default="3", type=int, help="Maximum threads for account execution. Default = 3. More can cause throttling errors")
parser.add_argument("--neo4j", action='store_true', help="put output to neo4j server")


if __name__ == "__main__":
    args = parser.parse_args()
    print("This program will take several minutes to run....")
    logging.basicConfig(format='%(levelname)s: %(message)s', level=args.log_level)
    report = generate_iam_report(vars(args)) # pass our args on as a dictionary

    if args.neo4j:
        logging.info(f"Exporting IAM to NEO4j")
        import_to_neo4j(report)

    outstr = json.dumps(report,indent=4)
    if args.output:
        args.output.write(outstr)
    else:
        print(outstr)

