require "groonga"
require "parallel"
require "nokogiri"

ACC_PATH = "/Users/inutano/project/statistics_sra/sra_metadata/SRA_Accessions"
RMEM_PATH = "/Users/inutano/project/statistics_sra/sra_metadata/SRA_Run_Members"
TAXON_PATH = "/Users/inutano/project/soylatte/data/taxon_table.csv"

def ref_taxid_sname
  id_sn = {}
  taxon_raw = `awk -F ',' '{ print $1 "\t" $2 }' #{TAXON_PATH}`.split("\n")
  taxon_raw.each do |line|
    id, name = line.split("\t")
    id_sn[id] = name
  end
  id_sn
end

# for experiment

def ref_run_exp
  run_exp = {}
  rmem = `awk -F '\t' '$1 ~ /^.RR/ { print $1 "\t" $3 }' #{RMEM_PATH}`.split("\n")
  rmem.each do |line|
    run, exp = line.split("\t")
    run_exp[run] = exp
  end
  run_exp
end

def ref_exp_sub
  exp_sub = {}
  acc = `awk -F '\t' '$1 ~ /^.RX/ { print $1 "\t" $2 }' #{ACC_PATH}`.split("\n")
  acc.each do |line|
    exp, sub = line.split("\t")
    exp_sub[exp] = sub
  end
  exp_sub
end

# for sample

def ref_run_sam
  run_sam = {}
  rmem = `awk -F '\t' '$1 ~ /^.RR/ { print $1 "\t" $4 }' #{RMEM_PATH}`.split("\n")
  rmem.each do |line|
    run, sam = line.split("\t")
    run_sam[run] = sam
  end
  run_sam
end

def ref_sam_sub
  sam_sub = {}
  acc = `awk -F '\t' '$1 ~ /^.RS/ { print $1 "\t" $2 }' #{ACC_PATH}`.split("\n")
  acc.each do |line|
    sam, sub = line.split("\t")
    sam_sub[sam] = sub
  end
  sam_sub
end

def metadata_parser(acc, id, sym)
  metadata_path = "/Users/inutano/project/statistics_sra/sra_metadata/"
  fname = acc + ".#{sym.to_s}.xml"
  xml_path = File.join(metadata_path, acc.slice(0..5), acc, fname)
  Nokogiri::XML(open(xml_path)).css(sym.to_s.upcase).select{|n| n.attr("accession") == id }.first
rescue NameError, Errno::ENOENT
  nil
end

def extract_experiment(acc, exp)
  p = metadata_parser(acc, exp, :experiment)
  inst = p.css("INSTRUMENT_MODEL").inner_text
  platform = inst.split("\s").first if inst
  [ inst,
    platform,
    p.css("LIBRARY_STRATEGY").inner_text,
    p.css("LIBRARY_SOURCE").inner_text,
    p.css("LIBRARY_SELECTION").inner_text,
    #p.css("LIBRARY_LAYOUT").first.children[1].name,
    #p.css("LIBRARY_LAYOUT").first.children[1].attr("NOMINAL_LENGTH").to_s,
    #p.css("LIBRARY_LAYOUT").first.children[1].attr("NOMINAL_SDEV").to_s,
  ]
rescue NoMethodError
  (0..4).map{|n| nil }
end

def extract_taxid(acc, sam)
  p = metadata_parser(acc, sam, :sample)
  p.css("TAXON_ID").inner_text
rescue NoMethodError
  nil
end

if __FILE__ == $0
  input_file = ARGV.first || "/Users/inutano/project/statistics_sra/data/data.run"
  data = open(input_file).readlines
  
  # remove header and output
  header = data.shift
  add_header = [ "instrument",
                 "platform",
                 "lib_strategy",
                 "lib_source",
                 "lib_selection",
                 #"lib_layout",
                 #"lib_nominal_length",
                 #"lib_nominal_sdev",
                 "s_name",
                 "genus",
               ]
  puts header.chomp + "\t" + add_header.join("\t")

  # establish database connection
  db_path = "../db/project.db"
  Groonga::Database.open(db_path)
  runs = Groonga["Runs"]
  
  not_recorded = []
  data.each do |line_raw|
    line = line_raw.chomp
    id = line.slice(0..8)
    run_record = runs[id]
    if run_record
      s_name_a = run_record.sample.map{|r| r ? r.scientific_name : r }.uniq.compact
      genus = s_name_a.map{|s_name| s_name.split("\s").first }.uniq.compact
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
            s_name_a.join(","),
            genus.join(","),
          ]
      puts line + "\t" + a.join("\t")
    else
      not_recorded << line
    end
  end
  
  # section for data not recorded on soylatte DB
  # data tables
  taxid_sname = ref_taxid_sname
  run_exp = ref_run_exp
  exp_sub = ref_exp_sub
  run_sam = ref_run_sam
  sam_sub = ref_sam_sub
  
  # parallel processing of unknocked lines
  line_remain =  not_recorded.select{|l| l != "" }
  while !line_remain.empty?
    processing = line_remain.shift(80)
    data = Parallel.map(processing) do |line|
      run = line.slice(0..8)
      exp = run_exp[run]
      sam = run_sam[run]
      exp_meta = extract_experiment(exp_sub[exp], exp)
      taxid = extract_taxid(sam_sub[sam], sam)
      sname = taxid_sname[taxid] if taxid
      genus = sname.split("\s").first if sname
      ([line] + exp_meta + [sname, genus]).join("\t")
    end
    puts data
  end
end
