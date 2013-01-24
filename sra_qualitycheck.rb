# -*- coding: utf-8 -*-
# status code:
# available: 1, controlled: 2, done: 3, missing: 4

require "groonga"
require "yaml"
require "fileutils"

require "ap"

def mess(message)
  puts Time.now.to_s + "\t" + message
end

class Filecheck
  @@base_path = "/usr/local/ftp/ddbj_database/dra/fastq"

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
  qub = config["qsub_path"]
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
    
    #loop do
    20.times do
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
          # done
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
      data_path = config["data_path"]
      to_be_processed = Dir.entries(data_path).select{|f| f =~ /^.RR/ }
    
      to_be_processed.each do |file|
        runid = file.slice(0..8)
        fpath = File.join(data_path, file)
        running_fastqc(runid, fpath, config_path)
      end
    
  when "--validate"
    db = Groonga["SRAIDs"]
  
  when "--debug"
    db = Groonga["SRAIDs"]
    
    #array = (367..371).to_a.map{|n| "DRR" + "%06d" % n }
    array = open("./list").readlines
    array.each do |id|
      rec = db[id.chomp]
      rec.status = 1
      ap rec.key
      ap rec.status
    end

    ap "available: " + db.select{|r| r.status == 1 }.size.to_s
    ap "controlled: " + db.select{|r| r.status == 2 }.size.to_s
    ap "downloaded: " + db.select{|r| r.status == 3 }.size.to_s
    ap "missing: " + db.select{|r| r.status == 4 }.size.to_s
  end
end
