#!/bin/bash

set -eo pipefail

OUT_ZIP=_JLC_gerbers.zip
OUT_BOM=_JLC_BOM.csv
OUT_POS=_JLC_CPL.csv
ROTS=rotate.sh # Rotate to align with pick and place if this file exists in the print dir

PRJ=`ls *.pro | head -1`
PRJ=`basename ${PRJ} .pro`
BOM=${PRJ}-bom.csv
POS=${PRJ}-all-pos.csv


mkdir -p print

# The BOM is just output with no extension
mv ${PRJ} print/${BOM} 2>/dev/null || true

cd print
# Clean out old output
rm -f $OUT_ZIP
rm -f $OUT_BOM
rm -f $OUT_POS

BOM=${PRJ}-bom.csv
POS=${PRJ}-all-pos.csv

#JLC column renames
if [ -f "$BOM" ]; then
    sed 's/\;/,/g ; s/Reference/Designator/g ; s/Value/Comment/g' "$BOM" > $OUT_BOM
fi
if [ -f "$POS" ]; then
    sed \
    -e 's/PosX/Mid X/g' \
    -e 's/PosY/Mid Y/g' \
    -e 's/Ref/Designator/g' \
    -e 's/Rot/Rotation/g' \
    -e 's/Side/Layer/g' \
    "$POS" > ${OUT_POS}_tmp

    if [ -f "$ROTS" ]; then
        ./$ROTS "${OUT_POS}_tmp"
    fi

    (
        l=0
        mid_x=9999
        mid_y=9999
        layer=9999
        # print the header untouched
        #read line; echo "$line" >> /test/myCSV_new.csv
        IFS=,
        while read -ra fields; do
            if [[ "$l" -gt 0 ]]; then
                if [[ "$mid_x" -eq 9999 ]]; then
                    echo "Failed to find 'Mid X' column in POS output"
                    exit 1
                fi
                if [[ "$mid_y" -eq 9999 ]]; then
                    echo "Failed to find 'Mid Y' column in POS output"
                    exit 1
                fi
                if [[ "$layer" -eq 9999 ]]; then
                    echo "Failed to find 'Layer' column in POS output"
                    exit 1
                fi
                is_bot=1
                if [[ "${fields[$layer]}" = "bottom" ]]; then
                    is_bot=-1
                fi

                x=${fields[$mid_x]}
                y=${fields[$mid_y]}
                if [[ $x =~ .*mm ]]; then
                    echo "Already contains mm"
                else
                    x=`echo "$x * $is_bot" | bc`
                    fields[$mid_x]=${x}mm
                fi
                if [[ $y =~ .*mm ]]; then
                    echo "Already contains mm"
                else
                    fields[$mid_y]=${y}mm
                fi
                #fields[3]=$(dec2ip "${fields[3]}")
                #echo "${fields[*]}" >> /test/myCSV_new.csv
                echo "${fields[*]}" >> ${OUT_POS}
            else
                z=0
                for i in "${fields[@]}"; do
                    if [ "Mid X" = "$i" ]; then
                        mid_x=$z
                    fi
                    if [ "Mid Y" = "$i" ]; then
                        mid_y=$z
                    fi
                    if [ "Layer" = "$i" ]; then
                        layer=$z
                    fi
                    z=$((z+1))
                done
                echo "${fields[*]}" > ${OUT_POS}
            fi
            l=$((l+1))
        done
    ) < ${OUT_POS}_tmp
    rm ${OUT_POS}_tmp
fi

zip $OUT_ZIP ${PRJ}*.g* ${PRJ}*.drl $OUT_BOM $OUT_POS
