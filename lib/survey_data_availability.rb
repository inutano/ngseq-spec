# coding for Ruby 2.0

require "parallel"
require "open-uri"
require "json"

if __FILE__ == $0
  acc = "../sra_metadata/SRA_Accessions"
  rmem = "../sra_metadata/SRA_Run_Members"

  array = [ { name: "Submission", sym: "A" },
            { name: "Study", sym: "P" },
            { name: "Experiment", sym: "X" },
            { name: "Sample", sym: "S" },
            { name: "Run", sym: "R" } ]
    
  puts "#{Time.now} availability survey"
  puts "--"
    
  json_url = "http://sra.dbcls.jp/cgi-bin/publication2.php"  
  submission_ids = open(json_url){|f| JSON.load(f) }["ResultSet"]["Result"].map{|item| item["sra_id"] }.uniq
  mix_raw = Parallel.map(submission_ids) do |subid|
    `gawk -F '\t' '$2 == "#{subid}" { print $1 }' #{acc}`.split("\n")
  end
  mix = mix_raw.flatten.uniq
  
  array.each do |h|
    name = h[:name]
    sym = h[:sym]
    head = "#{name} ID, "
    
    num_live = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" { print $1 }' #{acc} | wc -l`
    num_dead = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 != "live" { print $1 }' #{acc} | wc -l`
    
    puts head + "status == \"live\", available\t" + num_live
    puts head + "status != \"live\", not available\t" + num_dead
    puts "The ratio of live #{name} is\t" + (num_live.to_f / (num_live.to_f+num_dead.to_f)).to_s
      
    num_public_ids = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" && $9 == "public" { print $1 }' #{acc}`.split("\n")
    num_public = num_public_ids.size.to_s
    num_controlled = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" && $9 == "controlled_access" { print $1 }' #{acc} | wc -l`
    
    puts head + "status == \"live\" and visibility == \"public\", anyone can access\t" + num_public
    puts head + "status == \"live\" and visibility == \"controlled_access\", permission required\t" + num_controlled
    puts "The ratio of live and public #{name} is\t" + (num_public.to_f / (num_public.to_f+num_controlled.to_f)).to_s
    
    live_public_publish = num_public_ids.select{|id| mix.include?(id) }
    num_has_publication = live_public_publish.compact.size
    num_nyp = num_public.to_i - num_has_publication
    
    puts head + "status == \"live\", visibility == \"public\", and has publication\t" + num_has_publication.to_s
    puts head + "status == \"live\", visibility == \"public\", but does not have publication\t" + num_nyp.to_s
    puts "The ratio of live and public #{name} which has publication is\t" + (num_has_publication.to_f/(num_public.to_f)).to_s
    puts "--"
  end
end
