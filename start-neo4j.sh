#!/bin/bash

docker ps -a | grep "neo4j" | grep "Exited" | cut -d ' ' -f 1 | xargs docker start