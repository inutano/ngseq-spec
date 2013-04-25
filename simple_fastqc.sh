#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=16G,s_vmem=16G -pe def_slot 1
# ls fastq/ | sed -e 's:fastq/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

cd /home/inutano/project/ER/fastq
/home/inutano/local/bin/fastqc --noextract $1 && rm -f $1
