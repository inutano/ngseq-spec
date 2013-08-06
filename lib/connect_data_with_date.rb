require "parallel"
require "time"

def date_hash_gen(cap)
  accessions_path = "../sra_metadata/SRA_Accessions"
  id_date = `awk -F '\t' '$1 ~ /^.R#{cap}/ { print $1 "\t" $6 }' #{accessions_path}`
  hash = {}
  id_date.split("\n").each do |id_d|
    array = id_d.split("\t")
    id = array[0]
    date = Time.parse(array[1])
    hash[id] = date
  end
  hash
end

if __FILE__ == $0
  input_path = ARGV.first
  input = open(input_path).readlines
  header = input.shift.chomp + "\t" + "date"
  puts header
  
  date_hash = if input_path =~ /sample/
                date_hash_gen("S")
              else
                date_hash_gen("R")
              end
  
  #output = Parallel.map(input) do |line_n|
  input.each do |line_n|
    line = line_n.chomp
    id = line.slice(0..8)
    date = date_hash[id]
    puts line + "\t" + date.to_s
  end
end
