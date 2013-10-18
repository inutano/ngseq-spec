#!/bin/zsh

ls fastq/*fastq |\
while read f ; do
  echo "${f}\t`tail -1 ${f}`"
done |\
awk -F '\t' '$2 ~ /^@.RR/ || $2 ~ /^(A|T|G|C)+$/ {print $1}' |\
while read f ; do
  echo $f
  echo $f >> /home/inutano/project/ER/table/fqdumpfailed
  rm -f $f
done
