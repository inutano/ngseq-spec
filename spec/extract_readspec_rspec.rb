# :)

require "rspec"
require "../lib/extract_readspec.rb"

describe ReadSpecUtils do
  describe "getting all the list of QC data path grouped by Run ID" do
    before do
      qc_dir = "../fastqc_data"
      @data_hash = ReadSpecUtils.get_all_path(qc_dir)
    end
    
    it "returns hash of which its keys only contain Run ID" do
      keys_not_runid = @data_hash.keys.select{|k| k !~ /^(S|E|D)RR\d{3}\d+$/ }
      expect(keys_not_runid).to be_empty
    end
  end
  
  context "generate a file path from query id DRR000001" do
    before do
      id = "DRR000001"
      qc_dir = "../fastqc_data"
      @paths = ReadSpecUtils.get_path_by_id(id, qc_dir)
    end
    
    it "returns an array of data paths that are exist" do
      @paths.each do |path|
        expect(File).to exist(path)
      end
    end
  end
end

describe ReadSpec do
  context "getting a summary for DRR000001" do
    before do
      id = "DRR000001"
      qc_dir = "../fastqc_data"
      paths = ReadSpecUtils.get_path_by_id(id, qc_dir)
      @rs = ReadSpec.new(id, paths)
    end
    
    it "returns merged qc data if it was paired-end" do
      qc_data = @rs.get_spec
      expect(qc_data).to be_a_kind_of(Array)
      expect(qc_data.compact.size).to eq(11)
    end
  end
end

