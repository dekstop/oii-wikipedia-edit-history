#!/bin/bash

wiki=simplewiki
date=20180220
DB=${wiki}_${date}

PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"
${PSQL} -c "SELECT 1" || exit 1

PYTHON=~/osm/ipython-env/env/bin/python

srcdir=~/oiidg/src
geoipdir=~/oiidg/geoip
datadir=~/oiidg/data

##
## DB schema
##

time $PSQL < ${srcdir}/schema.sql || exit 1

##
## Revision history metadata
##

# ${srcdir}/getdata.sh || exit 1

# time $PYTHON ${srcdir}revisions.py \
#     ${datadir}/${wiki}-${date}-stub-meta-history.xml.gz \
#     ${geoipdir}/GeoLite2-Country-current/GeoLite2-Country.mmdb \
#     ${datadir}/${wiki}-${date}-history-revisions.csv.gz || exit 1

time pv ${datadir}/${wiki}-${date}-history-revisions.csv.gz | gunzip | $PSQL -c "COPY wikipedia_anon_revisions FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"' ESCAPE '\' NULL 'None'" || exit 1

##
## Geo tags for pages
##

# As th SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv |  $PSQL -c "COPY wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1

