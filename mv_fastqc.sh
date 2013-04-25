#!/bin/zsh

cd ./data
ls |\
awk '$1 ~ /fastqc.zip$/ { print $1 }' |\
while read f ; do
  dir=`echo $f | awk '{ printf "/home/inutano/backup/fastqc_result/" "%.6s" "/" "%.9s", $1, $1 }'`
  if [ ! -e $dir ] ; then
    mkdir -p $dir
  fi
  mv $f $dir
done
