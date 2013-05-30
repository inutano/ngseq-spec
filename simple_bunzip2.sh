#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=4G,s_vmem=4G -pe def_slot 1
# ls data/ | sed -e 's:data/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

base="/home/inutano/project/ER/data"
cd ${base}
/usr/bin/bunzip2 ${base}/${1}
fq=`echo $1 | sed -e 's:.bz2::'`
mv ${base}/${fq} /home/inutano/project/ER/fastq
