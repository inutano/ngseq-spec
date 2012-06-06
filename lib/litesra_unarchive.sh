#$ -S /bin/bash -j y -l mem_req=8G,s_vmem=8G
# litesra_unarchive.sh <lite.sra full file path>

dest="/home/inutano/project/sra_qualitycheck/data"
toolkit="/home/inutano/local/bin/sratoolkit/fastq-dump --split3"
file_path=$1
cleaning="rm -fr ${file_path}"
error_log="/home/inutano/project/sra_qualitycheck/litesra/unarchive_errror.log"

cd ${dest}
${toolkit} ${file_path} && ${cleaning} || (echo "failed unarchive ${file_path}" >> error_log)
