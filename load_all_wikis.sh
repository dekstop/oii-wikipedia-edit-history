#!/bin/bash

SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd )

languages="af ak am ar arz az be bg ca ceb ce cs cy da de el en eo es et eu fa fi fr gl ha he hi hr hu hy id ig it ja ka kg ki kk ko la lg ln lt mg min ms nl nn no nso ny om pl pt rn ro ru rw sh simple sk sl sn so sr st sv sw ta th ti tn tr uk ur uz vi vo war xh yo zh_min_nan zh zu"

for lang in $languages
do 
    time ${SCRIPT_DIR}/loadwiki.sh oiidg_wp_20180220 ${lang}wiki 20180220 || exit 1
done
