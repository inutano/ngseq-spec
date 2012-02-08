#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "yaml"
require "twitter"
require "active_record"
require "logger"

config = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")
path = config["path"]
tw_conf = config["twitter"]

ActiveRecord::Base.establish_connection(
	:adapter => "sqlite3",
	:database => "#{path}/production.sqlite3"
)

ActiveRecord::Base.logger = Logger.new("#{path}/database.log")

Twitter.configure do |config|
	config.consumer_key = tw_conf["consumer_key"]
	config.consumer_secret = tw_conf["consumer_secret"]
	config.oauth_token = tw_conf["oauth_token"]
	config.oauth_token_secret = tw_conf["oauth_token_secret"]
end

class SRAID < ActiveRecord::Base
	def to_s
		"#{runid}, status => #{status}, paper => #{paper}"
	end
end

class Monitoring
	def initialize
		@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]
	end
	
	def all
		SRAID.all
	end
		
	def task
		SRAID.where( :status => "available" ).order("paper DESC, runid ASC").map{|r| r.runid }
	end
	
	def paper_published
		SRAID.where( :status => "available", :paper => true ).map{|r| r.runid }
	end

	def paper_unpublished
		SRAID.where( :status => "available", :paper => false ).map{|r| r.runid }
	end
	
	def available
		SRAID.where( :status => "available" ).map{|r| r.runid }
	end
	
	def done
		SRAID.where( :status => "done" ).map{|r| r.runid }
	end
	
	def ongoing
		SRAID.where( :status => "ongoing" ).map{|r| r.runid }
	end
	
	def missing
		SRAID.where( :status => "missing" ).map{|r| r.runid }
	end
	
	def reported
		SRAID.where( :status => "reported" ).map{|r| r.runid }
	end
	
	def compressed
		Dir.entries(@path["data"]).select{|fname| fname =~ /sra$/ }
	end
		
	def diskusage
		`df -h`.split("\n").select{|l| l =~ /home/ }.map{|l| l.split(/\s+/)}.flatten[4].to_i
	end
	
	def ftpsession
		`ps aux`.split("\n").select{|l| l =~ /lftp/ }.length
	end
	
	def jobsubmitted
		`qstat -u iNut`.split("\n").select{|l| l =~ /^[0-9]/}.length
	end	
end

class Operation
	def initialize(run_id)
		@run_id = run_id
		@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]
		@time = Time.now.strftime("%m%d%H%M%S")
	end
	
	def ftp_location
		exp_id = open(@path["run_members"]).readlines.select{|l| l =~ /^#{@run_id}/}.join.split("\t")[2]
		"ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{exp_id.slice(0,3)}/#{exp_id.slice(0,6)}/#{exp_id}/#{@run_id}"
	end
	
	def get_sra(location)
		log = @path["log"] + "/lftp_#{@run_id}_#{@time}.log"
		`lftp -c "open #{location} && get #{@run_id}.lite.sra -o #{@path["data"]}" >& #{log}`
	end
	
	def fastqc
		log = @path["log"] + "/fastqc_#{@run_id}_#{@time}.log"
		`qsub -o #{log} #{@path["lib"]}/fastqc.sh #{@run_id}`
	end
	
	def lftp_failed?
		log = Dir.glob(@path["log"] + "/lftp_#{@run_id}*.log").sort.last
		(log && open(log).read =~ /fail/)
	end
end

class ReportTwitter
	def initialize
		@tw = Twitter::Client.new
		@time = Time.now.strftime("%m/%d %H:%M:%S")
	end
	
	def report_stat(usage, session, job)
		message = <<-MESSAGIO.gsub(/^\s*/,"")
			@null #{@time}
			disk usage: #{usage}%
			#{session} ftp sessions
			#{job} job submitted
		MESSAGIO
		@tw.update(message)
	end
	
	def report_job(all, done, ongoing)
		message = <<-MESSAGIO.gsub(/^\s*/,"")
			@null #{@time}
			#{done.length} of runs finished,
			#{ongoing.length} of runs in progress.
			#{(done.length.to_f / all.length) * 100}%
		MESSAGIO
		@tw.update(message)
	end
	
	def report_error(missing_list)
		missing_list.join(",").scan(/.{100}/).each do |list|
			message = <<-MESSAGIO.gsub(/^\s*/,"")
				@null #{@time}
				error occurred:
				#{list.gsub(/,$/,"")}
			MESSAGIO
			@tw.update(message)
		end
	end
end

if __FILE__ == $0
	if ARGV.first == "--transmit"
		m = Monitoring.new
		task = m.task
		threads = []
		executed_id = []
		while m.diskusage <= 60 && m.ftpsession <= 12
			runid = task.shift
			executed_id.push(runid)
			op = Operation.new(runid)
			loc = op.ftp_location
			th = Thread.fork{ op.get_sra(loc) }
			threads << th
		end
		
		executed_id.each do |runid|
			record = SRAID.find_by_runid(runid)			
			record.status = "ongoing"
			record.save
		end
		
		# waiting for lftp sessions to finish
		threads.each{|th| th.join }

		executed_id.each do |runid|
			if Operation.new(runid).lftp_failed?
				record = SRAID.find_by_runid(runid)
				record.status = "missing"
				record.save
			end
		end

	elsif ARGV.first == "--fastqc"
		m = Monitoring.new
		litesra = m.compressed
		while m.diskusage <= 60 && !litesra.empty?
			runid = litesra.shift.gsub(".lite.sra","")
			op = Operation.new(runid)
			op.fastqc
			
			record = SRAID.find_by_runid(runid)
			record.status = "done"
			record.save
		end
	
	elsif ARGV.first == "--report"
		r = ReportTwitter.new
		m = Monitoring.new
		r.report_stat(m.diskusage, m.ftpsession, m.jobsubmitted)
		r.report_job(m.all, m.done, m.ongoing)
		
	elsif ARGV.first == "--errorreport"
		r = ReportTwitter.new
		m = Monitoring.new
		missing_list = m.missing
		r.report_error(missing_list)
		
		missing_list.each do |runid|
			record = SRAID.find_by_runid(runid)
			record.status = "reported"
			record.save
		end
		
	elsif ARGV.first == "--debug"
		m = Monitoring.new
	
		puts "number of task: #{m.task.length}"
		puts "available: #{m.available.length}"
		puts "ongoing: #{m.ongoing.uniq.length}"
		puts "missing: #{m.missing.length}"
		puts "reported: #{m.reported.length}"
		
	elsif ARGV.first == "--cleaning"
		m = Monitoring.new
		m.ongoing.each do |id|
			log = Dir.glob("/home/iNut/project/sra_qualitycheck/log/lftp_#{id}*").sort.last
			puts open(log).read
			if open(log).read =~ /failed/
				record = SRAID.find_by_runid(id)
				puts record.to_s
				record.status = "missing"
				record.save
				puts record.to_s
			end
		end
	end
end
