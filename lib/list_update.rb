# -*- coding: utf-8 -*-

require "#{File.expand_path(File.dirname(__FILE__))}/parse_sras_json.rb"
require "fileutils"
require "active_record"

ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => "./production.sqlite3"
)

class SRAIDsInit < ActiveRecord::Migration
  def self.up
    create_table( :sraids ) do |t|
      t.string :runid, :null => false
      t.string :subid, :null => false
      t.string :studyid, :null => false
      t.string :expid, :null => false
      t.string :sampleid, :null => false
      t.string :status, :null => false # done, ongoing, available, missing
      t.boolean :paper, :null => false # paper published or not
      t.timestamps
    end
  end
  def self.down
  end
end

class SRAID < ActiveRecord::Base
end

class Update
  @@accessions = "./SRA_Accessions.tab"
  @@run_members = "./SRA_Run_Members.tab"
  @@publication = "./publication.json"
  
  def self.accessions
    FileUtils.mv(@@accessions, "./previous/SRA_Accessions_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@@accessions)
    `lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Accessions.tab"`
    File.open(@@accessions).readlines
  end
  
  def self.run_members
    FileUtils.mv(@@run_members,"./previous/SRA_Run_Members_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@@run_members)
    `lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Run_Members.tab"`
    File.open(@@run_members).readlines
  end

  def self.paperpublished_subid
    FileUtils.mv(@@publication, "./previous/publication_#{Time.now.strftime("%m%d%H%M%S")}.json") if File.exist?(@@publication)
    `wget -O ./publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"`
    SRAsJSONParser.new(@@publication).all_subid
  end
end

if __FILE__ == $0
  # create db file and table if it  does not exist
  SRAIDsInit.migrate( :up ) if !File.exist?("./production.sqlite3")
  
  # preparing list to insert: available on ftp site and not yet recorded on DB
  available_on_ftp = Update.accessions.select{|l| l =~ /^.RR/ && l.split("\t")[2] == "live"}
  already_in_db = SRAID.all.map{|r| r.runid }
  update_list =  available_on_ftp.delete_if{|l| already_in_db.include?(l.split("\t").first)}
  
  # for the first time to create DB, devide already done and undone
  result_dirs = Dir.entries("../result")  
  done = update_list.select{|l| result_dirs.include?(l.split("\t").first)}
  undone = update_list - done
  
  [done, undone].each do |set|
    SRAID.transaction {
      set.each do |line|
        runid = line[0]
        subid = line[1]
        studyid = line[12]
        expid = line[10]
        sampleid = line[11]
        if set == done
          status = "done"
        else
          status = "available"
        end
        
        SRAID.create (
          :runid => runid,
          :subid => subid,
          :studyid => studyid,
          :expid => expid,
          :sampleid => sampleid,
          :status => status,
          :paper => false
        )
      end
    }
  end
  
  # update publication info
  SRAID.transaction {
    Update.paperpublished_subid.each do |subid|
      record = SRAID.find_by_subid(subid)
      record.paper = true
      record.save
    end
  }
end
