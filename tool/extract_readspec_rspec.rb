# :)

require "rspec"
require "./extract_readspec.rb"

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
      qc_data = @rs.get_qc_data
      expect(qc_data).to be_a_kind_of(Array)
    end
  end
end

describe ReadSpecUtils do
  describe "getting a list of QC data path grouped by Run ID" do
    before do
      qc_dir = "../fastqc_data"
      @data_hash = ReadSpecUtils.get_data_path(qc_dir)
    end
    
    it "returns hash of which its keys only contain Run ID" do
      keys_not_runid = @data_hash.keys.select{|k| k !~ /^(S|E|D)RR\d{3}\d+$/ }
      expect(keys_not_runid).to be_empty
    end
  end
end
