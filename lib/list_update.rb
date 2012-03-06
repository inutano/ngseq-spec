#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "#{File::expand_path(File::dirname(__FILE__))}/parse_sras_json.rb"
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
      t.string :subid
      t.string :studyid
      t.string :expid
      t.string :sampleid
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
  @@run_members = "./SRA_Run_Members.tab"
  @@accessions = "./SRA_Accessions.tab"

  def self.run_members
    FileUtils.mv(@@run_members,"./previous/SRA_Run_Members_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@@run_members)
    `lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Run_Members.tab"`
    File.open(@@run_members).readlines
  end
  def self.accessions
    FileUtils.mv(@@accessions,"./previous/SRA_Accessions_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@@accessions)
    `lftp -c "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8 SRA_Accessions.tab"`
    File.open(@@accessions).readlines
  end
  def self.available_runid(run_members)
    run_members.select{|l| l =~ /live/ }.map{|l| l.split("\t").first }.uniq
  end
  def self.paperpublished_subid
    FileUtils.mv("./publication.json","./previous/publication_#{Time.now.strftime("%m%d%H%M%S")}.json") if File.exist?("./publication.json")
    `wget -O ./publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"`
    SRAsJSONParser.new("./publication.json").all_subid
  end
  def self.paperpublished_runid(pub_subid, accessions)
    sub_runid = pub_subid.map do |subid|
      accessions.select{|l| l.include?(subid) && l=~ /^.RR/ && l.include?("live") }.map{|l| l.split("\t").first }
    end
    sub_runid.flatten.uniq
  end
end

if __FILE__ == $0
  # create db file and table if it  does not exist
  SRAIDsInit.migrate( :up ) if !File.exist?("./production.sqlite3")
  
  puts "updating SRA_Run_Members.tab #{Time.now}"
  run_members = Update.run_members
	
  puts "updating SRA_Accessions.tab #{Time.now}"
  accessions = Update.accessions

  puts "putting live id to db.. #{Time.now}"
  Update.available_runid(run_members).each do |id|
    SRAID.create( :runid => id, :status => "available", :paper => false ) if !SRAID.find_by_runid(id)
  end
	
  puts "updating publication.json from DBCLS SRAs #{Time.now}"
  pub_subid = Update.paperpublished_subid
	
  puts "mark paper-publushed run id on db #{Time.now}"
  Update.paperpublished_runid(pub_subid, accessions).each do |id|
    record = SRAID.find_by_runid(id)
    if record
      record.paper = true
      record.save
    end
  end
  
  puts "search submission, project, experiment ID and put them into DB #{Time.now}"
  SRAID.all.each do |record|
    runid = record.runid
    acc = accessions.select{|line| line =~ /^#{runid}/ }.join.split("\t")
    record.subid = acc[1]
    record.studyid = acc[12]
    record.expid = acc[10]
    record.sampleid = acc[11]
    record.save
    puts "record for #{record.runid}: #{record.subid}, #{record.studyid}, #{record.expid}, #{record.sampleid}"
  end
  
  puts "mark already calcurated items as done #{Time.now}"
  SRAID.all.each do |record|
    runid = record.runid
    result_dir = "../result/#{runid}"
    if record.status != "done" && record.status != "ongoing" && File.exist?(result_dir)
      record.status = "done"
      record.save
    end
  end  
end

