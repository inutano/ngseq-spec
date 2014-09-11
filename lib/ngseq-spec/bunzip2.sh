#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=4G,s_vmem=4G -pe def_slot 1
# ls data/ | sed -e 's:data/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

base="/home/inutano/project/ER"
fq=`echo $1 | sed -e 's:.bz2::'`
cd "${base}/data"
/usr/bin/bunzip2 ${1} && mv ${fq} "${base}/fastq"
