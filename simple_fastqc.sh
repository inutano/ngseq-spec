#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=32G,s_vmem=32G -pe def_slot 1
# ls data/ | sed -e 's:data/::g' | while read f ; do ; qsub -N $f simple_fastqc.sh $f ; done

cd /home/inutano/project/ER/data
/home/inutano/local/bin/fastqc --noextract $1
