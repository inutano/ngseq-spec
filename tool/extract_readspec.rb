# :)

require "parallel"
require "./fastqc_result_parser"

module ReadSpecUtils
  def self.get_data_path(qc_dir)
    fname = "/fastqc_data.txt"
    dirs = Dir.glob(qc_dir + "/?RR*/?RR*/?RR*_fastqc").map{|p| p + fname }
    dirs.group_by{|fp| fp.match(/(.RR\d+)_.+qc/)[1] }
  end
end

class ReadSpec
  def initialize(run_id, read_path_set)
    @id = run_id
    @set = read_path_set
  end
  
  def get_spec(metadata_tab)
    qc_data = get_qc_data
    metadata = metadata_tab[@id]
    qc_data + metadata
  end
  
  def get_qc_data
    case @set.size
    when 1
      parse_qc_data(@set.first) + ["single"]
    else
      merge_qc_data + ["paired"]
    end
  end
  
  def merge_qc_data
    read1, read2 = [/_1/, /_2/].map{|rex| @set.select{|name| name =~ rex }.first }
    qc1, qc2 = [read1, read2].map{|read| parse_qc_data(read) }
    raise NameError if qc1[0] != qc2[0]
    [qc1[0]] + (1..8).map{|n| (qc1[n] + qc2[n]) / 2.0 }
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
  sequence_spec = "./sequencespec.json"
  md_tab = open(sequence_spec){|f| JSON.load(f) }
  
  data_path.each_pair do |id, paths|
    rs = ReadSpec.new(id, paths)
    rs.get_spec(md_tab)
  end
end
