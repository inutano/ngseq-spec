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
		@wholeset.map{|set| set["sra_id"]}
	end
	
	def journal_info(subid)
		@wholeset.select{|s| s["sra_id"] == subid }.map{|s| s.keep_if{|k,v| ["article_title","date","journal","pmid"].include?(k)}}
	end
end


if __FILE__ == $0
	parse_json = SRAsJSONParser.new(ARGV[0])
	#puts parse_json.all_subid
	pp parse_json.journal_info("SRA009031")
end
