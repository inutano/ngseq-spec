#!/usr/env/ruby
# -*- coding: utf8 -*-

require "#{File::expand_path(File::dirname(__FILE__))}/parse_sras_json.rb"

class IDlistUpdate
	def initialize
		@com = "open ftp.ncbi.nlm.nih.gov/sra/reports/Metadata && pget -n 8"
		@run_members = "./SRA_Run_Members.tab"
		@accesions = "./SRA_Accessions.tab"
	end

	def run_members
		FileUtils.mv(@run_members,"./tmp/SRA_Run_Members_#{Time.now.strftime("%m%d%H%M%S")}.tab" if !File.exist?(@run_members)
		`lftp -c "#{@com} SRA_Run_Members.tab"`
		File.open(@run_members).readlines
	end
	
	def accessions
		FileUtils.mv(@accessions,"./tmp/SRA_Accessions_#{Time.now.strftime("%m%d%H%M%S")}.tab" if !File.exist?(@run_members)
		`lftp -c "#{com} SRA_Accessions.tab"`
		File.open(@accessions).readlines
	end
	
	def available_runid(run_members)
		run_members.delete_if{|l| l !~ /live/ }.map{|l| l.split("\t").first }.uniq
	end
	
	def paperpublished_subid
		FileUtils.mv("./publication.json","./tmp/publication_#{Time.now.strftime("%m%d%H%M%S")}.json") if !File.exist?("./publication.json")
		`wget -O ${dir}/publication.json "http://sra.dbcls.jp/cgi-bin/publication2.php"`
		SRAJSONParser.new("./publication.json").all_subid
	end
	
	def paperpublished_runid(pub_subid, accessions)
		h_subrun = {}
		accessions.delete_if{|l| !(l =~ /^(S|E|D)RR/ && l.include?("live"))}.each do |l|
			subid_v_runid[l.split(",").last] ||= []
			subid_v_runid[l.split(",").last].push(l.split(",").first)
		end
		pub_subid.map{|subid| h_subrun[subid]}.flatten
	end
end

if __FILE__ == $0
	
end
