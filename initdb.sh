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

##
## Shapefiles
##

function load_shapefile() {
    tablename=$1
    shapefile=$2
    sqlfile=$3

    time $PSQL -c "DROP TABLE IF EXISTS ${tablename} CASCADE" || return 1
    shp2pgsql -c -I ${shapefile} $tablename > ${sqlfile} || return 1
    time $PSQL < ${sqlfile} || return 1
}

load_shapefile countries \
    ~/oiidg/natural-earth/ne_10m_admin_0_countries/ne_10m_admin_0_countries.shp \
    ${etldir}/ne_10m_admin_0_countries.sql || exit 1
$PSQL -c "UPDATE countries SET iso_a2='FR', iso_a3='FRA' WHERE name='France'" || exit 1
$PSQL -c "UPDATE countries SET iso_a2='NO', iso_a3='NOT' WHERE name='Norway'" || exit 1

load_shapefile provinces \
    ~/oiidg/natural-earth/ne_10m_admin_1_states_provinces/ne_10m_admin_1_states_provinces.shp \
    ${etldir}/ne_10m_admin_1_states_provinces.sql || exit 1

load_shapefile hexbins2 \
    ~/oiidg/hexbins/hexbins2.shp \
    ${etldir}/hexbins2.sql || exit 1

load_shapefile hexbins5 \
    ~/oiidg/hexbins/hexbins5.shp \
    ${etldir}/hexbins5.sql || exit 1

##
## DB schema
##
# time $PSQL < ${srcdir}/globalschema.sql || exit 1
time $PSQL < ${srcdir}/functions.sql || exit 1

