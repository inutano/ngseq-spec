#!/home/iNut/local/bin/zsh
#$ -j y

id=$1
fastq_dump="/home/iNut/local/bin/sratoolkit/fastq-dump"
fastqc="/home/iNut/local/bin/fastqc/fastqc"
data_location="/home/iNut/project/sra_qualitycheck/data"
file_path="${data_location}/${id}.lite.sra"
result_dir="/home/iNut/project/sra_qualitycheck/result/${id}"

fastq_dump_command="${fastq_dump} --split-3 -O ${data_location} ${file_path}"
fastqc_command="${fastqc} --noextract --threads 8 --outdir ${result_dir} ${data_location}/${id}*fastq"
cleaning_command="rm -rf ${data_location}/${id}*"

mkdir ${result_dir}
${fastq_dump_command} && ${fastqc_command} && ${cleaning_command}
