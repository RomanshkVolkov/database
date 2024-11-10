#!/bin/bash
# obtener un .sql con todo el contenido de una base de datos
mysqldump -h <host> \
    -u <username> \
    -p '<database>' \
    --port=3306 \
    --single-transaction \
    --routines \
    --triggers \
    --databases <database> > ./rds-dump.sql

# puedes montarlo en docker como entry point 