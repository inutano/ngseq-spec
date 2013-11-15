# -*- coding: utf-8 -*-

task :default => :about

namespace :dataset do
  desc "retrieve dataset from NCBI"
  task :get => ["SRA_Accessions.tab","SRA_Run_Members.tab","taxon_table.csv"]
  
  directory "data"
  ts = Time.now.strftime("%Y%m%d-%H&M")
  
  desc "Download SRA metadata table"
  rule %r{SRA.+\.tab} => "data" do |t|
    fpath = File.join("data", t.name)
    if File.exist? fpath
      mv fpath fpath + "." + ts
    end
    base_url = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
    sh "lftp -c \"open #{base_url} && pget -n 8 #{t.name}\""
    mv t.name, "data"
  end
  
  desc "Download taxonomy id <=> scientific name table"
  file "taxon_table.csv" => "data" do |t|
    fpath = File.join("data", t.name)
    if File.exist? fpath
      mv fpath fpath + "." + ts
    end
    
    base_url = "ftp.ncbi.nlm.nih.gov/pub/taxonomy"
    sh "lftp -c \"open #{base_utl} && pget -n 8 taxdump.tar.gz\""
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

task :about do
  puts "Rake to set up required datasets"
end
