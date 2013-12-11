# ruby 2.0

require "parallel"



if __FILE__ == $0
=begin
  runfile = "../data/data.run.meta.gs.date"
  expfile = "../data/data.exp.meta.gs.date"
  
  hash = {}
  `awk -F '\t' '{print $1}' #{runfile}`.split("\n").each do |fname_n|
    fname = fname_n.chomp
    hash[fname.slice(0..8)] = true if fname =~ /_/
  end
  
  data = open(expfile).readlines
  header = data.shift.chomp + "\tr_throughput"
  result = Parallel.map(data) do |line_n|
    line = line_n.chomp.split("\t")
    id = line[0]
    th = line[1]
    r_th = if hash[id]
             th.to_i * 2
           else
             th.to_i
           end
    l = line << r_th
    l.join("\t")
  end
  puts header
  puts result
=end  
#=begin
  data_path = ARGV.first
  data = open(data_path).readlines
  header = data.shift.chomp + "\tr_throughput"
  result = Parallel.map(data) do |line_n|
    line = line_n.chomp.split("\t")
    fname = line[0]
    throughput = line[1]
    real_throughput = if fname =~ /_/
                        throughput.to_i * 2
                      else
                        throughput.to_i
                      end
    l = line << real_throughput
    l.join("\t")
  end
  puts header
  puts result
#=end
end
