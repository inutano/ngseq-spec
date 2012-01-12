#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "#{File::expand_path(File::dirname(__FILE__))}/parse_sras_json.rb"
require "fileutils"

class IDlistUpdate
	def initialize
		@com = "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8"
		@run_members = "./SRA_Run_Members.tab"
		@accessions = "./SRA_Accessions.tab"
	end

	def run_members
		puts "updating SRA_Run_Members... #{Time.now.strftime("%H:%M:%S")}"
		FileUtils.mv(@run_members,"./previous/SRA_Run_Members_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@run_members)
		`lftp -c "#{@com} SRA_Run_Members.tab"`
		File.open(@run_members).readlines
	end
	
	def accessions
		puts "updating SRA_Accessions... #{Time.now.strftime("%H:%M:%S")}"
		FileUtils.mv(@accessions,"./previous/SRA_Accessions_#{Time.now.strftime("%m%d%H%M%S")}.tab") if File.exist?(@accessions)
		`lftp -c "#{@com} SRA_Accessions.tab"`
		File.open(@accessions).readlines
	end
	
	def available_runid(run_members)
		puts "updating available run id... #{Time.now.strftime("%H:%M:%S")}"
		run_members.delete_if{|l| l !~ /live/ }.map{|l| l.split("\t").first }.uniq
	end
	
	def paperpublished_subid
		puts "updating paper-published submission id... #{Time.now.strftime("%H:%M:%S")}"
		FileUtils.mv("./publication.json","./previous/publication_#{Time.now.strftime("%m%d%H%M%S")}.json") if File.exist?("./publication.json")
		`wget -O ./publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"`
		SRAsJSONParser.new("./publication.json").all_subid
	end
	
	def paperpublished_runid(pub_subid, accessions)
		puts "updating paper published run id... #{Time.now.strftime("%H:%M:%S")}"
		sub_run = {}
		accessions.delete_if{|l| !(l =~ /^(S|E|D)RR/ && l.include?("live"))}.each do |l|
			sub_run[l.split(",").last] ||= []
			sub_run[l.split(",").last].push(l.split(",").first)
		end
		pub_subid.map{|subid| sub_run[subid]}.flatten.uniq
	end
	
	def list4process(pub_runid, available_runid)
		puts "updating list for processing quality check... #{Time.now.strftime("%H:%M:%S")}"
		(pub_runid + available_runid).uniq
	end
	
end

if __FILE__ == $0
	if ARGV[0] == "--run-update"
		updater = IDlistUpdate.new 
		
		# update index of SRA runid
		runid = updater.run_members

		# update index of SRA accessions
		accessions = updater.accessions
		
		# update "live" runid
		available_runid = updater.available_runid(runid)
		
		# update paperpublished submission id
		pub_subid = updater.paperpublished_subid
		
		# update paperpublushed run id, one should be qualitycheck-processed
		pub_runid = updater.paperpublished_runid(pub_subid, accessions)
		
		# update list for qualitycheck process
		list_for_process = updater.list4process(pub_runid, available_runid)
		
		puts list_for_process.length
		open("todo.json","w"){|f| JSON.dump(list_for_process, f)}
	end
end
