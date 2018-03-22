#!/bin/bash

wiki=simplewiki
date=20180220
DB=${wiki}_${date}

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

time $PSQL -c "DROP TABLE IF EXISTS countries CASCADE" || exit 1
shp2pgsql -c -I ${neshapefile} countries > ${nesqlfile} || exit 1
time $PSQL < ${nesqlfile} || exit 1

time $PSQL < ${srcdir}/schema.sql || exit 1

##
## Revision history metadata
##

WGET="wget --continue --directory-prefix=${datadir}"
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-stub-meta-history.xml.gz || exit 1
$WGET http://wikimedia.bytemark.co.uk/${wiki}/${date}/${wiki}-${date}-geo_tags.sql.gz || exit 1

echo "Parsing the history XML... this will take a while."
time $PYTHON ${srcdir}/revisions.py \
    ${datadir}/${wiki}-${date}-stub-meta-history.xml.gz \
    ${geoipdir}/GeoLite2-Country-current/GeoLite2-Country.mmdb \
    ${etldir}/${wiki}-${date}-history-revisions.csv.gz || exit 1

time pv ${etldir}/${wiki}-${date}-history-revisions.csv.gz | gunzip | $PSQL -c "COPY wikipedia_anon_revisions FROM STDIN DELIMITERS ',' CSV HEADER QUOTE E'\"' ESCAPE '\' NULL 'None'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS page_revisions; CREATE TABLE page_revisions AS SELECT * FROM view_page_revisions" || exit 1

##
## Geo tags for pages
##

# As the SQL dumps are in MySQL format... convert INSERT statements to CSV.
# Fairly specific to this dump format.
function sql_insert_to_csv() {
    grep INSERT | awk '{gsub(/\),/,"\n",$0); print;}' | sed -e 's/^\(INSERT.*VALUES \)*(//g' | sed -e 's/);//' || return 1
}

time pv ${datadir}/${wiki}-${date}-geo_tags.sql.gz | gunzip | sql_insert_to_csv |  $PSQL -c "COPY wikipedia_geo_tags FROM STDIN DELIMITERS ',' CSV QUOTE E'\'' ESCAPE '\' NULL 'NULL'" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS page_geotags; CREATE TABLE page_geotags AS SELECT * FROM view_page_geotags" || exit 1
time $PSQL -c "DROP TABLE IF EXISTS page_geotag_primary; CREATE TABLE page_geotag_primary AS SELECT * FROM view_page_geotag_primary" || exit 1

##
## Spatial join
## 

echo "Spatial join... this will take a while."
time $PSQL -c "DROP TABLE IF EXISTS page_country; CREATE TABLE page_country AS SELECT * FROM view_page_country" || exit 1

##
## Export
##

# Tables
$PSQL -c "COPY page_geotags TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotags.csv || exit 1
$PSQL -c "COPY page_geotag_primary TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotag_primary.csv || exit 1
$PSQL -c "COPY (SELECT page, iso_a2 as iso2 FROM page_country p join countries c on (p.gid=c.gid)) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_geotag_primary_iso2.csv || exit 1
$PSQL -c "COPY page_revisions TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_revisions.csv || exit 1

# Maps
$PSQL -c "COPY (SELECT p.page, max(lat) as lat, max(lon) as lon, r.iso2 as editor_iso2, count(*) as edits FROM page_geotags p JOIN page_revisions r ON (p.page=r.page) GROUP BY p.page, editor_iso2) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_coords_editor_country.csv || exit 1
$PSQL -c "COPY (SELECT p.page, max(lat) as lat, max(lon) as lon, count(*) as edits FROM page_geotags p JOIN page_revisions r ON (p.page=r.page) GROUP BY p.page) TO STDOUT CSV HEADER" > ${csvdir}/${wiki}-${date}-page_coords.csv || exit 1

