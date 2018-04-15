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

schema=`echo "${wiki}" | sed -e 's/[^[:alnum:]]/_/g'`
PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"
${PSQL} -c "SELECT 1" || exit 1

PYTHON=~/osm/ipython-env/env/bin/python

srcdir=~/oiidg/src
geoipdir=~/oiidg/geoip

datadir=~/oiidg/data/${wiki}_${date}
etldir=${datadir}/etl

mkdir -p $etldir 2>&1

##
## DB schema
##

time $PSQL < ${srcdir}/wikitemplate.sql || exit 1
$PSQL -c "DROP SCHEMA IF EXISTS ${schema} CASCADE" || exit 1
$PSQL -c "ALTER SCHEMA wikitemplate RENAME TO ${schema}" || exit 1

##
## Revision history metadata
##

WGET="wget --continue --directory-prefix=${datadir}"
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-stub-meta-history.xml.gz || exit 1
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-geo_tags.sql.gz || exit 1

echo "Extracting ${wiki} page revision metadata... this will take a while."
time $PYTHON ${srcdir}/revisions.py --errors \
    ${datadir}/${wiki}-${date}-stub-meta-history.xml.gz \
    ${geoipdir}/GeoLite2-Country-current/GeoLite2-Country.mmdb \
    ${etldir}/${wiki}-${date}-history-revisions.csv.gz || exit 1

time pv ${etldir}/${wiki}-${date}-history-revisions.csv.gz | gunzip | sed 's/\r//' | sed 's/,""/,/g' | $PSQL -c "COPY ${schema}.wikipedia_revisions FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"'" || exit 1
time $PSQL -c "REFRESH MATERIALIZED VIEW ${schema}.page_stats" || exit 1

##
## Geo tags for articles
##

# As the SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

function strip_invalid_utf8() {
    iconv -f utf-8 -t utf-8 -c || return 1
}

time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv | strip_invalid_utf8 | $PSQL -c "COPY ${schema}.wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1
time $PSQL -c "REFRESH MATERIALIZED VIEW ${schema}.article_geotags" || exit 1
time $PSQL -c "REFRESH MATERIALIZED VIEW ${schema}.article_geotag_primary" || exit 1

##
## Spatial joins
##

time $PSQL -c "REFRESH MATERIALIZED VIEW ${schema}.article_country" || exit 1
time $PSQL -c "REFRESH MATERIALIZED VIEW ${schema}.article_province" || exit 1

##
## Controvery scores
##

echo "Computing ${wiki} controversy scores... this will take a while."
time $PYTHON ${srcdir}/controversy_scores.py --errors \
    ${datadir}/${wiki}-${date}-stub-meta-history.xml.gz \
    ${etldir}/${wiki}-${date}-controversy_scores.csv.gz || exit 1

time pv ${etldir}/${wiki}-${date}-controversy_scores.csv.gz | gunzip | $PSQL -c "COPY ${schema}.page_controversy FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"'" || exit 1

