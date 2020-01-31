#!/bin/bash

docker run \
     --detach \
     --publish=7474:7474 \
     --publish=7687:7687 \
     --env NEO4J_dbms_security_auth__enabled=false \
     neo4j

