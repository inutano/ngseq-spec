# -*- coding: utf-8 -*-

require "yaml"
require "active_record"
require "logger"
require "twitter"

require "./lib/sraid"
require "./lib/qc_process"
require "./lib/report"

if __FILE__ == $0
  path = YAML.load_file("./lib/config.yaml")["path"]
  ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database => path["lib"] + "/production.sqlite3",
    :timeout => 5000
  )
  
  ActiveRecord::Base.logger = Logger.new(path["log"] + "/database.log")

  if ARGV.first == "--transmit"
    loop do
      puts "begin transmission #{Time.now}"
      available = SRAID.available[0..15]
      disk_limit = 10_000_000_000_000_000
      
      threads = []
      fired = []
      if ReportStat.diskusage < disk_limit
        available.each do |record|
          runid = record.runid
          subid = record.subid
          expid = record.expid
          
          qcp = QCprocess.new(runid)
          th = Thread.new do
            qcp.get_fq_local(subid, expid)
          end
          
          threads << th
          fired << runid
          puts "copying #{runid}.."
        end
      end
      
      puts "waiting #{threads.length} forked processes to complete.. #{Time.now}"
      threads.each do |th|
        th.join
      end
      
      missing = open("#{path["log"]}/missing.idlist").readlines.map{|l| l.chomp }
      SRAID.transaction do
        fired.each do |runid|
          record = SRAID.find_by_runid(runid)
          begin
            if missing.include?(runid)
              record.status = "missing"
              record.save
              puts "missing: #{runid}"
            else
              record.status = "downloaded"
              record.save
              puts "downloaded: #{runid}"
            end
          rescue
            retry
          end
        end
      end
      
      puts "sleep 5sec: #{Time.now}"
      sleep 5
    end
  
  elsif ARGV.first == "--fastqc"
    loop do
      puts "begin fastqc process #{Time.now}"
      downloaded = SRAID.downloaded
      disk = ReportStat.diskusage
      while ReportStat.qstat < 500 && disk <= 10000000000000 && !downloaded.empty? 
        record = downloaded.shift
        qcp = QCprocess.new(record.runid)
        qcp.fastqc
        
        begin
          record.status = "done"
          record.save
          puts "submit fastqc for " + record.to_s
        rescue SQLite3::CantOpenException, SQLite3::BusyException, ActiveRecord::StatementInvalid => error
          puts error
          puts "retry after 5min..."
          sleep 300
          retry
        end
      end
      puts "sleep 3min: #{Time.now}"
      sleep 180
    end
  
  elsif ARGV.first == "--report"
    loop do
      puts "report #{Time.now}"
      diskusage = ReportStat.diskusage
      ftpsession = ReportStat.ftpsession
      qstat = ReportStat.qstat
      done = SRAID.done
      available = SRAID.available
      all = SRAID.all
      missyou = SRAID.missing.map{|r| r.runid }
      ReportTwitter.stat(diskusage, ftpsession, qstat)
      ReportTwitter.job(done, available, all)
      ReportTwitter.error(missyou)
      
      puts "DB updating #{Time.now}"
      SRAID.transaction do 
        missyou.each do |runid|
          record = SRAID.find_by_runid(runid)
          record.status = "reported"
          record.save
        end
      end
      puts "sleep 1hr: #{Time.now}"
      sleep 3600
    end
  end
end
