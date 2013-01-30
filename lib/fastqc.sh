#$ -S /bin/bash -j y -l mem_req=16G,s_vmem=16G -pe def_slot 1
# fastqc_fq.sh <runid> <fpath> <config_path>

runid=$1
fpath=$2
config_path=$3

fastqc_path=`grep "^fastqc_path" ${config_path} | cut -d '"' -f 2`
data_path=`grep "^data_path" ${config_path} | cut -d '"' -f 2`

result_path=`grep "^result_path" ${config_path} | cut -d '"' -f 2`
runid_head=`echo ${runid} | sed -e 's:.\{3\}$::'`
result_dir="${result_path}/${runid_head}/${runid}"

result_file=`echo ${fpath} | sed -e 's:^.\+/::g' | sed -e 's:\..\+$:_fastqc.zip:g'`
result_fpath="${result_dir}/${result_file}"

dump=`grep "^fastq-dump_path" ${config_path} | cut -d '"' -f 2`

if [ -e ${result_fpath} ] ; then
  rm -f ${result_fpath}
fi

if [ ! -e ${result_dir} ] ; then
  mkdir -p ${result_dir}
fi

case "${fpath}" in
  *.tar.gz )
    unarchived=`echo ${fpath} | sed -e 's:\.tar\.gz$::'`
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived}"
    cleaning="rm -fr ${unarchived}"
    /bin/tar zxfv ${fpath} -C ${data_path} && ${fastqc} && ${cleaning} || touch "${unarchived}_failed" ;;

  *.tar.bz2 )
    unarchived=`echo ${fpath} | sed -e 's:\.tar\.bz2$::'`
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived}"
    cleaning="rm -fr ${unarchived}"
    /bin/tar jxfv ${fpath} -C ${data_path} && ${fastqc} && ${cleaning} || touch "${unarchived}_failed" ;;

  *.bz2 )
    unarchived=`echo ${fpath} | sed -e 's:\.bz2$::'`
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived}"
    cleaning="rm -fr ${unarchived}"
    cd ${data_path} && /usr/bin/bunzip2 ${fpath} && ${fastqc} && ${cleaning} || touch "${unarchived}_failed" ;;

  *.gz )
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${fpath}"
    cleaning="rm -fr ${fpath}"
    ${fastqc} && ${cleaning} || touch "${fpath}_failed" ;;

  *.fastq )
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${fpath}"
    cleaning="rm -fr ${fpath}"
    ${fastqc} && ${cleaning} || touch "${fpath}_failed" ;;

  *.sra )
    unarchived=`echo ${fpath} | sed -e 's:\.sra$::' | sed -e 's:\.lite$::' | sed -e 's:$:.fastq:'`
    fastqc="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived}"
    cleaning="rm -fr ${unarchived}"
    cd ${data_path} && ${dump} ${fpath} && ${fastqc} && ${cleaning} || touch "${unarchived}_failed"

    unarchived_1=`echo ${fpath} | sed -e 's:\.sra$::' | sed -e 's:\.lite$::' | sed -e 's:$:_1.fastq:'`
    if [ -e ${unarchived_1} ] ; then
      fastqc_1="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived_1}"
      cleaning_1="rm -fr ${unarchived_1}"
      cd ${data_path} && ${fastqc_1} && ${cleaning_1} || touch "${unarchived_1}_failed"
    fi

    unarchived_2=`echo ${fpath} | sed -e 's:\.sra$::' | sed -e 's:\.lite$::' | sed -e 's:$:_2.fastq:'`
    if [ -e ${unarchived_2} ] ; then
      fastqc_2="${fastqc_path} --noextract --outdir ${result_dir} ${unarchived_2}"
      cleaning_2="rm -fr ${unarchived_2}"
      cd ${data_path} && ${fastqc_2} && ${cleaning_2} || touch "${unarchived_2}_failed"
    fi

    rm -f ${fpath} ;;

  * )
    echo "failed: unknown file type" && exit 1 ;;
esac
