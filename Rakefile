# -*- coding: utf-8 -*-

task :default => :about

ts = Time.now.strftime("%Y%m%d-%H&M")

namespace :dataset do
  desc "retrieve dataset from NCBI"
  task :retrieve => ["SRA_Accessions.tab","SRA_Run_Members.tab","taxon_table.csv"]
  
  directory "data"
  
  desc "Download SRA metadata table"
  rule %r{SRA.+\.tab} => "data" do |t|
    if File.exist? File.join("data", t.name)
      mv File.join("data", t.name), File.join("data", t.name + ts)
    end
    base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
    sh "lftp -c \"open #{base_url} && pget -n 8 #{t.name}\""
    mv t.name, "data"
  end
  
  desc "Download taxonomy id <=> scientific name table"
  file "taxon_table.csv" => "data" do |t|
    if File.exist? File.join("data", t.name)
      mv File.join("data", t.name), File.join("data", t.name + ts)
    end
    
    base_url = "ftp.ncbi.nlm.nih.gov/pub/taxonomy"
    sh "lftp -c \"open #{base_url} && pget -n 8 taxdump.tar.gz\""
    sh "tar zxf taxdump.tar.gz"
    
    file = `grep "scientific" names.dmp`.gsub("|","\t").gsub(/\t+/,",").split("\n")
    array = file.map{|l| l.split(",")[0..1].join(",") }
    open(t.name,"w"){|f| f.puts(array) }
    mv t.name, "data"
    rm FileList["*.dmp"]
    rm "gc.prt"
    rm "readme.txt"
    rm "taxdump.tar.gz"
  end
end

namespace :metadata do
  tar = "NCBI_SRA_Metadata_Full_#{Time.now.strftime("%Y%m")}01.tar.gz"
  desc "retrieve metadata tarball from NCBI"
  task :retrieve => tar
  
  directory "data"
  
  desc "Download and decompress sra metadata"
  file tar => "data" do |t|
    unless File.exist? File.join("data", t.name)
      base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
      sh "lftp -c \"open #{base_url} && pget -n 8 #{t.name}\""
      sh "tar zxf #{t.name}"
      
      data_dir = tar.gsub(/\.tar\.gz$/, "")
      mv data_dir, "data"
      
      sh "ln -sf #{data_dir} data/sra_metadata"
      rm tar
      
      origin_dirs = Dir.entries("data").select{|f| f =~ /^.RA\d{6}$/ }
      prefix = origin_dirs.map{|f| f.slice(0,6) }.uniq
      prefix.each do |p|
        moveto = File.join("data", p)
        directory File.join("data", p)
        mv File.join("data", )
      end
    end
  end
end

task :about do
  puts "Rake to set up required datasets"
end
