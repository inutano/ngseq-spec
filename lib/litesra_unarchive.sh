#$ -S /bin/bash -j y -l mem_req=8G,s_vmem=8G
# litesra_unarchive.sh <runid>

runid=${1}
dump="/home/inutano/local/bin/sratoolkit/fastq-dump --split-3"
p_dir="/home/inutano/project/sra_qualitycheck"
litesra_dir="${p_dir}/litesra"
data_dir="${p_dir}/data"
error_log="${litesra_dir}/unarchive_error.log"

cd ${litesra_dir}
${dump} ${litesra_dir}/${runid}.lite.sra \
&& mv ${litesra_dir}/${runid}*.fastq ${data_dir} \
&& rm -f ${litesra_dir}/${runid}.lite.sra \
|| (echo "failed unarchive ${runid}" >> ${error_log})

