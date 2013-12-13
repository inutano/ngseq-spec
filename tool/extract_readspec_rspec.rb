# :)

require "rspec"
require "./extract_readspec.rb"

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
