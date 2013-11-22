# -*- coding: utf-8 -*-

require "rspec"
require "../lib/sequencespec.rb"

describe SRAIDTable do
  context "with argument :sample" do
    before do
      data_dir = "/home/inutano/project/opensequencespec/data"
      @table_manager = SRAIDTable.new(data_dir, :sample)
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
