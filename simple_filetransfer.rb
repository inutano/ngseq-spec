# -*- coding: utf-8 -*-

require "parallel"
require "fileutils"

BASE = "/home/inutano"
ACC = BASE + "/project/ER/table/SRA_Accessions.tab"

def get_fq(id)
  fq_awk = `awk -F '\t' '$1 ~ /^#{id}/ { printf "/" "%.6s" "/" $2 "/" $11, $2 }' #{ACC}`
  fq_path = BASE + "/data/fastq_data" + fq_awk
  if File.exist?(fq_path)
    fq = Dir.entries(fq_path).select{|n| n =~ /^#{id}/ }
    if !fq.empty?
      fq.map{|f| File.join(fq_path, f)}
    end
  end
end

def get_sra(id)
  sra_awk = `awk -F '\t' '$1 ~ /^#{id}/ { printf "/" "%.3s" "/" "%.6s" "/" $11 "/" $1, $11, $11 }' #{ACC}`
  sralite_path = BASE + "/data/litesra_data/ByExp/litesra" + sra_awk
  if File.exist?(sralite_path)
    sralite = Dir.entries(sralite_path).select{|n| n =~ /^#{id}/ }
    if !sralite.empty?
      sralite.map{|f| File.join(sralite_path, f)}
    end
  end
end

def conf_fpath(id)
  files = get_fq(id)
  if !files
    files = get_sra(id)
  end
  files
end

def disk_full?
  data_usage = `du /home/inutano/project/ER/data | cut -f 1`.chomp.to_i
  fastq_usage = `du /home/inutano/project/ER/fastq | cut -f 1`.chomp.to_i
  disk_usage = data_usage + fastq_usage
  if data_usage > 20_000_000_000 or disk_usage > 40_000_000_000
    true
  end
end

if __FILE__ == $0
  download_dir = BASE + "/project/ER/download"
  download_log = BASE + "/project/ER/table/download_log"
  download_notfound = BASE + "/project/ER/table/download_notfound"
  data_dir = BASE + "/project/ER/data"

  filelist_path = ARGV.first || BASE + "/project/ER/table/filelist"
  filelist = open(filelist_path).readlines
  
  progress = 0
  while !filelist.empty?
    if disk_full?
      puts "disk quota nearly exceeded. Type 'continue' to restart"
      str = ""
      while str != "continue"
        str = gets.chomp
      end
    end

    download = []
    no_file = []
    filelist.shift(25).each do |id_n|
      id = id_n.chomp
      fa = conf_fpath(id)
      if fa
        download << fa
      else
        no_file << id
      end
    end
    
    threads = []
    download.flatten.each do |file|
      fname = file.split("/").last
      th = Thread.new do
        FileUtils.cp(file, download_dir)
        FileUtils.mv(File.join(download_dir, fname), data_dir)
        open(download_log,"a"){|f| f.puts(fname) }
      end
      threads << th
    end
    threads.each{|th| th.join }
    
    open(download_notfound,"a"){|f| f.puts(no_file) }
    progress += 25
    puts "#{Time.now}\t" + progress.to_s + " files transferred"    
  end
end
