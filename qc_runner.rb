# -*- coding: utf-8 -*-

require "yaml"
require "active_record"
require "logger"
require "twitter"

require "./lib/sraid"
require "./lib/qc_process"
require "./lib/report_tw"

path = YAML.load_file("./lib/config.yaml")["path"]

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => path["lib"] + "/production.sqlite3",
  :timeout => 10000
)

ActiveRecord::Base.logger = Logger.new(path["log"] + "/database.log")

if __FILE__ == $0
  if ARGV.first == "--transmit"
    puts "reading id convert table.."
    accessions = open(path["lib"] + "/SRA_Accessions.tab").readlines
    run_members = open(path["lib"] + "/SRA_Run_Members.tab").readlines
    loop do
      puts "transmittion start #{Time.now}"
      available = SRAID.available.map{|r| r.runid }
      diskusage = ReportStat.diskusage.to_i
      session = ReportStat.ftpsession
      while diskusage <= 60 && session <= 8
        runid = available.shift
        qcp = QCprocess.new(runid)
        location = qcp.ftp_location(accessions, run_members)
        Thread.fork do
          qcp.gwt_fq(location)
          log = Dir.glob(path["log"] + "/lftp_#{@run_id}*.log").sort.last
            if (log && open(log).read =~ /fail/)
              record = SRAID.find_by_runid(runid)
              record.status = "missing"
              record.save
              puts record.to_s
            else
              record = SRAID.find_by_runid(runid)
              record.status = "downloaded"
              record.save
              puts record.to_s
            end
        end
      end
      puts "sleep 3min: #{Time.now}"
      sleep 180
    end
  
  elsif ARGV.first == "--fastqc"
    puts Time.now
    loop do
      downloaded = SRAID.downloaded.map{|r| r.runid }
      while diskusage <= 60 && !downloaded.empty?
        runid = downloaded.shift
        qcp = QCprocess.new(runid)
        qcp.fastqc
        
        record = SRAID.find_by_runid(runid)
        record.status = "done"
        record.save
        puts "submit fastqc for " + record.to_s
      end
      puts "sleep 5min: #{Time.now}"
      sleep 300
    end
  
  elsif ARGV.first == "--report"
    loop do
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
      missyou.each do |runid|
        record = SRAID.find_by_runid(runid)
        record.status = "reported"
        record.save
      end
      puts "sleep 30min: #{Time.now}"
      sleep 1800
    end
  end
end
