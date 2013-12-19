# :)

require "rspec"
require "../lib/extract_readspec.rb"

describe ReadSpecUtils do
  describe "getting all the list of QC data path grouped by Run ID" do
    before do
      qc_dir = "../fastqc_data"
      @data_hash = ReadSpecUtils.get_data_path(qc_dir)
    end
    
    it "returns hash of which its keys only contain Run ID" do
      keys_not_runid = @data_hash.keys.select{|k| k !~ /^(S|E|D)RR\d{3}\d+$/ }
      expect(keys_not_runid).to be_empty
    end
  end
  
  context "generate a file path from query id DRR000001" do
    before do
      @id = "DRR000001"
      qc_dir = "../fastqc_data"
      @data_path = ReadSpecUtils.get_path(@id, qc_dir)
    end
    
    it "returns hash of which its key is same as query id" do
      keys = @data_path.keys
      expect(keys.size).to eq(1)
      expect(keys.first).to eq(@id)
    end
    
    it "returns hash of which its values are directory paths that exist" do
      values = @data_path.values
      expect(values.size).to eq(1)
      paths = values.first
      paths.each do |path|
        expect(File).to exist(path)
      end
    end
  end
end

describe ReadSpec do
  context "getting a summary for DRR000001" do
    before do
      id = "DRR000001"
      paths = ["../fastqc_data/DRR000/DRR000001/DRR000001_1_fastqc/fastqc_data.txt"]
      paths << "../fastqc_data/DRR000/DRR000001/DRR000001_2_fastqc/fastqc_data.txt"
      paths << "../fastqc_data/DRR000/DRR000001/DRR000001_fastqc/fastqc_data.txt"
      @rs = ReadSpec.new(id, paths)
    end
    
    it "returns merged qc data if it was paired-end" do
      qc_data = @rs.get_spec
      expect(qc_data).to be_a_kind_of(Array)
      expect(qc_data.compact.size).to eq(11)
    end
  end
end

