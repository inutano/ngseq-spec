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
    @runid = record.runid
    @subid = record.subid
    @expid = record.expid
    @fpath = File.join(@@base_path, @subid.slice(0..5), @subid, @expid)
  end
  attr_reader :fpath
  
  def files
    if File.exist?(@fpath)
      flist = !Dir.entries(@fpath).select{|f| f =~ /#{@runid}/ }
      flist if !flist.empty?
    end
  end
end

class Ptransfer
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    @@base_path = config["dra_fq_path"]
    @@data_dir = config["data_dir"]
  end
  
  def self.each(fpath_array)
    threads = []
    fpath_array.each do |fpath|
      th = Thread.new do
        files = Dir.entries(fpath).select{|f| f =~ /^#{runid}/ }.map{|fq| File.join(fpath, fq)}
        FileUtils.cp(files, data_dir)
      end
      threads << th
    end
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
      
      ap to_be_processed

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
      
      file_notfound = file_status.delete_if{|h| h[:files] }.map{|h| h[:record] }
      file_notfound.each do |record|
        # file not found => missing
        
        ap "file not found"
        ap record.runid
        
        record.status = 4
      end
      
      file_exist = file_status.select{|h| h[:files] }
      
      ap file_exist
      
      fpath_array = file_exist.map{|h| h[:path] }
      
      ap fpath_array
      
      Ptransfer.each(fpath_array)
      
      data_dir = config["data_dir"]
      files_downloaded = Dir.entries(data_dir)
      
      ap files_downloaded
      
      file_exist.each do |hash|
        id = hash[:record].runid
        if files_downloaded.select{|f| f =~ /#{id}/}.empty?
          # failed to download => missing
          
          ap "downloaded " + hash[:files]
          
          hash[:record].status = 4
        else
          # done
          
          ap "missing or failed " + hash[:files]
          
          hash[:record].status = 3
        end
      end
#    end

  when "--fastqc"
  end
end
