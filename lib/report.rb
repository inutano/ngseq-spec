# -*- coding: utf-8 -*-

require "yaml"
require "twitter"

tw_conf = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["twitter"]

Twitter.configure do |config|
  config.consumer_key = tw_conf["consumer_key"]
  config.consumer_secret = tw_conf["consumer_secret"]
  config.oauth_token = tw_conf["oauth_token"]
  config.oauth_token_secret = tw_conf["oauth_token_secret"]
end

class ReportStat
  def self.diskusage
    `df -h`.split("\n").select{|l| l =~ /home/ }.map{|l| l.split(/\s+/)}.flatten[4]
  end
  
  def self.ftpsession
    `ps aux`.split("\n").select{|l| l =~ /lftp/ }.length / 2
  end
  
  def self.qstat
    `qstat -u iNut`.split("\n").select{|l| l =~ /^[0-9]/}.length
  end
end

class ReportTwitter
  @@tw = Twitter::Client.new
  
  def self.stat(diskusage, ftpsession, qstat)
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null #{Time.now.strftime("%m/%d %H:%M:%S")}
      disk usage: #{diskusage}
      #{ftpsession} ftp sessions
      #{qstat} job submitted
    MESSAGIO
    @@tw.update(message)
  end
  
  def self.job(done, available, all)
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null #{Time.now.strftime("%m/%d %H:%M:%S")}
      #{done.length} of runs finished,
      #{available.length} of runs ahead.
      #{(done.length.to_f / all.length) * 100}%
    MESSAGIO
    @@tw.update(message)
  end
  	
  def self.error(missing)
    missing.join(",").scan(/.{100}/).each do |list|
      message = <<-MESSAGIO.gsub(/^\s*/,"")
        @null #{Time.now.strftime("%m/%d %H:%M:%S")}
        error occurred:
        #{list.gsub(/,$/,"")}
      MESSAGIO
      @@tw.update(message)
    end
  end
end
