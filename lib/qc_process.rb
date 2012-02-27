# -*- coding: utf-8 -*-

require "yaml"

class QCprocess
  @@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]

  def initialize(runid)
    accessions = @@path["lib"] + "/SRA_Accessions.tab"
    run_members = @@path["lib"] + "/SRA_Run_Members.tab"
    @runid = runid
    @subid = open(accessions).readlines.select{|l| l =~ /^#{runid}/}.join.split("\t")[1]
    @expid = open(run_members).readlines.select{|l| l =~ /^#{runid}/}.join.split("\t")[2]
  end
  
  def get_fq
    location = "ftp.ddbj.nig.ac.jp/ddbj_database/dra/fastq/#{@subid.slice(0,6)}/#{@subid}/#{@expid}"
    log = @@path["log"] + "/lftp_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `lftp -c "open #{location} && mget -O #{@@path["data"]} * " >& #{log}`
  end

  def fastqc
    log = @@path["log"] + "/fastqc_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `/usr/local/gridengine/bin/lx24-amd64/qsub -o #{log} #{@@path["lib"]}/fastqc_fq.sh #{@run_id}`
  end
end
