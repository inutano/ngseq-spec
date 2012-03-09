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

  if !File.exist?("./production.sqlite3")
    puts "start DB migration #{Time.now}"
    SRAIDsInit.migrate( :up )
  end
  
  puts "updating SRA Accessions list from NCBI #{Time.now}"
  available_on_ftp = Update.accessions.select{|l| l =~ /^.RR/ && l.split("\t")[2] == "live"}

  puts "calcurating items already in DB #{Time.now}"
  already_in_db = SRAID.all.map{|r| r.runid }

  puts "preparing list to insert: available on ftp site and not yet recorded #{Time.now}"
  update_list =  available_on_ftp.delete_if{|l| already_in_db.include?(l.split("\t").first)}
  
  puts "checking if there are existing items in update list #{Time.now}"
  result_dirs = Dir.entries("../result")  
  done = update_list.select{|l| result_dirs.include?(l.split("\t").first)}
  undone = update_list - done
  
  puts "start inserting records #{Time.now}"
  [done, undone].each do |set|
    SRAID.transaction {
      set.each do |line|
        arr = line.split("\t")
        insert = { :paper => false }
        insert[ :runid ] = arr[0]
        insert[ :subid ] = arr[1]
        insert[ :studyid ] = arr[12]
        insert[ :expid ] = arr[10]
        insert[ :sampleid ] = arr[11]
        if set == done
          status = "done"
        else
          status = "available"
        end
        insert[ :status ] = status
        SRAID.create(insert)
        puts "inserted #{insert[:runid]} into DB"
      end
    }
  end
  
  puts "updating publication info #{Time.now}"
  SRAID.transaction {
    Update.paperpublished_subid.each do |subid|
      record = SRAID.find_by_subid(subid)
      if record
        record.paper = true
        record.save
      end
    end
  }
end
