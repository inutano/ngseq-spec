#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=16G,s_vmem=16G -pe def_slot 1
# ls data/ | sed -e 's:data/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

cd /home/inutano/project/ER/data
bunzip2 $1
fq=`echo $1 | sed -e 's:.bz2::'`
mv $fq /home/inutano/project/ER/fastq
