# coding for Ruby 2.0 :)

require "parallel"

def ref_sp_gsize
  sp_gsize = {}
  raw = open("/Users/inutano/project/statistics_sra/taxonomy/sp_gsize.tab").readlines
  raw.each do |line|
    sp, gsize = line.chomp.split("\t")
    sp_gsize[sp] = gsize.to_i * 1_000_000
  end
  sp_gsize
end

if __FILE__ == $0
  # load table and remove header
  sp_gsize = ref_sp_gsize
  data_path = ARGV.first || "/Users/inutano/project/statistics_sra/data/data.run.meta"
  data = open(data_path).readlines
  header = [data.shift.chomp, "gsize"].join("\t")
  puts header
  
  # add genome size (estimated) if available
  #puts Parallel.map(data) do |line_n|
  data.each do |line_n|
    line = line_n.chomp
    sname = line.split("\t")[16]
    sp = sname.split("\s")[0..1].join("\s") if sname
    gsize = sp_gsize[sp]
    puts [line, gsize.to_s].join("\t")
  end
end
