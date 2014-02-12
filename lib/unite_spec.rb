# :)

require "json"
require "parallel"
require "fileutils"

if __FILE__ == $0
  rs_fpath = "../result/readspec.json"
  ss_fpath = "../result/sequencespec.json"
  
  readspec = open(rs_fpath){|f| JSON.parse(f.read, :symbolize_names => true) }
  sequencespec = open(ss_fpath){|f| JSON.parse(f.read, :symbolize_names => true) }
  
  num_of_threads = 12
  spec = Parallel.map(readspec, :in_threads => num_of_threads) do |id, readspec_a|
    md = sequencespec[id].flatten
    rm_runid = md.shift
    (readspec_a.flatten + md).join("\t")
  end
  
  us_fpath = "../result/unitespec.tab"
  if File.exist?(us_fpath)
    FileUtils.mv us_fpath, us_fpath + "." + Time.now.strftime("%Y%m%d-%H%M")
  end
  open(us_fpath, "w"){|f| f.puts(spec) }
end
