#!/home/iNut/local/bin/zsh
#$ -j y

id=$1
fastq_dump="/home/iNut/local/bin/sratoolkit/fastq-dump"
fastqc="/home/iNut/local/bin/fastqc/fastqc"
data_location="/home/iNut/project/sra_qualitycheck/data"
file_path="${data_location}/${id}.lite.sra"

fastq_dump_command="${fastq_dump} --split-3 -O ${data_location} ${file_path}"
fastqc_command="${fastqc} --noextract --threads 8 --outdir /home/iNut/project/sra_qualitycheck/result ${data_location}/${id}*"

${fastq_dump_command} && ${fastqc_command}
