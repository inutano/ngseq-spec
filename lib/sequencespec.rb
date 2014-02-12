# -*- coding: utf-8 -*-

require "parallel"
require "json"

require File.expand_path(File.dirname(__FILE__)) + "/sra_metadata_parser"

class SRAIDTable
  def initialize(data_dir, num_of_processes, symbol)
    @accessions = File.join data_dir, "SRA_Accessions.tab"
    @sra_metadata = File.join data_dir, "sra_metadata"
    
    @processes = num_of_processes
    
    @symbol = symbol
    @table = load_table
  end
  attr_accessor :table
  
  def load_table
    idlist = exec_awk(target_columns).split("\n")
    idlist_array = Parallel.map(idlist, :in_processes => @processes){|line| line.split("\t") }
    grouped_by_id = idlist_array.group_by{|line| line.first }
    grouped_by_id.each{|k,v| grouped_by_id[k] = v.flatten }
  end
  
  def target_columns
    # DEFINE COLUMN NUMBERS TO BE EXTRACTED FROM "SRA_Accessions.tab"
    # id, acc, received, alias, exp, sample, project, bioproject, biosample
    [ 1, 2, 6, 10, 11, 12, 13, 18, 19 ]
  end
  
  def exec_awk(columns)
    prefix = { run: "RR", experiment: "RX", sample: "RS" }
    match = "$1 ~ /^.#{prefix[@symbol]}/ && $3 == \"live\" && $9 == \"public\""
    column_string = columns.map{|num| "$#{num}" }.join(' "\t" ')
    `awk -F '\t' '#{match} { print #{column_string} }' #{@accessions}`
  end
  
  def get_id_related_run
    # get live experiment/sample id, related to live run id
    col_num = { experiment: 4, sample: 5 }
    @run_table ||= load_table(:run)
    Parallel.map(@run_table.values){|props| props[col_num[@symbol]] }
  end
  
  def parse_metadata(id)
    p = case @symbol
        when :experiment
          SRAMetadataParser::Experiment.new(id, get_xml_path(id))
        when :sample
          SRAMetadataParser::Sample.new(id, get_xml_path(id))
        end
    field_define[@symbol].map{|f| p.send(f) }
  rescue NameError, Errno::ENOENT
    nil
  end
  
  def get_xml_path(id)
    subid = @table[id][1]
    fname = [subid, @symbol.to_s, "xml"].join(".")
    File.join @sra_metadata, subid.slice(0..5), subid, fname
  end
  
  def field_define
    { experiment:
        [ :alias, :library_strategy, :library_source,
          :library_selection, :platform, :instrument_model ],
      sample:
        [ :alias, :taxon_id ] }
  end
  
  def get_metadata_hash
    metadatalist = Parallel.map(@table.keys, :in_processes => @processes) do |id|
      metad = parse_metadata(id)
      [id] + metad if metad
    end
    grouped_by_id = metadatalist.compact.group_by{|array| array.first }
    grouped_by_id.each{|k,v| grouped_by_id[k] = v.flatten }
  end
end

if __FILE__ == $0
  num_of_process = 16
  data_dir = "/home/inutano/project/opensequencespec/data"
  out_dir = "/home/inutano/project/opensequencespec/result"
  
  exp_json = out_dir + "/exp_metadata.json"
  sample_json = out_dir + "/sample_metadata.json"
  runtable_json = out_dir + "/runtable.json"

  if !File.exist?(exp_json)
    # expid => [expid, alias, strt, src, select, plat, inst]
    exptable = SRAIDTable.new(data_dir, num_of_process, :experiment)
    exp_metadata_hash = exptable.get_metadata_hash
    open(exp_json,"w"){|f| JSON.dump(exp_metadata_hash, f) }
  end
  
  if !File.exist?(sample_json)
    # sampleid => [sampleid, alias, taxid]
    sampletable = SRAIDTable.new(data_dir, num_of_process, :sample)
    sample_metadata_hash = sampletable.get_metadata_hash
    open(sample_json,"w"){|f| JSON.dump(sample_metadata_hash, f) }
  end
  
  if !File.exist?(runtable_json)
    # runid => [runid, acc, received, alias, exp, sample, project, bioproject, biosample]
    runtable = SRAIDTable.new(data_dir, num_of_process, :run).table
    open(runtable_json,"w"){|f| JSON.dump(runtable, f) }
  end

  # load external reference table
  # taxon id to scientific name
  tax_sp = {}
  open(data_dir+"taxon_table.csv").readlines.each do |line_n|
    line = line_n.chomp.split(",")
    tax_sp[line[0]] = line[1]
  end
  
  # genome size by species
  sp_gsize = {}
  open(data_dir+"/sp_gsize.tab").readlines.each do |line_n|
    line = line_n.chomp.split("\t")
    sp_gsize[line[0]] = line[1]
  end
  
  # merge all information to runid
  exp_metadata_hash = open(exp_json){|f| JSON.load(f) }
  sample_metadata_hash = open(sample_json){|f| JSON.load(f) }
  runtable = open(runtable_json){|f| JSON.load(f) }
  
  merged_table = Parallel.map(runtable.values, :in_processes => num_of_process) do |run_meta|
    exp_meta = exp_metadata_hash[run_meta[4]]
    sample_meta = sample_metadata_hash[run_meta[5]]
    spname = tax_sp[sample_meta[2]]
    
    # output table scheme:
    # runid, subid, studyid, expid, sampleid,
    [ run_meta[0], run_meta[1], run_meta[6], exp_meta[0], sample_meta[0],
    # run_alias, exp_alias, sample_alias,
      run_meta[3], exp_meta[1], sample_meta[1],
    # lib strategy, source, selection, platform, instrument,
      exp_meta[2], exp_meta[3], exp_meta[4], exp_meta[5], exp_meta[6],
    # taxonomy id, scientific name, genus, estimated genome size (Mb, include NA),
      sample_meta[2], spname, spname.split("\s").first, sp_gsize[spname],
    # received date
      run_meta[2] ]
  end
  sequence_spec = merged_table.group_by{|n| n.first }
  open(out_dir + "/sequencespec.json","w"){|f| JSON.dump(merged_table, f) }
end
