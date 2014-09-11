#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=2G,s_vmem=2G -pe def_slot 4
# ls fastq/ | sed -e 's:fastq/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

cd /home/inutano/project/ER/fastq
/home/inutano/local/bin/fastqc --thread 4 --noextract $1 && rm -f $1
