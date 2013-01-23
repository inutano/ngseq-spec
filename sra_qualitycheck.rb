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
    @@data_dir = config["data_dir"]
  end
  
  def self.each(fpath_array)
    threads = []
    fpath_array.each do |id_fpath|
      runid = id_fpath[:runid]
      fpath = id_fpath[:fpath]
      
      th = Thread.new do
        files = Dir.entries(fpath).select{|f| f =~ /^#{runid}/ }.map{|fq| File.join(fpath, fq) }
        
        ap files
        
        FileUtils.cp(files, @@data_dir)
      end
      
      ap th
      
      threads << th
    end
    mess "copying.."
    threads.each{|th| th.join }
  end
end

if __FILE__ == $0
  config_path = File.join(File.expand_path(File.dirname(__FILE__)), "lib", "config.yaml")
  config = YAML.load_file(config_path)
  
  Groonga::Context.default_options = { encoding: :utf8 }
  Groonga::Database.open(config["db_path"])
  
  case ARGV.first
  when "--transfer"
    db = Groonga["SRAIDs"]
#    loop do
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
        
        ap files
        
        path = fc.fpath
        
        ap path
        
        { record: record, files: files, path: path }
      end

      file_notfound = file_status.select{|h| !h[:files] }.map{|h| h[:record] }
      file_notfound.each do |record|
        # file not found => missing
        
        record.status = 4

        ap "file not found"
        ap record.key.key
        ap record.status
      end
      
      ap file_status
      
      file_exist = file_status.select{|h| h[:files] }
      
      ap file_exist
      
      fpath_array = file_exist.map do |hash|
        { runid: hash[:record].key.key,
          fpath: hash[:path] }
      end
      
      ap fpath_array
      
      Ptransfer.load_files(config_path)
      Ptransfer.each(fpath_array)
      
      data_dir = config["data_dir"]
      files_downloaded = Dir.entries(data_dir)
      
      ap files_downloaded.sort_by{|f| f }
      
      file_exist.each do |hash|
        id = hash[:record].key.key
        ap id 
        if files_downloaded.select{|f| f =~ /#{id}/ }.empty?
          # failed to download => missing
          
          ap "failed"
          ap hash[:files]
          
          hash[:record].status = 4
        else
          # done
          
          ap "downloaded"
          ap hash[:files]
          
          hash[:record].status = 3
        end
      end
#    end

  when "--fastqc"
  
  when "--debug"
    db = Groonga["SRAIDs"]
    
    #array = (367..371).to_a.map{|n| "DRR" + "%06d" % n }
    array = []
    array.each do |id|
      rec = db[id]
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
