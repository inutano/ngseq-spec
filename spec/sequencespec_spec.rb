# -*- coding: utf-8 -*-

require "rspec"
require "../lib/sequencespec.rb"

describe SRAIDTable do
  context "with argument :experiment" do
    before do
      data_dir = "/home/inutano/project/opensequencespec/data"
      @table_manager = SRAIDTable.new(data_dir, 4, :experiment)
    end
    
    context "with a case of DRX000001" do
      it "loads hash as table and each value is an arary" do
        table = @table_manager.load_table
        array = table["DRX000001"]
        expect(array.first).to eq("DRX000001")
        expect(array.size).to eq(9)
      end

      it "parses metadata and return it as an array of profiles" do
        array = @table_manager.parse_metadata("DRX000001")
        expect(array[0]).to eq("NATTO_BEST195_SEP08")
        expect(array[1]).to eq("WGS")
        expect(array[2]).to eq("GENOMIC")
        expect(array[3]).to eq("RANDOM")
        expect(array[4]).to eq("ILLUMINA")
        expect(array[5]).to eq("Illumina Genome Analyzer II")
      end
    end
  end

  context "with argument :sample" do
    before do
      data_dir = "/home/inutano/project/opensequencespec/data"
      @table_manager = SRAIDTable.new(data_dir, 4, :sample)
    end
    
    context "with a case of DRS000001" do
      it "loads hash as table and each value is an arary" do
        table = @table_manager.load_table
        array = table["DRS000001"]
        expect(array.first).to eq("DRS000001")
        expect(array.size).to eq(9)
      end
    
      it "parses metadata and return it as an array of profiles" do
        array = @table_manager.parse_metadata("DRS000001")
        expect(array[0]).to eq("Bacillus subtilis subsp. natto BEST195 without plasmid pBEST195L")
        expect(array[1]).to eq("86029")
      end
    end
  end
end
