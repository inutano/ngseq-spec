require "parallel"

if __FILE__ == $0
  accessions = "/Users/inutano/project/soylatte/data/SRA_Accessions.tab"
  file = ARGV.first
  str = `awk -F '\t' '$9 == "" { print $1 }' #{file} | sed -e 's:\.bz2$::g' -e 's:\.fastq$::g' -e 's:_.$::g'`
  missing_meta_id = str.split("\n").first(5000)
  
  out = Parallel.map(missing_meta_id) do |id|
    `awk '$1 == "#{id}" { print $1 "\t" $3 "\t" $9 }' #{accessions}`
  end
  puts out
end
