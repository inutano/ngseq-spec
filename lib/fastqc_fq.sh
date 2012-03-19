#!/home/iNut/local/bin/zsh
#$ -j y
# fastqc_fq.sh <runid>

project_dir="/home/iNut/project/sra_qualitycheck"
fastqc_path="/home/iNut/local/bin/fastqc/fastqc"

runid=$1
data_dir="${project_dir}/data"
result_dir="${project_dir}/result/${runid}"

fastqc_command="${fastqc_path} --noextract --threads 8 --outdir ${result_dir} ${data_dir}/${runid}*fastq*"
cleaning_command="rm -fr ${data_dir}/${runid}*fastq*"

mkdir ${result_dir}
${fastqc_command} && ${cleaning_command}
