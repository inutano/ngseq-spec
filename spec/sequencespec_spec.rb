# -*- coding: utf-8 -*-

require "rspec"
require "../lib/sequencespec.rb"

describe SRAIDTable do
  it 'should return hash of metadata' do
    data_dir = "/home/inutano/project/opensequencespec/data"
    table = SRAIDTable.new(data_dir, :sample)
    table.load_table["DRS000001"][0].should == "DRS000001"
  end
end
