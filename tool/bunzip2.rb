# -*- coding: utf-8 -*-

require "rake"
require "fileutils"

Basedir = "/home/inutano/project/ER"

def bz2_order_by_size
  data_dir = Basedir + "/data"
  bz2_files = Dir.glob(data_dir + "/*bz2")
  bz2_files.sort_by{|f| File.size(f) }
end

def qsub_bunzip2(bz2)
  job_name = bz2.split("/").last.slice(0..8) + "B"
  script_path = Basedir + "/tool/bunzip2.sh"
  qsub = "qsub -N #{job_name} #{script_path} #{bz2}"
  sh qsub
  job_name
rescue RuntimeError
  puts "------ qsub command caused an error for #{bz2} " + Time.now.to_s
  exit
end

def job_finished?(job_name)
  stat = `/home/geadmin/UGER/bin/lx-amd64/qstat | awk '$1 ~ /^[0-9]/ { print $3 }'`
  !stat.split("\n").include?(job_name)
end

def disk_full?
  data_usage = `du /home/inutano/project/ER/data | cut -f 1`.chomp.to_i
  fastq_usage = `du /home/inutano/project/ER/fastq | cut -f 1`.chomp.to_i
  disk_usage = data_usage + fastq_usage
  if fastq_usage > 20_000_000_000 or disk_usage > 40_000_000_000
    true
  end
end

if __FILE__ == $0
  while true
    # anytime disk full
    if disk_full?
      puts "Disk quota nearly exceeded: sleep until anyone is out " + Time.now.to_s
      while disk_full?
        sleep 10
      end
    end
    
    bz2_list = bz2_order_by_size
    
    # no file to dump
    if bz2_list.empty?
      puts "No file to be processed: sleep until new guys are coming " + Time.now.to_s
      while bz2_list.empty?
        sleep 10
        bz2_list = bz2_order_by_size
      end
    end
    
    # job submission
    job_box = []
    bz2_list.each do |bz2|
      job_box << qsub_bunzip2(bz2)
    end
    puts job_box.length.to_s + " jobs submitted " + Time.now.to_s
    
    # waiting for submitted job to finish
    job_box.each do |job_name|
      while !job_finished?(job_name)
        sleep 10
      end
    end
  end
end
