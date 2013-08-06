# coding for Ruby 2.0 :)

require "parallel"
RMEM_PATH = "/Users/inutano/project/statistics_sra/sra_metadata/SRA_Run_Members"

def header
  [ "filename",
    "total_sequences",
    "min_length",
    "max_length",
    "mean_length",
    "median_length",
    "percent_gc",
    "normalized_phred_score",
    "total_n_content",
    "total_duplicate_percentage",
    "layout",
    "instrument",
    "platform",
    "lib_strategy",
    "lib_source",
    "lib_selection",
    #"lib_layout",
    #"lib_nominal_length",
    #"lib_nominal_sdev",
    "s_name",
    "genus",
  ]
end

def sample_avg(array)
  s = array.size
  case s
  when 1
    array.first[1..15]
  else
    sum = array.map{|p| p[1].to_i }.reduce(:+)
    avg = (2..9).map do |col|
      array.map{|p| p[col].to_f }.reduce(:+) / s
    end
    meta = (10..17).map do |col|
      array.map{|p| p[col] }.uniq.join(",")
    end
    [sum] + avg + meta
  end
end

def ref_run_exp
  run_exp = {}
  rmem = `awk -F '\t' '$8 == "live" { print $1 "," $3 }' #{RMEM_PATH}`.split("\n")
  rmem.each do |line_c|
    run, exp = line_c.split(",")
    run_exp[run] = exp
  end
  run_exp
end

def ref_exp_run(runid_list)
  exp_run = {}
  run_exp = ref_run_exp
  runid_list.each do |id|
    exp = run_exp[id]
    exp_run[exp] ||= []
    exp_run[exp] << id
  end
  exp_run
end

def ref_run_sam
  run_sam = {}
  rmem = `awk -F '\t' '$8 == "live" { print $1 "," $4 }' #{RMEM_PATH}`.split("\n")
  rmem.each do |line_c|
    run, sam = line_c.split(",")
    run_sam[run] ||= []
    run_sam[run] << sam
  end
  run_sam
end

def ref_exp_sam
  exp_sam = {}
  rmem = `awk -F '\t' '$8 == "live" { print $3 "," $4 }' #{RMEM_PATH}`.split("\n")
  rmem.each do |line_c|
    exp, sam = line_c.split(",")
    exp_sam[exp] ||= []
    exp_sam[exp] << sam
  end
  exp_sam
end

if __FILE__ == $0
  require "ap"
  
  # load id tables and run data
  input = ARGV.first || "/Users/inutano/project/statistics_sra/data/data.run.meta"
  data_raw = open(input).readlines
  head_rm = data_raw.shift.chomp.split("\t")
  
  # id data table
  runid_data = {}
  data_raw.each do |line_n|
    line = line_n.chomp
    id = line.slice(0..8)
    runid_data[id] = line.split("\t")
  end
  runid_list = runid_data.keys
  
  # connect exp to run(s)
  exp_run = ref_exp_run(runid_list)
  
  # case exp-run: 1-1
  single_run = exp_run.select{|k,v| v.size == 1 }.values
  
  # case exp-run: 1-n
  run_sam = ref_run_sam
  multi_run = exp_run.select{|k,v| v.size > 1 }.values
  multi_run_persample = multi_run.map do |run_array|
    h = {}
    run_array.each do |run|
      sam = run_sam[run]
      if sam && sam.size == 1
        h[sam[0]] ||= []
        h[sam[0]] << run
      end
    end
    h.values.flatten if !h.empty?
  end
  
  # merging pairs of original data
  run_merging = single_run + multi_run_persample.compact
  
  lines_merging = Parallel.map(run_merging) do |id_array|
    data_array = id_array.map{|id| runid_data[id] }
    [id_array.first] + sample_avg(data_array)
  end
  
  puts header.join("\t")
  puts Parallel.map(lines_merging){|v| v.join("\t") }
end

=begin
  # remove exp with multiple samples
  exp_sam = ref_exp_sam
  run_merging = Parallel.map(exp_run) do |exp,runs|
    samples = exp_sam[exp]
    if samples && samples.size != 1
      runs
    end
  end
  
  #puts "multi sample experiments: " + (run_merging.size - run_merging.compact.size).to_s
  puts "id\tcount"
  puts run_merging.compact.map{|runs| [runs.first, runs.size].join("\t") }
=end
