#!/bin/bash

docker run --rm --volume=$HOME/neo4j/conf:/conf --user=$(id -u):$(id -g)  neo4j dump-config

