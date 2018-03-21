#!/bin/bash

wiki=simplewiki
date=20180220
DB=${wiki}_${date}
PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"

${PSQL} -c "SELECT 1" || exit 1

datadir=~/oiidg/data
srcdir=~/oiidg/src

# As th SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

time $PSQL < ${srcdir}/schema.sql || exit 1
time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv |  $PSQL -c "COPY wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1

