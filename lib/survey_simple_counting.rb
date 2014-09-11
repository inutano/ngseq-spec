# coding for Ruby 2.0

if __FILE__ == $0
  acc = "../sra_metadata/SRA_Accessions"
  rmem = "../sra_metadata/SRA_Run_Members"

  array = [ { name: "Submission", sym: "A" },
            { name: "Study", sym: "P" },
            { name: "Experiment", sym: "X" },
            { name: "Sample", sym: "S" },
            { name: "Run", sym: "R" } ]
    
  puts "#{Time.now} simple countings;"
  puts "--"
  
  array.each do |h|
    name = h[:name]
    sym = h[:sym]
    
    num = `gawk -F '\t' '$1 ~ /^.R#{sym}/ { print $1 }' #{acc} | wc -l`
    puts "#{name} ID\t" + num
    puts "--"
    
    num_live = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" { print $1 }' #{acc} | wc -l`
    num_suppressed = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "suppressed" { print $1 }' #{acc} | wc -l`
    num_unpublished = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "unpublished" { print $1 }' #{acc} | wc -l`
    num_withdrawn = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "withdrawn" { print $1 }' #{acc} | wc -l`
    
    puts "#{name} ID status=live\t" + num_live
    puts "#{name} ID status=suppressed\t" + num_suppressed
    puts "#{name} ID status=unpublished\t" + num_unpublished
    puts "#{name} ID status=withdrawn\t" + num_withdrawn
    puts "--"
    
    num_public = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $9 == "public" { print $1 }' #{acc} | wc -l`
    num_controlled = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $9 == "controlled_access" { print $1 }' #{acc} | wc -l`
    
    puts "#{name} ID visibility=public\t" + num_public
    puts "#{name} ID visibility=controlled_access\t" + num_controlled
    puts "--"
  end
end
  
