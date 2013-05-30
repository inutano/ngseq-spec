#!/bin/zsh

input=${1}
awk -F '\t' '$1 !~ /filename/ { printf "%.9s" "\n", $1 }' ${input} |\
sort -u |\
while read f ; do
  lines=`awk -F '\t' -v id="$f" 'match($1, "^" id) { print $0 }' ${input}`
  num=`echo ${lines} | wc -l`
  if [ ${num} -eq 1 ] ; then
    echo ${lines} | sed -e 's:\.fastq::g' -e 's:\.bz2::g' -e 's:\.gz::g'
  else
    echo ${lines} |\
    awk -F '\t' -v id="$f" '$1 ~ /^(S|E|D)RR[0-9]{6}_(1|2)/ {
      th += $2
      min += $3
      max += $4
      gc += $5
      ph += $6
      nc += $7
      du += $8 }
    END{
      printf id "\t" th / 2 "\t" min/2 "\t" max/2 "\t" gc/2 "\t" ph/2 "\t" nc/2 "\t" du/2 "\n"
    }'
  fi
done
