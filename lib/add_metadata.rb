require "groonga"
require "parallel"
require "./lib_db_update"

if __FILE__ == $0
  input_file = ARGV.first
  data = open(input_file).readlines
  
  header = data.shift
  add_header = [ "instrument",
                 "platform",
                 "lib_strategy",
                 "lib_source",
                 "lib_selection",
                 "lib_layout",
                 "lib_nominal_length",
                 "lib_nominal_sdev",
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
            run_record.library_layout,
            run_record.library_nominal_length,
            run_record.library_nominal_sdev,
            #s_name_a.join("\s"),
            #genus.join("\s"),
          ]
      puts line + "\t" + a.join("\t")
    else
      not_recorded << line
    end
  end
  
  DBupdate.load_file("./config.yaml")
  while !not_recorded.empty?
    to_be_processed = not_recorded.shift(24)
    added_meta = Parallel.map(to_be_processed) do |line|
      id = line.slice(0..8)
      i = DBupdate.new(id).run_insert
      inst = i[:instrument]
      platform = inst.split("\s").first if inst
      a = [ inst,
            platform,
            i[:library_strategy],
            i[:library_source],
            i[:library_selection],
            i[:library_layout],
            i[:library_nominal_length],
            i[:library_nominal_sdev],
          ]
      line + "\t" + a.join("\t")
    end
    puts added_meta
  end
end
