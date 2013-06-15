require "groonga"
require "parallel"
require "nokogiri"

def metadata_extract(acc, exp)
  base = "/Users/inutano/project/soylatte/data/sra_metadata"
  xml = File.join(base, acc.slice(0..5), acc, acc + ".experiment.xml")
  
  nkgr = Nokogiri::XML(open(xml)).css("EXPERIMENT").select{|n| n.attr("accession") == exp }.first
  raise NameError, "experiment id not found" unless nkgr

  inst = nkgr.css("INSTRUMENT_MODEL").inner_text
  platform = inst.split("\s").first if inst
  [ inst,
    platform,
    nkgr.css("LIBRARY_STRATEGY").inner_text,
    nkgr.css("LIBRARY_SOURCE").inner_text,
    nkgr.css("LIBRARY_SELECTION").inner_text,
    #nkgr.css("LIBRARY_LAYOUT").first.children[1].name,
    #nkgr.css("LIBRARY_LAYOUT").first.children[1].attr("NOMINAL_LENGTH").to_s,
    #nkgr.css("LIBRARY_LAYOUT").first.children[1].attr("NOMINAL_SDEV").to_s,
  ]
rescue NameError, Errno::ENOENT
  []
end

if __FILE__ == $0
  input_file = ARGV.first
  data = open(input_file).readlines
  
  header = data.shift
  add_header = [ "instrument",
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
  puts header.chomp + "\t" + add_header.join("\t")
  
  db_path = "../db/project.db"
  Groonga::Database.open(db_path)
  runs = Groonga["Runs"]
  
  not_recorded = []
  data.each do |line_raw|
    line = line_raw.chomp
    id = line.slice(0..8)
    run_record = runs[id]
    if run_record
      #s_name_a = run_record.sample.map{|r| r ? r.scientific_name : r }.uniq.compact
      #genus = s_name_a.map{|s_name| s_name.split("\s").first }.uniq.compact
      inst = run_record.instrument
      platform = inst.split("\s").first if inst
      a = [ inst,
            platform,
            run_record.library_strategy,
            run_record.library_source,
            run_record.library_selection,
            #run_record.library_layout,
            #run_record.library_nominal_length,
            #run_record.library_nominal_sdev,
            #s_name_a.join("\s"),
            #genus.join("\s"),
          ]
      puts line + "\t" + a.join("\t")
    else
      not_recorded << line
    end
  end
  
  exp_hash = {} # runid => expid
  run_raw = `awk -F '\t' '$1 ~ /^.RR/ { print $1 "\t" $3 }' "../sra_metadata/SRA_Run_Members"`
  run_raw.split("\n").each do |line|
    id_acc = line.split("\t")
    exp_hash[id_acc[0]] = id_acc[1]
  end
  
  acc_hash = {} # exp id => submissionid
  acc_raw = `awk -F '\t' '$1 ~ /^.RX/ { print $1 "\t" $2 }' "../sra_metadata/SRA_Accessions"`
  acc_raw.split("\n").each do |line|
    id_acc = line.split("\t")
    acc_hash[id_acc[0]] = id_acc[1]
  end
  
  line_remain =  not_recorded.select{|l| l != "" }
  while !line_remain.empty?
    processing = line_remain.shift(160)
    data = Parallel.map(processing) do |line|
      id = line.slice(0..8)
      expid = exp_hash[id]
      accid = acc_hash[expid]
      a = metadata_extract(accid, expid)
      line + "\t" + a.join("\t")
    end
    puts data
  end
end
