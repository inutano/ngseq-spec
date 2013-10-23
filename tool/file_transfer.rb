# -*- coding: utf-8 -*-

require "fileutils"

BASE = "/home/inutano"

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
      puts "Disk quota nearly exceeded: sleep until anyone is out " + Time.now.to_s
      while disk_full?
        sleep 10
      end
    end
    
    download = filelist.shift(25).map{|l| l.chomp }
    
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
    
    progress += 25
    puts "#{Time.now}\t" + progress.to_s + " files transferred, " + filelist.size.to_s + " files left"
  end
end
