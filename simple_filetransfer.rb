# -*- coding: utf-8 -*-

require "parallel"
require "fileutils"

if __FILE__ == $0
  BASE = "/home/inutano"
  accessions = BASE + "/project/ER/table/SRA_Accessions.tab"
  run_members = BASE + "/project/ER/table/SRA_Run_Members.tab"
  fq_base = BASE + "/data/fastq_data"
  sralite_base = BASE + "/data/litesra_data/ByExp/litesra"
  
  download_dir = BASE + "/project/ER/download"
  download_log = BASE + "/project/ER/table/download_log"
  download_notfound = BASE + "/project/ER/table/download_notfound"
  data_dir = BASE + "/project/ER/data"
  
  filelist = open(BASE + "/project/ER/table/filelist").readlines
  
  progress = 0
  while !filelist.empty?
    filepath = Parallel.map(filelist.shift(25)) do |id_n|
      id = id_n.chomp
      fq_path = fq_base + `awk -F '\t' '$1 ~ /^#{id}/ { printf "/" "%.6s" "/" $2 "/" $11, $2 }' #{accessions}`
      sralite_path = sralite_base + `awk -F '\t' '$1 ~ /^#{id}/ { printf "/" "%.3s" "/" "%.6s" "/" $11 "/" $1, $11, $11 }' #{accessions}`
      [id, fq_path, sralite_path]
    end
    
    download = []
    no_file = []
    
    filepath.each do |fpath_a|
      id = fpath_a[0]
      fq_path = fpath_a[1]
      sralite_path = fpath_a[2]
      
      if File.exist?(fq_path)
        fq = Dir.entries(fq_path).select{|n| n =~ /^#{id}/ }
        if !fq.empty?
          download << fq.map{|f| File.join(fq_path, f) }
        else
          if File.exist?(sralite_path)
            sralite = Dir.entries(sralite_path).select{|n| n =~ /^#{id}/ }
            if !sralite.empty?
              download << sralite.map{|f| File.join(sralite_path, f) }
            else
              no_file << id
            end
          else
            no_file << id
          end
        end
      elsif File.exist?(sralite_path)
        sralite = Dir.entries(sralite_path).select{|n| n =~ /^#{id}/ }
        if !sralite.empty?
          download << sralite.map{|f| File.join(sralite_path, f) }
        else
          no_file << id
        end
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
