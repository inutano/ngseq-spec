#$ -o /home/inutano/project/ER/log -S /bin/bash -j y -l mem_req=4G,s_vmem=4G -pe def_slot 1
# qsub -N put_my_job_in multi_fastqdump.sh

base="/home/inutano/project/ER/data"
cd ${base}
ls -S ${base}/*sra | while read f ; do
  /home/inutano/local/bin/sratoolkit/fastq-dump --split-3 ${f} && \
   rm -f ${f} && \
   mv ${base}/${1:0:9}*.fastq /home/inutano/project/ER/fastq && \
   echo "${f} finished at `date "+%H:%M:%S"`" || \
   ( mv ${f} /home/inutano/project/ER/fqdumpfailed && \
     echo "An error occurred during processing ${f};" && \
     echo "  ${f} moved to fqdumpfailed" && \
     echo "  possibly disk full, check and type continue;" && \
     while [ "${SIGNAL}" != "continue" ] ; do
       read SIGNAL
     done \
   )
done
