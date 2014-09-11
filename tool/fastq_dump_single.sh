#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=4G,s_vmem=4G -pe def_slot 1
# ls data/*.sra | sed -e 's:data/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

cd /home/inutano/project/ER/data
/home/inutano/local/bin/sratoolkit/fastq-dump --split-3 $1 && rm -f $1
mv ${1:0:9}*.fastq /home/inutano/project/ER/fastq
