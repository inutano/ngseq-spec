# :)

require "json"
require "parallel"
require "fileutils"

def get_throughput(num_of_reads, mean_length, layout)
  multiple = case layout
             when "single"
               1
             when "paired"
               2
             end
  num_of_reads * mean_length * multiple
end

def get_coverage(throughput, gsize_mb)
  gsize = gsize_mb.to_f * 1_000_000
  if gsize > 0
    # gsize given by Mb order
    throughput / gsize
  else
    "NA"
  end
end

def merge_spec(readspec, md)
  rm_runid = md.shift

  num_of_reads, mean_length, layout = [1,4,10].map do |n|
    readspec[n]
  end
  gsize = md[15]
    
  th = get_throughput(num_of_reads, mean_length, layout)
  cov = get_coverage(th, gsize)
  readspec + md + [th, cov]
end

def line_valid?(a)
  if a.size == 30
    tf = (1..9).map do |n|
      a[n] >= 0
    end
    !tf.include?(false)
  end
end

if __FILE__ == $0
  # paths
  result_path = "../result"
  rs_fpath = "#{result_path}/readspec.json"
  ss_fpath = "#{result_path}/sequencespec.json"
  
  # load json files
  readspec, sequencespec = [rs_fpath, ss_fpath].map do |fpath|
    open(fpath){|f| JSON.parse(f.read, :symbolize_names => true) }
  end
  
  # threading option
  num_of_threads = 12
  
  # merge readspec and metadata
  invalid_pairs = []
  spec = Parallel.map(readspec, :in_threads => num_of_threads) do |id, readspec_a|
    readspec = readspec_a.flatten
    md = sequencespec[id].flatten
    
    line = if readspec[1] != "illegal-pair"
             merge_spec(readspec, md)
           else
             invalid_pairs << id
             nil
           end
    
    line.join("\t") if line && line_valid?(line)
  end
    
  # save results
  us_fpath = "#{result_path}/unitespec.tab"
  invalid_fpath = "#{result_path}/invalid_pairs.txt"
  
  ts = Time.now.strftime("%Y%m%d-%H%M")
  [[us_fpath, spec], [invalid_fpath, invalid_pairs]].each do |array|
    fpath = array[0]
    FileUtils.mv fpath, fpath + "." + ts if File.exist?(fpath)
    open(fpath,"w"){|f| f.puts(array[1].compact) }
  end
end
