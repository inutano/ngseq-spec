# -*- coding: utf-8 -*-

require "yaml"
require "fileutils"
require "ap"

class QCprocess
  @@path = YAML.load_file("#{File.expand_path(File.dirname(__FILE__))}/config.yaml")["path"]

  def initialize(runid)
    @runid = runid
  end
  
  def get_fq(subid, expid)
    location = "ftp.ddbj.nig.ac.jp/ddbj_database/dra/fastq/#{subid.slice(0,6)}/#{subid}/#{expid}"
    log = @@path["log"] + "/lftp_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `lftp -c "open #{location} && mget -O #{@@path["data"]} #{@runid}* " >& #{log}`
  end
  
  def get_fq_local(subid, expid)
    sub_head = subid.slice(0,6)
    location = "/usr/local/ftp/ddbj_database/dra/fastq/#{sub_head}/#{subid}/#{expid}"
    miss_list = @@path["log"] + "/missing.idlist"
    FileUtils.touch(miss_list) unless File.exist?(miss_list)
    begin
      files = Dir.entries(location).select{|f| f =~ /^#{@runid}/ }
      files_fullpath = files.map{|f| "#{location}/#{f}" }
      data_dir = @@path["data"]
      
      if not files.empty?
        FileUtils.cp(files_fullpath, data_dir)
      else
        open(miss_list,"a"){|f| f.puts(@runid) }
      end
    rescue
      open(miss_list,"a"){|f| f.puts(@runid) }
    end
  end
  
  def ftp_failed?
    log = Dir.glob(@@path["log"] + "/lftp_#{@runid}*.log").sort.last
    (log && open(log).read =~ /fail/)
  end

  def fastqc
    log_dir = "#{@@path["log"]}/#{@runid.slice(0,6)}"
    FileUtils.mkdir(log_dir) if not File.exist?(log_dir)
    log = log_dir + "/fastqc_#{@runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `/home/geadmin/UGER/bin/lx-amd64/qsub -N #{@runid} -o #{log} #{@@path["lib"]}/fastqc_fq.sh #{@runid}`
  end
end

