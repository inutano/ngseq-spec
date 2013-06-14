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
  base = path_list.first.slice(0..40)
  first = parse_fastqc(base + "_1_fastqc/fastqc_data.txt")
  second = parse_fastqc(base + "_2_fastqc/fastqc_data.txt")
  paired = (1..9).map{|num| (first[num] + second[num]) / 2 }
  [first[0]] + paired + ["paired"]
rescue NoMethodError, Errno::ENOENT
  ["unpaired"] + path_list
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
  
  puts header.join("\t")
  
  cdir = "../fastqc_data"
  index_dir = Dir.glob(cdir + "/?RR*")
  runid_dir = Parallel.map(index_dir){|path| Dir.glob(path + "/?RR*") }.flatten
  
  prev_result = ARGV.first
  if prev_result
    done = `awk -F '\t' '$1 != "" { printf "#{cdir}/" "%.6s" "/" "%.9s" ",", $1, $1 }' #{prev_result}`.split(",")
    runid_dir = Parallel.map(runid_dir){|path| path if !done.include?(path) }.compact
  end
  
  files_path_list = Parallel.map(runid_dir) do |path|
    Dir.glob(path + "/?RR*_fastqc")
  end
  
  while !files_path_list.empty?
    pnum = 160
    processing = files_path_list.shift(pnum)
    data = Parallel.map(processing) do |paths|
      path_num = paths.size
      case path_num
      when 1
        txt_path = paths.first + "/fastqc_data.txt"
        parse_fastqc(txt_path).join("\t")
      when 2 .. 3
        paired_avg(paths).join("\t")
      end
    end
    puts data.compact
  end
end
