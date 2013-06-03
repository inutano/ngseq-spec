# coding for Ruby 2.0

require "parallel"
require "./fastqc_result_parser"

def parse_fastqc(path)
  p = FastQCParser.new(path)
  [ p.filename,
    p.total_sequences,
    p.min_length,
    p.max_length,
    p.percent_gc,
    p.normalized_phred_score,
    p.total_n_content,
    p.total_duplicate_percentage,
    "single" ]
end

def paired_avg(f, s)
  [ f[0],
    (f[1] + s[1]) / 2,
    (f[2] + s[2]) / 2,
    (f[3] + s[3]) / 2,
    (f[4] + s[4]) / 2,
    (f[5] + s[5]) / 2,
    (f[6] + s[6]) / 2,
    (f[7] + s[7]) / 2,
    "paired" ]
end

if __FILE__ == $0
  header = [ "filename",
             "total_sequences",
             "min_length",
             "max_length",
             "percent_gc",
             "normalized_phred_score",
             "total_n_content",
             "total_duplicate_percentage",
             "layout" ]
  
  cdir = "../fastqc_data"
  index_dir = Dir.glob(cdir + "/?RR*") # DRR000
  run_id_dir = Parallel.map(index_dir){|path| Dir.glob(path + "/?RR*") } # DRR000001
  
  data = Parallel.map(run_id_dir.flatten) do |path|
    path_list = Dir.glob(path + "/?RR*_fastqc") # ../fastqc_data/DRR000/DRR000001/DRR000001_1_fastqc
    path_num = path_list.size
    case path_num
    when 1
      txt_path = path_list.first + "/fastqc_data.txt"
      parse_fastqc(txt_path).join("\t")
    when 2 .. 3
      begin
        first_path = path_list.select{|f| f =~ /_1_fastqc/ }.first + "/fastqc_data.txt"
        second_path = path_list.select{|f| f =~ /_2_fastqc/ }.first + "/fastqc_data.txt"
        first = parse_fastqc(first_path)
        second = parse_fastqc(second_path)
        paired_avg(first, second).join("\t")
      rescue NoMethodError
        puts ["Error: missing pair"] + path_list
      end
    end
  end
  open("../data/data.merge","w"){|f| f.puts([header.join("\t")] + data) }
end
