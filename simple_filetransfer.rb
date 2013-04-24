# -*- coding: utf-8 -*-

require "parallel"
require "ap"

if __FILE__ == $0
  BASE = "/home/inutano"
  accessions = BASE + "/project/ER/table/SRA_Accessions.tab"
  run_members = BASE + "/project/ER/table/SRA_Run_Members.tab"
  fq_base = BASE + "/data/fastq_data"
  sralite_base = BASE + "/data/litesra_data"
  
  not_yet = open(BASE + "/project/ER/table/need_calc").readlines
  filepath = Parallel.map(not_yet) do |id_n|
    id = id_n.chomp
    fq_path = fq_base + `awk -F '\t' '$1 ~ /^#{id}/ { printf "/" "%.6s" "/" $2 "/" $11, $2 }' #{accessions}`
    sralite_path = sralite_base + `awk -F '\t' '$1 ~ /^#{id}/ { printf "%.3s" "/" "%.6s" "/" $11 "/" $1, $11, $11 }' #{accessions}`
    [fq_path, sralite_path]
  end
  filepath.each do |fpath_a|
    ap Dir.entries(fpath_a[0])
    ap Dir.entries(fpath_a[1])
  end
end
