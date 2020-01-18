#!/bin/bash

docker ps -a | grep "neo4j" | grep "Up" | cut -d ' ' -f 1 | xargs docker stop