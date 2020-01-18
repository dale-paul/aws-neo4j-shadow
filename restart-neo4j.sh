#!/bin/bash

docker ps | grep neo4j | cut -d ' ' -f1 | xargs docker restart
