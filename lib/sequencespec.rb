# -*- coding: utf-8 -*-

require "parallel"
require "./sra_metadata_parser"
require "json"

class SRAIDTable
  def initialize(data_dir, symbol)
    @accessions = File.join data_dir, "SRA_Accessions.tab"
    @sra_metadata = File.join data_dir, "sra_metadata"
    @symbol = symbol
    @table = load_table
  end
  attr_accessor :table
  
  def load_table
    prefix = { run: "RR", exp: "RX", sample: "RS" }
    
    # id, acc, received, alias, exp, smaple, project, bioproject, biosample 
    columns = [ 1, 2, 6, 10, 11, 12, 13, 18, 19 ]
    column_string = columns.map{|num| "$#{num}" }.join(' "\t" ')
    match = '$1 ~ /^.#{prefix[@symbol]}/ && $3 == "live" && $9 == "public"'
    awk = "awk -F '\t' '#{match} { print #{column_string} }' #{@accessions}"
    
    idlist = `#{awk}`.split("\n")
    idlist_array = Parallel.map(idlist){|line| line.split("\t") }
    grouped_by_id = idlist_array.group_by{|line| line.first }
    grouped_by_id.each{|k,v| grouped_by_id[k] = v.flatten }
  end
  
  def get_id_related_run
    # get live experiment/sample id, related to live run id
    col_num = { experiment: 4, sample: 5 }
    @run_table ||= load_table(:run)
    Parallel.map(@run_table.values){|props| props[col_num[@symbol]] }
  end
  
  def parse_metadata(id)
    subid = @table[id][1]
    fname = [subid, @symbol.to_s, "xml"].join(".")
    xml = File.join @sra_metadata, subid.slice(0..5), subid, fname
    
    case @symbol
    when :experiment
      p = SRAMetadataParser::Experiment.new(id, xml)
      field = [ :id, :alias, :library_strategy, :library_source, :library_selection,
                :library_layout, :platform, :instrrument_model ]
    when :sample
      p = SRAMetadataParser::Sample.new(id, xml)
      field = [ :id, :alias, :taxon_id ]
    end
    field.map{|f| p.send(f) }
  end
  
  def get_metadata_hash
    metadatalist = Parallel.map(@table.keys) do |id|
      parse_metadata(id)
    end
    grouped_by_id = metadatalist.group_by{|array| array.first }
    grouped_by_id.each{|k,v| grouped_by_id[k] = v.flatten }
  end
end

if __FILE__ == $0
  # parse metadata for all experiment/sample
  exptable = SRAIDTable.new(:experiment)
  exp_metadata_hash = exptable.get_metadata_hash
  
  sampletable = SRAIDTable.new(:sample)
  sample_metadata_hash = sampletable.get_metadata_hash
  
  # merge all information to runid
  runtable = SRAIDTable.new(:run)
  
  merged_table = Parallel.map(runtable.table.keys) do |table|
    runid = table.shift
    expid = table[3]
    sampleid = table[4]
    [ runid,
      table,
      exp_metadata_hash[expid],
      sample_metadata_hash[sampleid] ].flatten
  end
  open("sequencespec.json","w"){|f| JSON.dump(merged_table, f) }
end
