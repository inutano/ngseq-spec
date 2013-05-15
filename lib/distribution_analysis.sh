#!/bin/zsh
# usage:
#  ./distribution_analysis.sh <qc count data with metadata>

data=${1}
total=`awk -F '\t' '$1 ~ /^.RR/ { print $1 }' ${data} | wc -l`
echo "total number of data:\t${total}"

total_454=`awk -F '\t' '$1 ~ /^.RR/ && $10 == "454" { print $1 }' ${data} | wc -l`
total_pac=`awk -F '\t' '$1 ~ /^.RR/ && $10 == "PacBio" { print $1 }' ${data} | wc -l`
total_illumina=`awk -F '\t' '$1 ~ /^.RR/ && $10 == "Illumina" { print $1 }' ${data} | wc -l`
total_ab=`awk -F '\t' '$1 ~ /^.RR/ && $10 == "AB" { print $1 }' ${data} | wc -l`

echo ""

echo "------throughput------"
th3K_30K=`awk -F '\t' '$2 >= 3000 && $2 <= 30000 { print $1 }' ${data} | wc -l`
echo "3,000~30,000:\t"${th3K_30K}
echo "ratio:\t"$((${th3K_30K}. / ${total} * 100))
th1M_100M=`awk -F '\t' '$2 >= 1000000 && $2 <= 100000000 { print $1 }' ${data} | wc -l`
echo "1,000,000~100,000,000:\t"${th1M_100M}
echo "ratio:\t"$((${th1M_100M}. / ${total} * 100))

echo "------by platform------"
th3K_30K_pac=`awk -F '\t' '$2 >= 3000 && $2 <= 30000 && $10 == "PacBio" { print $1 }' ${data} | wc -l`
echo "PacBio in 3,000~30,000:\t"${th3K_30K_pac}
echo "ratio:\t"$((${th3K_30K_pac}. / ${total_pac} * 100))
th3K_30K_454=`awk -F '\t' '$2 >= 3000 && $2 <= 30000 && $10 == "454" { print $1 }' ${data} | wc -l`
echo "454 in 3,000~30,000:\t"${th3K_30K_454}
echo "ratio:\t"$((${th3K_30K_454}. / ${total_454} * 100))

th1M_100M_454=`awk -F '\t' '$2 >= 1000000 && $2 <= 100000000 && $10 == "454" { print $1 }' ${data} | wc -l`
echo "454 in 1,000,000~100,000,000:\t"${th1M_100M_454}
echo "ratio:\t"$((${th1M_100M_454}. / ${total_454} * 100))

th1M_100M_illumina=`awk -F '\t' '$2 >= 1000000 && $2 <= 100000000 && $10 == "Illumina" { print $1 }' ${data} | wc -l`
echo "illumina in 1,000,000~100,000,000:\t"${th1M_100M_illumina}
echo "ratio:\t"$((${th1M_100M_illumina}. / ${total_illumina} * 100))
th1M_100M_AB=`awk -F '\t' '$2 >= 1000000 && $2 <= 100000000 && $10 == "AB" { print $1 }' ${data} | wc -l`
echo "AB in 1,000,000~100,000,000:\t"${th1M_100M_AB}
echo "ratio:\t"$((${th1M_100M_AB}. / ${total_ab} * 100))

echo ""

echo "------max read length------"
read30_100=`awk -F '\t' '$4 >= 30 && $4 <= 100 { print $1 }' ${data} | wc -l`
echo "30~100:\t"${read30_100}
echo "ratio:\t"$((${read30_100}. / ${total} * 100))
read300_1000=`awk -F '\t' '$4 >= 300 && $4 <= 1000 { print $1 }' ${data} | wc -l`
echo "300~1000:\t"${read300_1000}
echo "ratio:\t"$((${read300_1000}. / ${total} * 100))
read3000_10000=`awk -F '\t' '$4 >= 3000 && $4 <= 10000 { print $1 }' ${data} | wc -l`
echo "3000~10000:\t"${read3000_10000}
echo "ratio:\t"$((${read3000_10000}. / ${total} * 100))

