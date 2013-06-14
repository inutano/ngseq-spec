# coding for Ruby 2.0

require "parallel"

def header
  [ "filename",
    "total_sequences",
    "min_length",
    "max_length",
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
    #"s_name",
    #"genus",
  ]
end

def sample_avg(array)
  s = array.size
  case s
  when 1
    array.first.split("\t")[1..18]
  else
    parsed = array.map{|line| line.split("\t") }
    sum = parsed.map{|p| p[1].to_i }.reduce(:+)
    avg = (2..7).map do |col|
      parsed.map{|p| p[col].to_f }.reduce(:+) / s
    end
    meta = (8..18).map do |col|
      parsed.map{|p| p[col] }.uniq.join(",")
    end
    [sum] + avg + meta
  end
end

if __FILE__ == $0
  input_file = ARGV.first || "../data/data.merge.meta"
  lines = open(input_file).readlines.select{|l| l !~ /^filename/ }
  run_members = "../sra_metadata/SRA_Run_Members"
  
  runid_sampleid = `awk -F '\t' '$8 == "live" { print $1 "," $4 }' #{run_members}`.split("\n")
  run_v_sample = {}
  runid_sampleid.each do |run_sample|
    array = run_sample.split(",")
    runid = array[0]
    sampleid = array[1]
    run_v_sample[runid] ||= []
    run_v_sample[runid] << sampleid
  end
  
  sample_v_run = {}
  lines.each do |line_n|
    line = line_n.chomp
    runid = line.slice(0..8)
    sampleid = run_v_sample[runid]
    if sampleid
      if sampleid.size == 1
        sample_v_run[sampleid] ||= []
        sample_v_run[sampleid] << line
      else # multiplex
        sample_v_run[runid] = [line]
      end
    end
  end
  
  per_sample = Parallel.map(sample_v_run) do |k,v|
    values = sample_avg(v)
    ([k] + values).join("\t")
  end
  open("../data/data.sample.meta","w"){|f| f.puts([header.join("\t")] + per_sample) }
end
