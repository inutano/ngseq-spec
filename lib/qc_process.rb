# -*- coding: utf-8 -*-

require "yaml"

class QCprocess
  @@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]

  def initialize(runid)
    @runid = runid
  end
  
  def get_fq(subid, expid)
    location = "ftp.ddbj.nig.ac.jp/ddbj_database/dra/fastq/#{subid.slice(0,6)}/#{subid}/#{expid}"
    puts location
    log = @@path["log"] + "/lftp_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `lftp -c "open #{location} && mget -O #{@@path["data"]} #{@runid}* " >& #{log}`
  end
  
  def ftp_failed?
    log = Dir.glob(@@path["log"] + "/lftp_#{@runid}*.log").sort.last
    (log && open(log).read =~ /fail/)
  end

  def fastqc
    log = @@path["log"] + "/fastqc_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `/usr/local/gridengine/bin/lx24-amd64/qsub -o #{log} #{@@path["lib"]}/fastqc_fq.sh #{@run_id}`
  end
end
