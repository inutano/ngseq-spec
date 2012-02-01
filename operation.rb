#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "yaml"
require "twitter"
require "active_record"

ActiveRecord::Base.establish_connection(
	:adapter => "sqlite3",
	:database => "./lib/production.sqlite3"
)

class SRAID < ActiveRecord::Base
end

class Monitoring
	def initialize
		@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]
	end
	
	def paper_published
		SRAID.where( :status => "available", :paper => true ).map{|r| r.runid }
	end

	def paper_unpublished
		SRAID.where( :status => "available", :paper => false ).map{|r| r.runid }
	end
	
	def done
		SRAID.where( :status => "done" ).map{|r| r.runid }
	end
	
	def ongoing
		SRAID.where( :status => "ongoing" ).map{|r| r.runid }
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
		@time = Time.now.strftime("%m%d%H%M%S")
		@path = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["path"]
	end
	
	def ftp_location
		exp_id = open(@path["run_members"]).readlines.select{|l| l =~ /^#{@run_id}/}.join.split("\t")[2]
		exp_dbcenter = exp_id.slice(0,3)
		exp_header = exp_id.slice(0,6)
		"ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{exp_dbcenter}/#{exp_header}/#{exp_id}/#{@run_id}"
	end
	
	def get_sra(location)
		record = SRAID.find_by_runid(@runid)
		record.status = "ongoing"
		record.save
		log = "#{@path["log"]}/lftp_#{@run_id}_#{@time}.log"
		`lftp -c "open #{location} && pget -n 8 #{@run_id}.lite.sra -o #{@path["data"]}" >& #{log}`
	end
	
	def fastqc
		log = "#{@path["log"]}/fastqc_#{@run_id}_#{@time}.log"
		`qsub -o #{log} #{@path["lib"]}/fastqc.sh #{@run_id}`
		record = SRAID.find_by_runid(@runid)
		record.status = "done"
		record.save
	end

	def failure?
		# if at least one log includes "error" or "failed", return true.
		!Dir.glob("#{@path["log"]}/*#{@run_id}*.log").map{|l| open(l).read}.select{|t| t =~ /error/ or t =~ /fail/}.empty?
	end
end

class ReportTwitter
	def initialize
		tw_conf = YAML.load_file("/home/iNut/project/sra_qualitycheck/lib/config.yaml")["twitter"]
		Twitter.configure do |config|
			config.consumer_key = tw_config["consumer_key"]
			config.consumer_secret = tw_conf["consumer_secret"]
			config.oauth_token = tw_conf["oauth_token"]
			config.oauth_token_secret = tw_conf["oauth_token_secret"]
		end
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
	
	def report_job(todo, done, in_progress)
		message = <<-MESSAGIO.gsub(/^\s*/,"")
			@null #{@time}
			#{done.length} of runs finished,
			#{in_progress.length} of runs in progress.
			#{done.length / todo.length}%
		MESSAGIO
		@tw.update(message)
	end
	
	def report_error(error_occurred_list)
		error_occurred_list.join(",").scan(/.{100}/).each do |list|
			message = <<-MESSAGIO.gsub(/^\s*/,"")
				@null #{@time}
				error occurred:
				#{list}
			MESSAGIO
			@tw.update(message)
		end
	end
end

if __FILE__ == $0
	if ARGV.first == "--transmit"
		m = Monitoring.new
		task = m.paper_published
		if task.empty?
			task = m.paper_unpublished
		end
		threads = []
		while m.diskusage <= 60 && m.ftpsession <= 12
			op = Operation.new(task.shift)
			th = Thread.fork{ op.get_sra(op.ftp_location) }
			threads << th
		end
		threads.each{|th| th.join}
	
	elsif ARGV.first == "--fastqc"
		m = Monitoring.new
		litesra = m.compressed
		while m.diskusage <= 60 && !litesra.empty?
			op = Operation.new(litesra.shift.gsub(".lite.sra",""))
			op.fastqc
		end
	
	elsif ARGV.first == "--report"
		r = ReportTwitter.new
		m = Monitoring.new
		r.report_stat(m.diskusage, m.ftpsession, m.jobsubmitted)
		r.report_job(m.todo, m.done, m.ongoing)
		
	elsif ARGV.first == "--errorreport"
		r = ReportTwitter.new
		m = Monitoring.new
		recent_log = Dir.glob("/home/iNut/project/sra_qualitycheck/log/*.log").select{|log_fname| Time.now - File.mtime(log_fname) < 43200 }
		error_occurred = recent_log.map{|log_fname| log_fname[/.RR[0-9]{6}/]}.select{|id| Operation.new(id).failure? }
		r.report_error(error_occured)
	end
end

