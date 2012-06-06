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

def get_litesra(runid, expid)
  db_head = expid.slice(0,3)
  exp_head = expid.slice(0,6)
  dir = "/usr/local/ftp/ddbj_database/sralite/ByExp/litesra/#{db_head}/#{exp_head}/#{expid}"
  file = "#{dir}/#{runid}.lite.sra"
  dest = "/home/inutano/project/sra_qualitycheck/litesra"
  if File.exist?(file)
    FileUtils.cp(file, dest)
  else
    log = dest = "/missing.idlist"
    open(log,"a"){|f| f.puts(runid) }
  end
end

def unarchive
  pdir = "/home/inutano/project/sra_qualitycheck"
  dir = pdir + "/litesra"
  files = Dir.glob("#{dir}/*.litesra")
  files.each do |file|
    file =~ /^.+(\wRR\d{6}).+$/
    runid = $1
    id_head = runid.slice(0,6)
    log_dir = pdir + "/log/" + id_head
    FileUtils.mkdir(log_dir) if not File.exist?(log_dir)
    log = log_dir + "/litesra_#{runid}_#{Time.now.strftime("%m%d%H%M%S")}.log"
    `/home/geadmin/UGER/bin/lx-amd64/qsub -N #{runid} -o #{log} ./litesra_unarchive.sh #{file}`
  end
end

if __FILE__ == $0
  # connect to db
  ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database => "./production.sqlite3"
  )
  logfile = "/home/inutano/project/sra_qualitycheck/log/database.log"
  ActiveRecord::Base.logger = Logger.new(logfile)
  
  # get no fq but compressed
  loop do
    missing = SRAID.where(:status => "missing").limit(16)
    threads = []
    missing.each do |record|
      runid = record.runid
      expid = record.expid
      th = Thread.new do
        get_litesra(runid, expid)
        puts "copying " + runid
      end
      threads << th
    end
    threads.each do |th|
      th.join
    end
  
    puts "sleep 5sec #{Time.now}" 
    sleep 5
  
    # unarchiving (run sh)
    unarchive
    
    puts "sleep 5sec #{Time.now}"
    sleep 5
  end
end
