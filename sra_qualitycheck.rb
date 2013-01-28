# -*- coding: utf-8 -*-
# record status:
# available: 1, controlled 2, downloaded 3, missing 4, processing 5, done 6

require "groonga"
require "yaml"
require "fileutils"

require "ap"

def mess(message)
  puts Time.now.to_s + "\t" + message
end

class Filecheck
  @@base_path = "/usr/local/ftp/ddbj_database/dra/fastq"
  @@base_sra_path = "/usr/local/ftp/ddbj_database/dra/sralite/ByExp/litesra"

  def initialize(record)
    @runid = record.key.key
    @subid = record.subid
    @expid = record.expid
    @fpath = File.join(@@base_path, @subid.slice(0..5), @subid, @expid)
  end
  attr_reader :fpath
  
  def files
    if File.exist?(@fpath)
      flist = Dir.entries(@fpath).select{|f| f =~ /#{@runid}/ }
      flist if !flist.empty?
    end
  end
  
  def fpath_sra
    db_head = @expid.slice(0..2)
    exp_head = @expid.slice(0..5)
    File.join(@@base_sra_path, db_head, exp_head, @expid, @runid)
  end
  
  def files_sra
    if File.exist?(self.fpath_sra)
      flist = Dir.entries(self.fpath_sra).select{|f| f =~ /#{@runid}/ }
      flist if !flist.empty?
    end
  end
end

class Ptransfer
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    @@download = config["download_path"]
    @@data = config["data_path"]
  end
  
  def self.each(hash_array)
    threads = []
    hash_array.each do |hash|
      runid = hash[:record].key.key
      fpath = hash[:fpath]
      
      th = Thread.new do
        files = Dir.entries(fpath).select{|f| f =~ /^#{runid}/ }.map{|fq| File.join(fpath, fq) }
        FileUtils.cp(files, @@download)
      end

      threads << th
    end
    mess "copying.."
    threads.each{|th| th.join }
  end
  
  def self.flush
   downloaded = Dir.entries(@@download).select{|f| f !~ /^\./ }
   files = downloaded.map{|f| File.join(@@download, f) }
   FileUtils.mv(files, @@data)
  end
end

def running_fastqc(runid, fpath, config_path)
  config = YAML.load_file(config_path)
  log = File.join(config["log_path"], runid + "_fastqc_#{Time.now.strftime("%m%d%H%M%S")}")
  qsub = config["qsub_path"]
  lib_path = config["lib_path"]
  `#{qsub} -N #{runid} -o #{log} #{lib_path}/fastqc.sh #{runid} #{fpath} #{config_path}`
end

if __FILE__ == $0
  config_path = File.join(File.expand_path(File.dirname(__FILE__)), "lib", "config.yaml")
  config = YAML.load_file(config_path)
  
  Groonga::Context.default_options = { encoding: :utf8 }
  Groonga::Database.open(config["db_path"])
  
  case ARGV.first
  when "--transfer"
    db = Groonga["SRAIDs"]
    
    loop do
      mess "begin transmission"
      available = db.select{|r| r.status == 1 }.map{|r| r }
      to_be_processed = available[0..15]
      
      if to_be_processed.empty?
        mess "all available entries calcurated!"
        exit
      end
      
      file_status = to_be_processed.map do |record|
        fc = Filecheck.new(record)
        files = fc.files
        fpath = fc.fpath
        { record: record, files: files, fpath: fpath }
      end

      file_notfound = file_status.select{|h| !h[:files] }
      file_notfound.each do |hash|
        # file not found => missing 4
        record = hash[:record]
        record.status = 4
        mess "file not found: #{hash[:record].key.key} at #{hash[:fpath]}"
      end
      
      file_exist = file_status.select{|h| h[:files] }
      
      Ptransfer.load_files(config_path)
      Ptransfer.each(file_exist)
      
      download_path = config["download_path"]
      files_downloaded = Dir.entries(download_path)
      
      file_exist.each do |hash|
        id = hash[:record].key.key
        if files_downloaded.select{|f| f =~ /#{id}/ }.empty?
          # failed to download => missing
          hash[:record].status = 4
          mess "download failed: #{hash[:record].key.key} at #{hash[:fpath]}"
        else
          # downloaded
          hash[:record].status = 3
          mess "success! #{hash[:record].key.key}"
        end
      end
      
      Ptransfer.flush
      
      mess "sleep 10sec"
      sleep 10
    end

  when "--transfer-sra"
    db = Groonga["SRAIDs"]
    
    loop do
      mess "begin transmission"
      missing = db.select{|r| r.status == 4 }.map{|r| r }
      to_be_processed = missing[0..15]
      
      if to_be_processed.empty?
        mess "all missing entries calcurated!"
        exit
      end
      
      file_status = to_be_processed.map do |record|
        fc = Filecheck.new(record)
        files = fc.files_sra
        fpath = fc.fpath_sra
        { record: record, files: files, fpath: fpath }
      end

      file_notfound = file_status.select{|h| !h[:files] }
      file_notfound.each do |hash|
        # file not found again => lost 7
        record = hash[:record]
        record.status = 7
        mess "lite.sra file not found: #{hash[:record].key.key} at #{hash[:fpath]}"
      end
      
      file_exist = file_status.select{|h| h[:files] }
      
      Ptransfer.load_files(config_path)
      Ptransfer.each(file_exist)
      
      download_path = config["download_path"]
      files_downloaded = Dir.entries(download_path)
      
      file_exist.each do |hash|
        id = hash[:record].key.key
        if files_downloaded.select{|f| f =~ /#{id}/ }.empty?
          # failed to download => lost 7
          hash[:record].status = 7
          mess "download failed: #{hash[:record].key.key} at #{hash[:fpath]}"
        else
          # downloaded
          hash[:record].status = 3
          mess "success! #{hash[:record].key.key}"
        end
      end
      
      Ptransfer.flush
      
      mess "sleep 10sec"
      sleep 10
    end

  when "--fastqc"
    loop do
      db = Groonga["SRAIDs"]
      data_path = config["data_path"]
      
      to_be_processed = Dir.entries(data_path).select do |file|
        runid = file.slice(0..8)
        record = db[runid]
        if record
          record.status != 5
        end
      end
      
      to_be_processed.each do |file|
        runid = file.slice(0..8)
        fpath = File.join(data_path, file)
        running_fastqc(runid, fpath, config_path)
        mess "running fastqc, #{runid} at #{fpath}"
        record = db[runid]
        record.status = 5
      end
      
      mess "finish throwing jobs, sleep 10sec"
      sleep 10
    end
    
  when "--validate"
    db = Groonga["SRAIDs"]
    qc_processed = db.select{|record| record.status == 5 }
    
    qc_processed.each do |record|
      runid = record.key.key
      zip_path = File.join(config["result_path"], runid.slice(0..5), runid)
      if !File.exist?(zip_path)
        ap "file not found"
        ap zip_path
      end
    end
  
  when "--debug"
    db = Groonga["SRAIDs"]
    
    #array = (367..371).to_a.map{|n| "DRR" + "%06d" % n }
    #array = open("./list").readlines
    #array = open("./error_list").readlines
    #array = open("./list2").readlines
    #array = db.select{|rec| rec.status == 5 }
    #array = Dir.glob("./data/*.fastq.bz2")
    array = []
    array.each do |node|
      #id = node.gsub(/^\.\/data\//,"").gsub(/\.fastq\.bz2$/,"").gsub(/_.$/,"") 
      #record = db[id]
      #record = db[node.chomp]
      #record.status = 3
      #record.status = 1
      #record.status = 6
      #ap node.key.key
      #node.status = 6
      #ap record.status
    end
    
    ap "available: " + db.select{|r| r.status == 1 }.size.to_s
    ap "controlled: " + db.select{|r| r.status == 2 }.size.to_s
    ap "downloaded: " + db.select{|r| r.status == 3 }.size.to_s
    ap "missing: " + db.select{|r| r.status == 4 }.size.to_s
    ap "processing: " + db.select{|r| r.status == 5 }.size.to_s
    ap "done: " + db.select{|r| r.status == 6 }.size.to_s
    ap "lost: " + db.select{|r| r.status == 7 }.size.to_s
  end
end
 
