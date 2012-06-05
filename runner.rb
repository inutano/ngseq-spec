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
      available = SRAID.available[0..50]
      threads = []
      executed = []
      
      diskstat = ReportStat.diskusage <= 10_000_000_000_000_000
      ftpsession = ReportStat.ftpsession <= 16
      liststat = !available.empty?
      
      while diskstat && ftpsession && liststat
        record = available.shift
        runid = record.runid
        qcp = QCprocess.new(runid)
        
        th = Thread.new do
          subid = record.subid
          expid = record.expid
          qcp.get_fq_local(subid, expid)
        end
        
        threads << th
        executed << runid
        
        diskstat = ReportStat.diskusage <= 10_000_000_000_000_000
        ftpsession = ReportStat.ftpsession <= 16
        liststat = !available.empty?
      end
      
      begin
        SRAID.transaction do
          executed.each do |runid|
            record = SRAID.find_by_runid(runid)
            record.status = "ongoing"
            record.save
            puts record.to_s
          end
        end
      rescue SQLite3::CantOpenException, SQLite3::BusyException, ActiveRecord::StatementInvalid => error
        puts error
        puts "retry after 5min..."
        sleep 300
        retry
      end
      
      puts "waiting for forked processes to complete: #{Time.now}"
      threads.each do |th|
        th.join
      end
      
      begin
        executed.each do |runid|
          record = SRAID.find_by_runid(runid)
          qcp = QCprocess.new(runid)
          ftpstat = qcp.ftp_failed?
          if ftpstat
            record.status = "missing"
            record.save
            puts record.to_s
          else
            record.status = "downloaded"
            record.save
            puts record.to_s
          end
        end
      rescue SQLite3::CantOpenException, SQLite3::BusyException, ActiveRecord::StatementInvalid => error
        puts error
        puts "retry after 5min..."
        sleep 300
        retry
      end
      
      puts "sleep 30sec: #{Time.now}"
      sleep 30
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
