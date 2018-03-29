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

time pv ${etldir}/${wiki}-${date}-history-revisions.csv.gz | gunzip | sed 's/\r//' | sed 's/,""/,/g' | $PSQL -c "COPY ${wiki}.wikipedia_revisions FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.article_revisions; CREATE TABLE ${wiki}.article_revisions AS SELECT * FROM ${wiki}.view_article_revisions" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.wikipedia_page_stats; CREATE TABLE ${wiki}.wikipedia_page_stats AS SELECT * FROM ${wiki}.view_wikipedia_page_stats" || exit 1

##
## Geo tags for articles
##

# As the SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv |  $PSQL -c "COPY ${wiki}.wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.article_geotags; CREATE TABLE ${wiki}.article_geotags AS SELECT * FROM ${wiki}.view_article_geotags" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.article_geotag_primary; CREATE TABLE ${wiki}.article_geotag_primary AS SELECT * FROM ${wiki}.view_article_geotag_primary" || exit 1

##
## Spatial joins
## 

echo "Spatial joins... this will take a while."
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.article_country; CREATE TABLE ${wiki}.article_country AS SELECT * FROM ${wiki}.view_article_country" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS ${wiki}.article_province; CREATE TABLE ${wiki}.article_province AS SELECT * FROM ${wiki}.view_article_province" || exit 1

##
## Export
##

# Tables
#$PSQL -c "COPY ${wiki}.article_geotags TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_geotags.csv || exit 1
#$PSQL -c "COPY ${wiki}.article_geotag_primary TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_geotag_primary.csv || exit 1
$PSQL -c "COPY (SELECT page, iso_a2 as iso2 FROM ${wiki}.article_country a join countries c on (a.gid=c.gid)) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_geotag_primary_country.csv || exit 1
$PSQL -c "COPY (SELECT page, iso_a2 as iso2, iso_3166_2, name FROM ${wiki}.article_province a join provinces p on (a.gid=p.gid)) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_geotag_primary_province.csv || exit 1
#$PSQL -c "COPY ${wiki}.article_revisions TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_revisions.csv || exit 1

# Maps
$PSQL -c "COPY (SELECT ag.page, max(lat) as lat, max(lon) as lon, ar.iso2 as editor_iso2, count(*) as edits FROM ${wiki}.article_geotags ag JOIN ${wiki}.article_revisions ar ON (ag.page=ar.page) GROUP BY ag.page, editor_iso2) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_coords_editor_country.csv || exit 1
$PSQL -c "COPY (SELECT ag.page, max(lat) as lat, max(lon) as lon, count(*) as edits FROM ${wiki}.article_geotags ag JOIN ${wiki}.article_revisions ar ON (ag.page=ar.page) GROUP BY ag.page) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-article_coords.csv || exit 1

