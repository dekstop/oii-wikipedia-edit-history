#!/bin/bash
wiki=simplewiki
date=20180220
outdir=~/oiidg/data
WGET="wget --directory-prefix=${outdir}"

WGET https://dumps.wikimedia.org/${wiki}/${date}/${wiki}-${date}-stub-meta-history.xml.gz || exit 1
WGET https://dumps.wikimedia.org/${wiki}/${date}/${wiki}-${date}-geo_tags.sql.gz || exit 1

