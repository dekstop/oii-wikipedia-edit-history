#!/bin/bash

DB=
wiki=
date=

if [[ $# -ne 3 ]]
then
  echo "Usage : $0 <db> <wiki> <date>"
  exit 1
else
  DB=$1
  wiki=$2
  date=$3
fi

PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"
${PSQL} -c "SELECT 1" || exit 1

PYTHON=~/osm/ipython-env/env/bin/python

srcdir=~/oiidg/src
geoipdir=~/oiidg/geoip

datadir=~/oiidg/data/${wiki}_${date}
etldir=${datadir}/etl
csvdir=${datadir}/csv

mkdir -p $etldir 2>&1
mkdir -p $csvdir 2>&1

neshapefile=~/oiidg/natural-earth/ne_10m_admin_0_countries.shp
nesqlfile=${etldir}/ne_10m_admin_0_countries.sql

##
## DB schema
##

time $PSQL < ${srcdir}/wikitemplate.sql || exit 1
$PSQL -c "DROP SCHEMA IF EXISTS ${wiki} CASCADE" || exit 1
$PSQL -c "ALTER SCHEMA wikitemplate RENAME TO ${wiki}" || exit 1

##
## Revision history metadata
##

WGET="wget --continue --directory-prefix=${datadir}"
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-stub-meta-history.xml.gz || exit 1
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-geo_tags.sql.gz || exit 1

echo "Parsing the history XML... this will take a while."
time $PYTHON ${srcdir}/revisions.py --errors \
    ${datadir}/${wiki}-${date}-stub-meta-history.xml.gz \
    ${geoipdir}/GeoLite2-Country-current/GeoLite2-Country.mmdb \
    ${etldir}/${wiki}-${date}-history-revisions.csv.gz || exit 1

time pv ${etldir}/${wiki}-${date}-history-revisions.csv.gz | gunzip | sed 's/\r//' | $PSQL -c "COPY ${wiki}.wikipedia_revisions FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"' NULL 'None'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.page_revisions; CREATE TABLE ${wiki}.page_revisions AS SELECT * FROM ${wiki}.view_page_revisions" || exit 1

##
## Geo tags for pages
##

# As the SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv |  $PSQL -c "COPY ${wiki}.wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.page_geotags; CREATE TABLE ${wiki}.page_geotags AS SELECT * FROM ${wiki}.view_page_geotags" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.page_geotag_primary; CREATE TABLE ${wiki}.page_geotag_primary AS SELECT * FROM ${wiki}.view_page_geotag_primary" || exit 1

##
## Spatial join
## 

echo "Spatial join... this will take a while."
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.page_country; CREATE TABLE ${wiki}.page_country AS SELECT * FROM ${wiki}.view_page_country" || exit 1

##
## Export
##

# Tables
$PSQL -c "COPY ${wiki}.page_geotags TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotags.csv || exit 1
$PSQL -c "COPY ${wiki}.page_geotag_primary TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotag_primary.csv || exit 1
$PSQL -c "COPY (SELECT page, iso_a2 as iso2 FROM ${wiki}.page_country p join countries c on (p.gid=c.gid)) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotag_primary_iso2.csv || exit 1
$PSQL -c "COPY ${wiki}.page_revisions TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_revisions.csv || exit 1

# Maps
$PSQL -c "COPY (SELECT p.page, max(lat) as lat, max(lon) as lon, r.iso2 as editor_iso2, count(*) as edits FROM ${wiki}.page_geotags p JOIN ${wiki}.page_revisions r ON (p.page=r.page) GROUP BY p.page, editor_iso2) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_coords_editor_country.csv || exit 1
$PSQL -c "COPY (SELECT p.page, max(lat) as lat, max(lon) as lon, count(*) as edits FROM ${wiki}.page_geotags p JOIN ${wiki}.page_revisions r ON (p.page=r.page) GROUP BY p.page) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_coords.csv || exit 1

