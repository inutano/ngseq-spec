# coding for Ruby 2.0

require "parallel"
require "open-uri"
require "json"

if __FILE__ == $0
  acc = "../sra_metadata/SRA_Accessions"
  array = [ { name: "Submission", sym: "A" },
            { name: "Study", sym: "P" },
            { name: "Experiment", sym: "X" },
            { name: "Sample", sym: "S" },
            { name: "Run", sym: "R" } ]

  puts "#{Time.now} loading publication data.."

  json_url = "http://sra.dbcls.jp/cgi-bin/publication2.php"
  publication_data = open(json_url){|f| JSON.load(f) }["ResultSet"]["Result"]
  submission_ids = publication_data.map{|item| item["sra_id"] }.uniq
  
  puts "#{Time.now} publication countings;"
  puts "--"
  puts "Submission ID which has publication\t" + submission_ids.size.to_s
  
  mix_raw = Parallel.map(submission_ids) do |subid|
    `gawk -F '\t' '$2 == "#{subid}" { print $1 }' #{acc}`.split("\n")
  end
  mix = mix_raw.flatten.uniq
  
  array.select{|h| h[:sym] != "A" }.each do |h|
    puts "#{h[:name]} ID which has publication\t" + mix.select{|id| id =~ /^.R#{h[:sym]}/ }.size.to_s
    puts "--"
  end
end
