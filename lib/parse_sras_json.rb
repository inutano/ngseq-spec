#!/home/iNut/.rvm/rubies/ruby-1.9.2-p180/bin/ruby
# -*- coding: utf-8 -*-

require "json"
require "open-uri"
require "pp"

class SRAsJSONParser
	def initialize(json)
		@wholeset = open(json){|f| JSON.load(f)}["ResultSet"]["Result"]
	end
	
	def all_subid
		@wholeset.map{|h| h["sra_id"]}.uniq
	end
	
	def paper_info(subid)
		@wholeset.select{|h| h["sra_id"] == subid }.map{|h| h.keep_if{|k,v| ["article_title","date","journal","pmid"].include?(k)}}
	end
end

if __FILE__ == $0
	if ARGV[0] == "--all-subid"
		json = "./publication.json"
		parse_json = SRAsJSONParser.new(json)
		puts parse_json.all_subid
	else ARGV[0] == "--paper-info"
		sub_id = ARGV[1]
		puts parse_json.paper_info(sub_id)
	end
end
