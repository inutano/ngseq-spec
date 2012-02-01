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

class IDlistUpdate
	def initialize
		@com = "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8"
		@run_members = "./SRA_Run_Members.tab"
		@accessions = "./SRA_Accessions.tab"
		@time = Time.now.strftime("%m%d%H%M%S")
	end
	def run_members
		FileUtils.mv(@run_members,"./previous/SRA_Run_Members_#{@time}.tab") if File.exist?(@run_members)
		`lftp -c "#{@com} SRA_Run_Members.tab"`
		File.open(@run_members).readlines
	end
	def accessions
		FileUtils.mv(@accessions,"./previous/SRA_Accessions_#{@time}.tab") if File.exist?(@accessions)
		`lftp -c "#{@com} SRA_Accessions.tab"`
		File.open(@accessions).readlines
	end
	def available_runid(run_members)
		run_members.select{|l| l =~ /live/ }.map{|l| l.split("\t").first }.uniq
	end
	def paperpublished_subid
		FileUtils.mv("./publication.json","./previous/publication_#{@time}.json") if File.exist?("./publication.json")
		`wget -O ./publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"`
		SRAsJSONParser.new("./publication.json").all_subid
	end
	def paperpublished_runid(pub_subid, accessions)
		sub_run = {}
		accessions.select{|l| l =~ /^(S|E|D)RR/ && l.include?("live")}.each do |l|
			sub_run[l.split(",").last] ||= []
			sub_run[l.split(",").last].push(l.split(",").first)
		end
		pub_subid.map{|subid| sub_run[subid]}.flatten.uniq
	end
end

if __FILE__ == $0
	# create db file and table if it  does not exist
	SRAIDsInit.migrate( :up ) if !File.exist?("./production.sqlite3")

	updater = IDlistUpdate.new 

	puts "updating SRA_Run_Members.tab #{Time.now}"
	run_members = updater.run_members
	
	puts "updating SRA_Accessions.tab #{Time.now}"
	accessions = updater.accessions
	
	puts "putting live id to db.. #{Time.now}"
	updater.available_runid(run_members).each do |id|
		SRAID.create( :runid => id, :status => "available", :paper => false ) if SRAID.find_by_runid(id)
	end
	
	puts "updating publication.json from DBCLS SRAs #{Time.now}"
	pub_subid = updater.paperpublished_subid
	
	puts "mark paper-publushed run id on db #{Time.now}"
	updater.paperpublished_runid(pub_subid, accessions).each do |id|
		record = SRAID.find_by_runid(id)
		if record
			record.paper = true
			record.save
		end
	end
	
	puts "mark already calcurated items as done #{Time.now}"
	SRAID.all.each do |record|
		runid = record.runid
		result_dir = "../result/#{runid}"
		if record.status != "ongoing" && File.exist?(result_dir)
			record.status = "done"
			record.save
		end
	end
end

