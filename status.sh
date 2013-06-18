#!/bin/zsh
echo "total number of job:"
/home/geadmin/UGER/bin/lx-amd64/qstat | awk '$5 ~ /^(qw|r)$/ {print $1}' | wc -l
echo ""
echo "Job count ranking"
echo "running"
/home/geadmin/UGER/bin/lx-amd64/qstat -u "*" | awk '$5 == "r" {print $4}' | sort | uniq -c | sort -nr | head
echo "waiting"
/home/geadmin/UGER/bin/lx-amd64/qstat -u "*" | awk '$5 == "qw" {print $4}' | sort | uniq -c | sort -nr | head
echo ""
echo "number of .sra files"
ls /home/inutano/project/ER/data/*sra | wc -l
echo "number of .bz2 files"
ls /home/inutano/project/ER/data/*bz2 | wc -l
echo "number of .fastq files"
ls /home/inutano/project/ER/fastq/*fastq | wc -l
echo "number of fastqc result files"
ls /home/inutano/project/ER/fastq/*zip | wc -l
echo ""
echo "disk size"
du -h /home/inutano/project/ER/data/
du -h /home/inutano/project/ER/fastq/
