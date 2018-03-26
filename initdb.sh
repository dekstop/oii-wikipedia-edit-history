#!/bin/bash

DB=

if [[ $# -ne 1 ]]
then
  echo "Usage : $0 <db>"
  exit 1
else
  DB=$1
fi

PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"
${PSQL} -c "SELECT 1" || exit 1

srcdir=~/oiidg/src
geoipdir=~/oiidg/geoip

datadir=~/oiidg/data/
etldir=${datadir}/init

mkdir -p $etldir 2>&1

neshapefile=~/oiidg/natural-earth/ne_10m_admin_0_countries.shp
nesqlfile=${etldir}/ne_10m_admin_0_countries.sql

##
## DB schema
##

time $PSQL -c "DROP TABLE IF EXISTS countries CASCADE" || exit 1
shp2pgsql -c -I ${neshapefile} countries > ${nesqlfile} || exit 1
time $PSQL < ${nesqlfile} || exit 1

# time $PSQL < ${srcdir}/globalschema.sql || exit 1