echo "------by platform------"
read30_100_illumina=`awk -F '\t' '$4 >= 30 && $4 <= 100 && $10 == "Illumina" { print $1 }' ${data} | wc -l`
echo "Illumina in 30~100:\t"${read30_100_illumina}
echo "ratio:\t"$((${read30_100_illumina}. / ${total_illumina} * 100))
read30_100_ab=`awk -F '\t' '$4 >= 30 && $4 <= 100 && $10 == "AB" { print $1 }' ${data} | wc -l`
echo "AB in 30~100:\t"${read30_100_ab}
echo "ratio:\t"$((${read30_100_ab}. / ${total_ab} * 100))
read300_1000_454=`awk -F '\t' '$4 >= 300 && $4 <= 1000 && $10 == "454" { print $1 }' ${data} | wc -l`
echo "454 in 300~1000:\t"${read300_1000_454}
echo "ratio:\t"$((${read300_1000_454}. / ${total_454} * 100))
read3000_10000_pac=`awk -F '\t' '$4 >= 3000 && $4 <= 10000 && $10 == "PacBio" { print $1 }' ${data} | wc -l`
echo "PacBio in 3000~10000:\t"${read3000_10000_pac}
echo "ratio:\t"$((${read3000_10000_pac}. / ${total_pac} * 100))

echo ""

echo "------phred score------"
ps_over30=`awk -F '\t' '$6 >= 30 { print $1 }' ${data} | wc -l`
echo "over 30:\t"${ps_over30}
echo "ratio:\t"$((${ps_over30}. / ${total} * 100))
ps_under20=`awk -F '\t' '$6 <= 20 { print $1 }' ${data} | wc -l`
echo "under 20:\t"${ps_under20}
echo "ratio:\t"$((${ps_under20}. / ${total} * 100))

echo "------by platform------"
ps_under20_pac=`awk -F '\t' '$6 <= 20 && $10 == "PacBio" { print $1 }' ${data} | wc -l`
echo "Pac in under 20:\t"${ps_under20_pac}
echo "Pac ratio in under 20:\t"$((${ps_under20_pac}. / ${ps_under20} * 100))

echo ""

echo "------duplicate percentage------"
dp_under5=`awk -F '\t' '$8 <= 5 { print $1 }' ${data} | wc -l`
echo "under 5%:\t"${dp_under5}
echo "ratio:\t"$((${dp_under5}. / ${total} * 100))
dp_under10=`awk -F '\t' '$8 <= 10 { print $1 }' ${data} | wc -l`
echo "under 10%:\t"${dp_under10}
echo "ratio:\t"$((${dp_under10}. / ${total} * 100))
dp_over90=`awk -F '\t' '$8 >= 90 { print $1 }' ${data} | wc -l`
echo "over 90%:\t"${dp_over90}
echo "ratio:\t"$((${dp_over90}. / ${total} * 100))

echo "------by platform------"
dp_under5_wgs=`awk -F '\t' '$8 <= 5 && $11 == "WGS" { print $1 }' ${data} | wc -l`
echo "WGS in under 5%:\t"${dp_under5_wgs}
echo "WGS ratio in under 5%:\t"$((${dp_under5_wgs}. / ${db_under5} * 100))

dp_under5_wxs=`awk -F '\t' '$8 <= 5 && $11 == "WXS" { print $1 }' ${data} | wc -l`
echo "WXS in under 5%:\t"${dp_under5_wgs}
echo "WXS ratio in under 5%:\t"$((${dp_under5_wxs}. / ${db_under5} * 100))

dp_over90_amp=`awk -F '\t' '$8 >= 90 && $11 == "AMPLICON" { print $1 }' ${data} | wc -l`
echo "amplicon in over 90%:\t"${dp_over90_amp}
echo "amplicon ratio in over 90%:\t"$((${dp_over90_amp}. / ${dp_over90} * 100))

#1 filename
#2 total_sequences
#3 min_length
#4 max_length
#5 percent_gc
#6 normalized_phred_score
#7 total_n_content
#8 total_duplicate_percentage
#9 instrument
#10 platform
#11 lib_strategy
#12 lib_source
#13 lib_selection
#14 lib_layout
#15 lib_nominal_length
#16 lib_nominal_sdev
