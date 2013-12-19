# :)

require "parallel"
require "json"

require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

module ReadSpecUtils
  def self.get_data_path(qc_dir)
    dirs = Dir.glob(qc_dir + "/?RR*/?RR*/?RR*_fastqc").map{|p| p + fname }
    dirs.group_by{|fp| fp.match(/(.RR\d+)_.+qc/)[1] }
  end
  
  def self.get_path(id, qc_dir)
    raise NameError if id !~ /^(S|E|D)RR\d{3}\d+$/
    dir = File.join qc_dir, id.slice(0..5), id
    reads = Dir.glob(dir + "/#{id}*_fastqc").map{|p| p + fname }
    reads.group_by{|fp| fp.match(/#{id}/).to_s }
  end
  
  def self.fname
    "/fastqc_data.txt"
  end
end

class ReadSpec
  def initialize(run_id, read_path_set)
    @id = run_id
    @set = read_path_set
  end
  
  def get_spec
    case @set.size
    when 1
      spec = parse_qc_data(@set.first) + ["single"]
    else
      spec = merge_qc_data + ["paired"]
    end
    [@id] + spec
  end
  
  def merge_qc_data
    read1, read2 = [/_1/, /_2/].map{|rex| @set.select{|name| name =~ rex }.first }
    qc1, qc2 = [read1, read2].map{|read| parse_qc_data(read) }
    raise NameError if qc1[0] != qc2[0]
    [qc1[0]] + (1..8).map{|n| (qc1[n] + qc2[n]) / 2.0 }
  rescue NameError
    ["illegal-pair"]
  end
  
  def parse_qc_data(path)
    p = FastQCParser.new(path)
    [ p.total_sequences,
      p.min_length,
      p.max_length,
      p.mean_sequence_length,
      p.median_sequence_length,
      p.percent_gc,
      p.normalized_phred_score,
      p.total_n_content,
      p.total_duplicate_percentage ]
  end
end

if __FILE__ == $0
  qc_dir = "../fastqc_data"
  data_path = ReadSpecUtils.get_data_path(qc_dir)
  
  readspec_array = Parallel.map(data_path, :in_threads => 20) do |id, paths|
    ReadSpec.new(id, paths).get_spec.join("\t")
  end
  
  readspec_hash = readspec_array.group_by{|line| line.first }
  open("../result/readspec.json","w"){|f| JSON.dump(readspec_hash, f) }
end
