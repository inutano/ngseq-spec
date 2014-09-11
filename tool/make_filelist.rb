# -*- coding: utf-8 -*-
# generates a list of file path sorted by file size
# from a list of SRA ID or files (ARGV[0]) in FastQC result directory (static)

require "parallel"

class SRAFile
  HOME = "/home/inutano"
  ACC = HOME + "/project/ER/table/SRA_Accessions.tab"
  @@hash = {}
  @@num_of_parallel = 16
  
  def self.set_accessions_hash
    s = `awk -F '\t' '$1 ~ /^.RR/ && $3 == "live" && $9 == "public" { print $1 "\t" $2 "\t" $11 }' #{ACC}`
    s.split("\n").each do |str|
      a = str.split("\t")
      @@hash[a[0]] = [a[1], a[2]]
    end
  end

  def self.available_list
    s = `awk -F '\t' '$1 ~ /^.RR/ && $3 == "live" && $9 == "public" { print $1 }' #{ACC}`
    s.split("\n").sort
  end
  
  def self.qc_done_list
    # return an array of qc-done ID
    fastqc_result_dir = HOME + "/backup/fastqc_result"
    index_dirs = Dir.glob(fastqc_result_dir + "/*RR*")
    runid_dirs = Parallel.map(index_dirs, :in_threads => @@num_of_parallel){|dpath| Dir.glob("#{dpath}/*RR*") }.flatten
    runfiles = Parallel.map(runid_dirs, :in_threads => @@num_of_parallel){|dpath| Dir.glob("#{dpath}/*zip") }.flatten
    Parallel.map(runfiles, :in_threads => @@num_of_parallel){|fname| fname.split("/").last.slice(0..8) }.sort.uniq
  end
  
  def self.fq_path(id)
    # return an array of fastq file path and filesize
    v = @@hash[id]
    fq_path = File.join(HOME, "data/fastq_data", v[0].slice(0..5), v[0], v[1])
    if File.exist?(fq_path)
      fq_files_path = Dir.glob(fq_path + "/#{id}*")
      if !fq_files_path.empty?
        fq_files_path.map{|f| [f, File.size(f)] }
      end
    end
  end
  
  def self.sra_path(id)
    # return an array of sra file and filesize
    v = @@hash[id]
    wtf = "data/litesra_data/ByExp/litesra"
    sralite_path = File.join(HOME, wtf, v[1].slice(0..2), v[1].slice(0..5), v[1], id)
    if File.exist?(sralite_path)
      sralite_file = Dir.glob(sralite_path + "/#{id}*sra")
      if !sralite_file.empty?
        sralite_file.map{|f| [f, File.size(f)] }
      end
    end
  end
  
  def self.get_file_path(id)
    path_array = self.fq_path(id)
    if !path_array
      path_array = self.sra_path(id)
    end
    path_array
  end
  
  def self.sorted_filepath(id_array)
    file_path_array = Parallel.map(id_array, :in_threads => @@num_of_parallel){|id| self.get_file_path(id) }.compact
    box_to_sort = []
    file_path_array.each do |path_array|
      path_array.each do |path_size|
        box_to_sort << path_size
      end
    end
    box_to_sort.sort_by{|array| array[1] }.map{|array| array.first }
  end
end

if __FILE__ == $0
  available_id = SRAFile.available_list
  qc_done_id = SRAFile.qc_done_list
  waiting_id = available_id - qc_done_id
  SRAFile.set_accessions_hash
  puts SRAFile.sorted_filepath(waiting_id)
end
