#!/bin/zsh

cd /home/inutano/project/ER/fastq
ls |\
awk '$1 ~ /fastqc.zip$/ { print $1 }' |\
while read f ; do
  id=`echo ${f} | sed -e 's:_fastqc.zip::' | sed -e 's:_.::'`
  idx=`echo ${id} | sed -e 's:...$::'`
  dir=`echo ${id} | awk -v idx="${idx}" '{ printf "/home/inutano/backup/fastqc_result/" idx "/" $1 }'`
  if [ ! -e ${dir} ] ; then
    mkdir -p ${dir}
  fi
  old="${dir}/${f}"
  if [ -e ${old} ] ; then
    rm -f ${old}
  fi
  mv ${f} "${dir}/"
done
