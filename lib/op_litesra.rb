# -*- coding: utf-8 -*-

require "active_record"
require "logger"
require "fileutils"
require "ap"

class SRAID < ActiveRecord::Base
  def to_s
    "#{runid},  status => #{status}, paper => #{paper}"
  end
end

def litesra_path(runid, expid)
  db_head = expid.slice(0,3)
  exp_head = expid.slice(0,6)
  dir_head = "/usr/local/ftp/ddbj_database/dra/sralite/ByExp/litesra"
  "#{dir_head}/#{db_head}/#{exp_head}/#{expid}/#{runid}/#{runid}.lite.sra"
end

def get_litesra(fpath)
  dest = "/home/inutano/project/sra_qualitycheck/litesra"
  FileUtils.cp(fpath, dest)
end

def unarchive(runid)
  pdir = "/home/inutano/project/sra_qualitycheck"
  file = "#{pdir}/litesra/#{runid}.lite.sra"
  if File.exist?(file)
    log_dir = pdir + "/log/" + runid.slice(0,6)
    FileUtils.mkdir(log_dir) unless File.exist?(log_dir)
    log = log_dir + "/litesra_#{runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `/home/geadmin/UGER/bin/lx-amd64/qsub -N "dump.#{runid}" -o #{log} ./litesra_unarchive.sh #{runid}`
    puts "unarchive: #{runid}"
  end
end

if __FILE__ == $0
  # connect to db
  ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database => "./production.sqlite3"
  )
  db_log = "/home/inutano/project/sra_qualitycheck/log/database.log"
  ActiveRecord::Base.logger = Logger.new(db_log)
  
  # get no fq but compressed
  loop do
    missing = SRAID.where(:status => "missing").limit(16)
    threads = []
    missing.each do |record|
      runid = record.runid
      expid = record.expid
      fpath = litesra_path(runid, expid)
      puts fpath
      if File.exist?(fpath)
        th = Thread.new do
          get_litesra(fpath)
        end
        threads << th
        puts "copying: " + runid
      else
        record.status = "reported"
        record.save
        puts "reported as file not found: " + runid
      end
    end
    
    threads.each do |th|
      th.join
    end
    
    # unarchiving (run sh)
    puts "unarchiving.. #{Time.now}"
    transferred = missing.map{|record| record.runid }
    transferred.each do |runid|
      unarchive(runid)
      record = SRAID.find_by_runid(runid)
      record.status = "unarchiving"
      record.save
    end
    
    # status changing
    puts "changing file status.. #{Time.now}"
    data_dir = "/home/inutano/project/sra_qualitycheck/data"
    ids = Dir.glob("#{data_dir}/*.fastq").map{|f| f.slice(44,9)}.uniq
    ids.each do |runid|
      begin
        record = SRAID.find_by_runid(runid)
        if record.status == "unarchiving"
          record.status = "downloaded"
          record.save
          puts "downloaded: " + runid
        end
      rescue
        sleep 5
        retry
      end
    end
    
    puts "sleep 5sec #{Time.now}"
    sleep 5
  end
end
