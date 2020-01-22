#!/bin/bash

docker run \
     --detach \
     --publish=7474:7474 \
     --publish=7687:7687 \
     --volume=$HOME/neo4j/data:/data \
     --volume=$HOME/neo4j/logs:/logs \
     --volume=$HOME/neo4j/conf:/conf \
     --volume=$HOME/neo4j/plugins:/plugins \
     --volume=$HOME/neo4j/import:/import \
     neo4j

