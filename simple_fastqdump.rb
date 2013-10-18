# -*- coding: utf-8 -*-

require "rake"
require "fileutils"

Basedir = "/home/inutano/project/ER"

def smallest_3
  data_dir = Basedir + "/data"
  sra_files = Dir.glob(data_dir + "/*sra")
  sra_files.sort_by{|f| File.size(f) }.shift(3)
end

def fastq_dump(sra_file)
  fqd = "/home/inutano/local/bin/sratoolkit/fastq-dump --split-3 "
  sh fqd + sra_file
  FileUtils.mv(Dir.glob(sra_file.gsub(/\.sra$/,"*.fastq")), Basedir + "/fastq")
  FileUtils.rm_f(sra_file)
  puts sra_file.split("/").last + " finished at " + Time.now.to_s
rescue RuntimeError
  FileUtils.mv(sra_file, Basedir + "fqdumpfailed")
  puts sra_file.split("/").last + " ------FAILED------ " + Time.now.to_s
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
  while true do
    # anytime disk full
    if disk_full?
      puts "Disk quota nearly exceeded: sleep until anyone is out " + Time.now.to_s
      while disk_full?
        sleep 10
      end
    end

    # 3 is always a right number
    srafiles = smallest_3.compact

    # no file to dump
    if srafiles.empty?
      puts "No file to dump: sleep until new guys are coming " + Time.now.to_s
      while srafiles.empty?
        sleep 10
      end
    end
    
    # start processing
    threads = []
    srafiles.each do |srafile|
      th = Thread.new do
        fastq_dump(sra_file)
      end
    end
    threads.each{|th| th.join }
  end
end
