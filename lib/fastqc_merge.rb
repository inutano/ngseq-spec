# coding for Ruby 2.0

require "parallel"
require "./fastqc_result_parser"

def parse_fastqc(path)
  p = FastQCParser.new(path)
  [ p.filename,
    p.total_sequences,
    p.min_length,
    p.max_length,
    p.mean_sequence_length,
    p.median_sequence_length,
    p.percent_gc,
    p.normalized_phred_score,
    p.total_n_content,
    p.total_duplicate_percentage,
    "single" ]
end

def paired_avg(path_list)
  first_path = path_list.select{|f| f =~ /_1_fastqc/ }.first + "/fastqc_data.txt"
  second_path = path_list.select{|f| f =~ /_2_fastqc/ }.first + "/fastqc_data.txt"

  first = parse_fastqc(first_path)
  second = parse_fastqc(second_path)
  paired = (1..9).map{|num| (first[num] + second[num]) / 2 }

  [first[0]] + paired + ["paired"]
rescue NoMethodError
  []
end

if __FILE__ == $0
  header = [ "filename",
             "total_sequences",
             "min_length",
             "max_length",
             "mean_length",
             "median_length",
             "percent_gc",
             "normalized_phred_score",
             "total_n_content",
             "total_duplicate_percentage",
             "layout" ]
  
  cdir = "../fastqc_data"
  index_dir = Dir.glob(cdir + "/?RR*") # DRR000
  path_list = Parallel.map(index_dir){|path| Dir.glob(path + "/?RR*") }.flatten # DRR000001
  
  prev_path = ARGV.first
  if prev_path
    prev_id_list = `awk -F '\t' '$1 != "" { printf "#{cdir}/" "%.6s" "/" "%.9s" "\n", $1 }' #{prev_path}`.split("\n")
    path_list = path_list - prev_id_list
  end
  
  data = path_list.map do |path|
    path_list = Dir.glob(path + "/?RR*_fastqc") # ../fastqc_data/DRR000/DRR000001/DRR000001_1_fastqc
    path_num = path_list.size
    case path_num
    when 1
      txt_path = path_list.first + "/fastqc_data.txt"
      parse_fastqc(txt_path).join("\t")
    when 2 .. 3
      paired_avg(path_list).join("\t")
    end
  end
  open("../data/data.merge.raw","w"){|f| f.puts([header.join("\t")] + data.compact) }
end
