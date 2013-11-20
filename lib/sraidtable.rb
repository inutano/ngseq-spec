# -*- coding: utf-8 -*-

require "parallel"

class SRAIDTable
  def initialize(data_dir)
    @data_dir = data_dir
  end
  
  def load_accessions
    match = '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
    columns = [1, 2, 6, 10, 11, 12, 13, 18, 19]
    col_s = columns.map{|n| "$" + n.to_s }.join(' "\t" ')
    fpath = File.join @data_dir, "SRA_Accessions.tab"
    command = "awk -F '\t' '#{match} { print #{col_s} }' #{fpath}"
    
    @accessions ||= `#{command}`.split("\n").map do |line|
      line.split("\t")
    end
    @accessions
  end
  
  def columns_hash
    { run: 0,
      submission: 1,
      received: 2,
      alias: 3,
      experiment: 4,
      sample: 5,
      study: 6,
      biosample: 7,
      bioproject: 8 }
  end
  
  def get_idlist(symbol)
    @accessions ||= load_accessions
    col_num = columns_hash[symbol]
    Parallel.map(@accessions){|l| l[col_num] }.uniq
  end
  
  def get_run_hash(symbol)
    @accessions ||= load_accessions
    col_num = columns_hash[symbol]
    hash = {}
    Parallel.each(@accessions) do |line|
      hash[line[0]] = line[col_num]
    end
  end
end

if __FILE__ == $0
  idtable = SRAIDTable.new("../data")
  run_v_exp = idtable.get_run_hash(:experiment)
  puts run_v_exp
end
