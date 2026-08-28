#!/bin/bash
#
docker exec shared-postgres sh -c 'echo "PWD=[$DATABASE_PASSWORD] USER=[$DATABASE_USER]"'
