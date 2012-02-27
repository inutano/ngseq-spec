# -*- coding: utf-8 -*-

require "twitter"

class ReportTwitter
  @@tw = Twitter::Client.new
  
  def self.stat
    usage = `df -h`.split("\n").select{|l| l =~ /home/ }.map{|l| l.split(/\s+/)}.flatten[4]
    session = `ps aux`.split("\n").select{|l| l =~ /lftp/ }.length / 2
    job = `qstat -u iNut`.split("\n").select{|l| l =~ /^[0-9]/}.length
    message = <<-MESSAGIO.gsub(/^\s*/,"")
      @null #{Time.now.strftime("%m/%d %H:%M:%S")}
      disk usage: #{usage}%
      #{session} ftp sessions
      #{job} job submitted
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
