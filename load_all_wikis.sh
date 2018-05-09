#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd )

DB=
date=

if [[ $# -ne 2 ]]
then
  echo "Usage : $0 <db> <date>"
  exit 1
else
  DB=$1
  date=$2
fi

PSQL="psql --set ON_ERROR_STOP=1 -U oiidg -h localhost ${DB}"

languages="af als am an ar arz ast az azb ba bar bat-smg be bg bn bpy br bs bug ca cdo ce ceb ckb cs cv cy da de el en eo es et eu fa fi fo fr fy ga gd gl gu he hi hr hsb ht hu hy ia id ilo io is it ja jv ka kk kn ko ku ky la lb li lmo lt lv mai map-bms mg min mk ml mn mr mrj ms my mzn nap nds ne new nl nn no oc or os pa pl pms pnb pt qu ro ru sa sah scn sco sh si simple sk sl sq sr su sv sw ta te tg th tl tr tt uk ur uz vec vi vo wa war xmf yi yo zh zh-min-nan zh-yue"
# should include but data is not available: be-tarask
# manually added later: ak ha ig kg ki lg ln nso ny om rn rw sn so st ti tn xh zu

for lang in $languages
do 
    wiki=`echo "${lang}wiki" | sed -e 's/[^[:alnum:]]/_/g'`
    time ${SCRIPT_DIR}/loadwiki.sh $DB $wiki $date || exit 1
done

time $PSQL < ${SCRIPT_DIR}/allwikis.sql || exit 1

