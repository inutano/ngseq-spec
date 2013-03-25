# coding for Ruby 2.0

require "parallel"
require "open-uri"
require "json"
require "./fastqc_result_parser"

require "ap"

if __FILE__ == $0
  acc = "./sra_metadata/SRA_Accessions"
  rmem = "./sra_metadata/SRA_Run_Members"

  array = [ { name: "Submission", sym: "A" },
            { name: "Study", sym: "P" },
            { name: "Experiment", sym: "X" },
            { name: "Sample", sym: "S" },
            { name: "Run", sym: "R" } ]
    
  case ARGV.first
  when nil, "--help"
    puts "main.rb for sra statistics"
    puts "--counting-ids" + "\t" + "ID count"
    puts "--fastqc" + "\t" + "generate fastqc data tsv"
    puts "--publication" + "\t" + "ID list which has publication"
    puts "--available" + "\t" + "report availability of items"
    
  when "--counting-ids"
    puts "#{Time.now} simple countings;"    
    puts "--"
    
    array.each do |h|
      name = h[:name]
      sym = h[:sym]
      num = `gawk -F '\t' '$1 ~ /^.R#{sym}/ { print $1 }' #{acc} | wc -l`
      puts "Number of #{name} ID\t" + num
      puts "--"
      
      num_live = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" { print $1 }' #{acc} | wc -l`
      num_suppressed = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "suppressed" { print $1 }' #{acc} | wc -l`
      num_unpublished = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "unpublished" { print $1 }' #{acc} | wc -l`
      num_withdrawn = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "withdrawn" { print $1 }' #{acc} | wc -l`
      puts "Number of #{name} ID status=live\t" + num_live
      puts "Number of #{name} ID status=suppressed\t" + num_suppressed
      puts "Number of #{name} ID status=unpublished\t" + num_unpublished
      puts "Number of #{name} ID status=withdrawn\t" + num_withdrawn
      puts "--"

      num_public = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $9 == "public" { print $1 }' #{acc} | wc -l`
      num_controlled = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $9 == "controlled_access" { print $1 }' #{acc} | wc -l`
      puts "Number of #{name} ID visibility=public\t" + num_public
      puts "Number of #{name} ID visibility=controlled_access\t" + num_controlled
      puts "--"
    end
  
  when "--pub"
    json_url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
    json = open(json_url){|f| JSON.load(f) }["ResultSet"]["Result"]
    sub_pub = json.map{|item| { sraid: item["sra_id"], pmid: item["pmid"]} }.uniq
    
    converted = Parallel.map(sub_pub) do |sp|
      ids = `gawk -F '\t' '$2 == "#{sp[:sraid]}" { print $1 }' #{acc}`.split("\n")
      ids.map do |id|
        [id, sp[:pmid]].join("\t")
      end
    end
    puts converted.flatten
    
  when "--publication"
    puts "#{Time.now} publication countings;"
    puts "--"
    
    json_url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
    sub_has_pub = open(json_url){|f| JSON.load(f) }["ResultSet"]["Result"].map{|item| item["sra_id"] }.uniq
    
    puts "Number of Submission ID which has publication\t" + sub_has_pub.size.to_s
    
    
    
    array.select{|h| h[:sym] != "A" }.each do |h|
      converted = Parallel.map(sub_has_pub) do |subid|
        `gawk -F '\t' '$1 ~ /^.R#{h[:sym]}/ && $2 ~ /#{subid}/ { print $1 }' #{acc}`.split("\n")
      end
      puts "Number of #{h[:name]} ID which has publication\t" + converted.flatten.size.to_s
    end
    puts "--"
  
  when "--available"
    puts "#{Time.now} availability survey"
    puts "--"
    
    json_url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
    sub_has_pub = open(json_url){|f| JSON.load(f) }["ResultSet"]["Result"].map{|item| item["sra_id"] }.uniq

    array.each do |h|
      name = h[:name]
      sym = h[:sym]
      head = "#{name} ID, "
      
      num_live = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" { print $1 }' #{acc} | wc -l`
      num_dead = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 != "live" { print $1 }' #{acc} | wc -l`
      
      puts head + "status == \"live\", available\t" + num_live
      puts head + "status != \"live\", not available\t" + num_dead
      puts "The ratio of live #{name} is\t" + (num_live.to_f / (num_live.to_f+num_dead.to_f)).to_s
      puts "--"
      
      num_public_ids = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" && $9 == "public" { print $1 }' #{acc}`.split("\n")
      num_public = num_public_ids.size.to_s
      num_controlled = `gawk -F '\t' '$1 ~ /^.R#{sym}/ && $3 == "live" && $9 == "controlled_access" { print $1 }' #{acc} | wc -l`
      
      puts head + "status == \"live\" and visibility == \"public\", anyone can access\t" + num_public
      puts head + "status == \"live\" and visibility == \"controlled_access\", permission required\t" + num_controlled
      puts "The ratio of live and public #{name} is\t" + (num_public.to_f / (num_public.to_f+num_controlled.to_f)).to_s
      puts "--"
      
      live_public_publish = Parallel.map(num_public_ids) do |id|
        id if sub_has_pub.include?(id)
      end
      num_pub = live_public_publish.compact.size
      num_nyp = live_public_publish.size - num_pub
      
      puts head + "status == \"live\", visibility == \"public\", and has publication\t" + num_pub.to_s
      puts head + "status == \"live\", visibility == \"public\", but does not have publication\t" + num_nyp.to_s
      puts "The ratio of live and public #{name} which has publication is\t" + (num_pub.to_f/(num_pub+num_nyp)).to_s
      puts "--"
    end
  
  when "--fastqc"
    cdir = "./fastqc_data"
    index_dir = Dir.glob(cdir + "/?RR*")
    run_id_dir = Parallel.map(index_dir){|path| Dir.glob(path + "/?RR*") }
    read_dir = Parallel.map(run_id_dir.flatten){|path| Dir.glob(path + "/?RR*") }
    data_list = Parallel.map(read_dir.flatten){|path| path + "/fastqc_data.txt" }
    
    while !data_list.empty?
      files = data_list.shift(52)
      data = Parallel.map(files) do |path|
        p = FastQCParser.new(path)
        array = [ p.filename,
                  p.total_sequences,
                  p.min_length,
                  p.max_length,
                  p.percent_gc,
                  p.normalized_phred_score,
                  p.total_n_content,
                  p.total_duplicate_percentage ]
        array.join("\t")
      end
      puts data
    end
  end
end
