require "rake"
require "fileutils"

Basedir = "/home/inutano/project/ER"

def next_items(num)
  data_dir = Basedir + "/data"
  sra_files = Dir.glob(data_dir + "/*sra")
  sra_files.sort_by{|f| File.size(f) }.shift(num)
end

def fastq_dump(sra_file)
  cmd = ""
  cmd << "cd #{Basedir}/data && "
  cmd << "/home/inutano/local/bin/sratoolkit/fastq-dump --split-3 "
  cmd << sra_file
  sh cmd
  FileUtils.mv(Dir.glob(sra_file.gsub(/\.sra$/,"*.fastq")), Basedir + "/fastq")
  FileUtils.rm_f(sra_file)
  puts sra_file.split("/").last + " finished at " + Time.now.to_s
rescue RuntimeError
  FileUtils.mv(sra_file, Basedir + "/fqdumpfailed")
  puts sra_file.split("/").last + " ------FAILED------ " + Time.now.to_s
end

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
  qstat = "/home/geadmin/UGER/bin/lx-amd64/qstat | grep 'inutano' | wc -l"
  if `#{qstat}`.to_i > 4500
    puts "---- too many job! ----"
    while `#{qstat}`.to_i > 4500
      sleep 10
    end
    retry
  end
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
    ## Check disk availability
    if disk_full?
      puts "Disk quota nearly exceeded " + Time.now.to_s
      while disk_full?
        sleep 10
      end
    end
    
    ## Set number of parallel exec
    number_of_parallel = 8
    
    ## Check file to be unarchived
    ## .sra.lite
    srafiles = next_items(number_of_parallel).compact
    
    ## bunzip2
    bz2_list = bz2_order_by_size
    
    if srafiles.empty? && bz2_list.empty?
      puts "Sleep until new files come " + Time.now
      while srafiles.empty? && bz2_list.empty?
        sleep 10
        srafiles = next_items(number_of_parallel).compact
        bz2_list = bz2_order_by_size
      end
    end
    
    ## bunzip2 process
    if !bz2_list.empty?
      job_box = []
      bz2_list.each do |bz2|
        job_box << qsub_bunzip2(bz2)
      end
      puts job_box.length.to_s + " jobs submitted " + Time.now.to_s
      
      job_box.each do |job_name|
        while !job_finished?(job_name)
          sleep 10
        end
      end
    end
    
    ## .sra.lite process
    if !srafiles.empty?
      threads = []
      srafiles.each do |srafile|
        th = Thread.new do
          fastq_dump(srafile)
        end
        threads << th
      end
      threads.each{|th| th.join }
    end
  end
end
