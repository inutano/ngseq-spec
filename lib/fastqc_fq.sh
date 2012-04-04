#!/home/iNut/local/bin/zsh
#$ -j y
# fastqc_fq.sh <runid>

project_dir="/home/iNut/project/sra_qualitycheck"
fastqc_path="/home/iNut/local/bin/fastqc/fastqc"

runid=$1
data_dir="${project_dir}/data"
result_dir="${project_dir}/result/${runid}"

fastqc_command="${fastqc_path} --noextract --outdir ${result_dir} ${data_dir}/${runid}*fastq*"
cleaning_command="rm -fr ${data_dir}/${runid}*fastq*"
gunzip="/bin/gunzip"
bunzip="/usr/bin/bunzip2"

if [ ! -e ${result_dir} ] ; then
  mkdir ${result_dir}
fi

files=(`ls ${data_dir}/${runid}*`)

case "${files[0]}" in
  *.tar.gz )
    /bin/tar zxfv ${files[@]} -C ${data_dir} && ${fastqc_command} && ${cleaning_command} || (echo "failed fastqc" && ${cleaning_command}) ;;
  *.tar.bz2 )
    /bin/tar jxfv ${files[@]} -C ${data_dir} && ${fastqc_command} && ${cleaning_command} || (echo "failed fastqc" && ${cleaning_command}) ;;
  *.bz2 )
    cd ${data_dir} && /usr/bin/bunzip2 ${files[@]} && ${fastqc_command} && ${cleaning_command} || (echo "failed fastqc" && ${cleaning_command}) ;;
  *.gz )
    ${fastqc_command} && ${cleaning_command} || (echo "failed fastqc" && ${cleaning_command}) ;;
  * )
    echo "failed: unknown file type" && exit 1 ;;
esac
