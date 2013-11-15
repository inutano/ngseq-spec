# -*- coding: utf-8 -*-

require "parallel"

def load_table(accessions_path)
  match = '$1 ~ /^.RR/ && $3 == "live" && $9 == "public"'
  column = [1, 2, 6, 10, 11, 12, 13, 18, 19]
  col_s = column.map{|n| "$" + n.to_s }.join(' "\t" ')
  out = "{ print #{col_s} }"
  awk = `awk -F '\t' '#{match} #{out}' #{accessions_path}`
  Parallel.map(awk.split("\n")){|l| l.split("\t") }
end

def get_list(accessions, symbol)
  hash = { run: 0,
           submission: 1,
           received: 2,
           alias: 3,
           experiment: 4,
           sample: 5,
           study: 6,
           biosample: 7,
           bioproject: 8 }
  accessions.map{|line| line[hash[symbol]] }.uniq
end

if __FILE__ == $0
  accessions_path = "../data/SRA_Accessions.tab"
  accessions = load_table(accessions_path)
  run_list = get_list(accessions, :run)
  exp_list = get_list(accessions, :experiment)
  sample_list = get_list(accessions, :sample)
  puts run_list, exp_list, sample_list
end
