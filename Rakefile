task :default => :about

namespace :qc do
  desc "Make required directories"
  directory "download" "fq" "qc"
  
  desc "Download raw sequence file from SRA repository"
  task :download => "download "do
    ruby("lib/ngseq-spec/file-transfer.rb")
  end
  
  desc "Unarchive raw sequence file"
  task :unarchive => "fq" do
    ruby("lib/ngseq-spec/unarchive.rb")
  end
  
  desc "Exec FastQC to obtained data sets"
  task :fastqc => "qc" do
    ruby("lib/ngseq-spec/fastqc.rb")
  end
  
  desc "Move result file to archive directory and flush"
  task :flush do
    ruby("lib/ngseq-spec/flush.rb")
  end
end

namespace :seqspec do
  desc "Unzip QC data"
  task :unzip do
  end
  
  desc "Parse QC data and round values"
  task :parse do
  end
  
  desc "Parse metadata and create annotation data"
  task :annotate do
  end
  
  desc "Merge QC data and annotation"
  task :merge do
  end
end

namespace :mdata do
  desc "Update required metadata"
  task :retrieve do
  end
end

task :about do
  str = <<-EOF
    \# List of namespaces:
    qc:      generate qc data
    mdata:   retrieve or update metadata
    seqspec: summarise and annotate qc data
    
    see more details by rake -T
    
    \# Metadata files are required to be updated
    rake mdata:update   \# Download SRA metadata files and the other required files to 'mdata' directory
    
    \# To Generate QC data, run
    rake qc:download    \# Download qc data to 'download' folder
    rake qc:unarchive   \# Unarchive all data in download folder and move to 'fq' folder
    rake qc:fastqc      \# Execute FastQC to all data in fq folder
    rake qc:flush       \# Move FastQC data file from fq to fastqc directory, remove failed data
    
    \# To make summarised and annotated qc data, run
    rake seqspec:run    \# Run unzip, parse, annotate and merge to create summarised data
  EOF
  puts str
end


=begin
namespace :dataset do
  desc "retrieve dataset from NCBI"
  task :retrieve => ["SRA_Accessions.tab","SRA_Run_Members.tab","taxon_table.csv","sp_gsize.tab"]
  
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
  
  desc "Download taxonomy ID <=> estimated genome size table"
  file "sp_gsize.tab" => "data" do |t|
    fpath = File.join("data", t.name)
    if File.exist? fpath
      mv fpath, File.join("data", t.name + ts)
    end
    base_url = "ftp://ftp.ncbi.nlm.nih.gov/genomes/GENOME_REPORTS"
    sh "lftp -c \"open #{base_url} && pget -n 8 overview.txt\""
    sh "awk -F '\t' '$5 !~ \"-\" { print $1 \"\t\" $5 }' overview.txt > #{fpath}"
    rm "overview.txt"
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
    end
  end
  
  desc "rearrange directories in sra_metadata"
  task :rearrange do
    md_dir = "./data/sra_metadata"
    origin_dirs = Dir.entries(md_dir).select{|f| f =~ /^.RA\d{6}$/ }
    prefix = origin_dirs.map{|f| f.slice(0,6) }.uniq
    prefix.each do |p|
      moveto = File.join(md_dir, p)
      files = origin_dirs.map{|f| "#{md_dir}/#{f}" if f =~ /^#{p}/ }.compact
      mkdir moveto
      mv files, moveto
    end
  end
end

task :about do
  puts "Rake to set up required datasets"
end
=end
