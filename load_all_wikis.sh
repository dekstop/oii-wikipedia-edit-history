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

# All wikis, sorted by article count in descending order.
# Should include but data is not available: be-tarask
languages="en ceb sv de fr nl ru it es pl war vi ja zh pt uk fa sr ca ar no sh fi hu id ko cs ro ms tr eu eo bg hy da zh-min-nan sk he min kk hr lt et ce sl be gl el ur nn az simple uz la hi th ka vo ta cy mk tg mg lv oc tl ky tt bs ast sq azb new te zh-yue br pms bn ml jv lb ht sco mr af ga pnb is ba sw cv fy su my lmo an yo ne nds pa gu io scn bar bpy als ku kn ckb ia qu arz mn bat-smg si gd wa nap yi am bug or cdo map-bms hsb fo mzn mai xmf li sah sa vec ilo os mrj mhr hif eml sd bh roa-tara ps diq wuu pam hak nso zh-classical bcl se ace mi szl nah nds-nl frr rue vls gan km bo crh sc vep glk co fiu-vro tk lrc kv myv csb gv as nv so zea udm ay lez stq ie nrm ug kw lad pcd mwl sn gn rm gom koi ab lij mt fur dsb dv ang frp ln cbk-zam kab ext dty ksh lo gag olo pag pi av haw bxr pfl xal krc pap kaa rw pdc bjn ha to nov kl arc jam kbd tyv tpi kbp tet ki ig na jbo lbe roa-rup ty mdf za kg bi wo lg srn tcy zu chr ltg sm om xh rmy bm cu tn pih rn chy tw tum ts ak got st atj pnt ss ch fj ady iu ny ee ks ik ve sg ff dz ti cr din ng cho kj mh ho ii aa mus hz kr"

for lang in $languages
do 
    wiki=`echo "${lang}wiki" | sed -e 's/[^[:alnum:]]/_/g'`
    time ${SCRIPT_DIR}/loadwiki.sh $DB $wiki $date || exit 1
done

time $PSQL < ${SCRIPT_DIR}/allwikis.sql || exit 1

