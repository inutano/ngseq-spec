# -*- coding: utf-8 -*-

require "yaml"
require "twitter"

tw_conf = YAML.load_file("#{File.expand_path(File.dirname(__FILE__))}/config.yaml")["twitter"]

Twitter.configure do |config|
  config.consumer_key = tw_conf["consumer_key"]
  config.consumer_secret = tw_conf["consumer_secret"]
  config.oauth_token = tw_conf["oauth_token"]
  config.oauth_token_secret = tw_conf["oauth_token_secret"]
end

class ReportStat
  def self.diskusage
    # original
    # `df -h`.split("\n").select{|l| l =~ /home/ }.map{|l| l.split(/\s+/)}.flatten[4]
    yaml = YAML.load_file("#{File.expand_path(File.dirname(__FILE__))}/config.yaml")
    data_dir = yaml["path"]["data"]
    total_size = Dir.entries(data_dir).map{|f| File.exist?("#{data_dir}/#{f}") ? File.size("#{data_dir}/#{f}") : 0 }.reduce(:+)
    total_size
  end
  
  def self.ftpsession
    `ps aux`.split("\n").select{|l| l =~ /lftp/ }.length / 2
  end
  
  def self.qstat
    `qstat -u inutano`.split("\n").select{|l| l =~ /^\s+[0-9]/}.length
  end
end

class ReportTwitter
  @@tw = Twitter::Client.new
  
  def self.stat(diskusage, ftpsession, qstat)
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null tkr #{Time.now.strftime("%m/%d %H:%M:%S")}
      disk usage: #{diskusage}
      #{ftpsession} ftp sessions
      #{qstat} job submitted
    MESSAGIO
    @@tw.update(message)
  end
  
  def self.job(done, available, all)
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null tkr #{Time.now.strftime("%m/%d %H:%M:%S")}
      #{done.length} of runs finished,
      #{available.length} of runs ahead.
      #{(done.length.to_f / all.length) * 100}%
    MESSAGIO
    @@tw.update(message)
  end
  	
  def self.error(missing)
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null tkr #{Time.now.strftime("%m/%d %H:%M:%S")}
      #{missing.length.to_s} errors reported.
    MESSAGIO
    @@tw.update(message)
  end
end
