# coding for Ruby 2.0

require "parallel"
require "./fastqc_result_parser"

if __FILE__ == $0
  header = [ "filename",
             "total_sequences",
             "min_length",
             "max_length",
             "percent_gc",
             "normalized_phred_score",
             "total_n_content",
             "total_duplicate_percentage",
           ]
  puts header.join("\t")
  
  acc = "../sra_metadata/SRA_Accessions"
  rmem = "../sra_metadata/SRA_Run_Members"

  array = [ { name: "Submission", sym: "A" },
            { name: "Study", sym: "P" },
            { name: "Experiment", sym: "X" },
            { name: "Sample", sym: "S" },
            { name: "Run", sym: "R" } ]
  
  cdir = "../fastqc_data"
  index_dir = Dir.glob(cdir + "/?RR*")
  run_id_dir = Parallel.map(index_dir){|path| Dir.glob(path + "/?RR*") }
  read_dir = Parallel.map(run_id_dir.flatten){|path| Dir.glob(path + "/?RR*") }
  data_list = Parallel.map(read_dir.flatten){|path| path + "/fastqc_data.txt" }
  
  while !data_list.empty?
    files = data_list.shift(52)
    data = Parallel.map(files) do |path|
      p = FastQCParser.new(path)
      array = [ p.filename,
                p.total_sequences,
                p.min_length,
                p.max_length,
                p.percent_gc,
                p.normalized_phred_score,
                p.total_n_content,
                p.total_duplicate_percentage ]
      array.join("\t")
    end
    puts data
  end
end
