# :)

require "parallel"
require "./fastqc_result_parser"

QCDir = "../fastqc_data"

def get_qc_files
  fname = "/fastqc_data.txt"
  dirs = Dir.glob(QCDir + "/?RR*/?RR*/?RR*_fastqc").map{|p| p + fname }
  dirs.group_by{|fp| fp.match(/(.RR\d+)_.+qc/)[1] }
end

class ReadSpec
  def initialize(run_id)
    @run_id = run_id
  end
  
  def fastqc_data
  end
  
  def metadata
  end
end

if __FILE__ == $0
  qc_files = get_qc_files
end
