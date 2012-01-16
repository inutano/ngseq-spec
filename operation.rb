#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "json"
require "yaml"
require "twitter"

class Monitoring
	def initialize
		@in_progress = "./lib/in_progress.json"
		open(@in_progress,"w"){|f| JSON.dump([],f)} if !File.exist?(@in_progress)
	end
	
	def todo
		open("./lib/todo.json"){|f| JSON.load(f)}
	end
	
	def done
		Dir.entries("./result")
	end
	
	def in_progress
		open(@in_progress){|f| JSON.load(f)}
	end
	
	def compressed
		Dir.entries("./data").select{|fname| fname =~ /sra$/ }
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
	
	def report_error(log)
		open(log).read =~ /error/ or /failed/
	end
end

class Operation
	def initialize(run_id)
		@run_id = run_id
		@time = Time.now.strftime("%m%d%H%M%S")
		@in_progress = "./lib/in_progress.json"
	end
	
	def ftp_location
		exp_id = open("./lib/SRA_Run_Members.tab").readlines.select{|l| l =~ /^#{@run_id}/}.join.split("\t")[2]
		exp_dbcenter = exp_id.slice(0,3)
		exp_header = exp_id.slice(0,6)
		"ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{exp_dbcenter}/#{exp_header}/#{exp_id}/#{@run_id}"
	end
	
	def get_sra(location)
		add = open(@in_progress){|f| JSON.load(f)}.push(@run_id)
		open(@in_progress,"w"){|f| JSON.dump(add, f)}
		`lftp -c "open #{location} && pget -n 8 -vvv --log=./log/lftp_#{@run_id}_#{@time}.log #{@run_id}.lite.sra -o ./data"`
	end
	
	def fastqc
		del = open(@in_progress){|f| JSON.load(f)}.delete_if{|id| id == @run_id}
		open(@in_progress){|f| JSON.dump(del, f)}
		`qsub -o ./log/fastqc_#{@run_id}_#{@time}.log ./lib/fastqc.sh #{@run_id}`
	end
	
end

class ReportTwitter
	def initialize
		y_config = YAML.load_file("./lib/config.yaml")
		Twitter.configure do |config|
			config.consumer_key = y_config["twitter"]["consumer_key"]
			config.consumer_secret = y_config["twitter"]["consumer_secret"]
			config.oauth_token = y_config["twitter"]["oauth_token"]
			config.oauth_token_secret = y_config["twitter"]["oauth_token_secret"]
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
	if ARGV[0] == "--transmit"
		m = Monitoring.new
		task = m.todo - m.done - m.in_progress
		threads = []
		while m.diskusage <= 60 && m.ftpsession <= 12
			op = Operation.new(task.shift)
			th = Thread.fork{ op.get_sra(op.ftp_location) }
			threads << th
		end
		threads.each{|th| th.join}
	
	elsif ARGV[0] == "--fastqc"
		m = Monitoring.new
		litesra = m.compressed
		while m.diskusage <= 60 && !litesra.empty?
			op = Operation.new(litesra.shift.gsub(".lite.sra",""))
			op.fastqc
		end
	
	elsif ARGV[0] == "--report"
		r = ReportTwitter.new
		m = Monitoring.new
		r.report_stat(m.diskusage, m.ftpsession, m.jobsubmitted)
		r.report_job(m.todo, m.done, m.in_progress)
		
	elsif ARGV[0] == "--errorreport"
		r = ReportTwitter.new
		m = Monitoring.new
		recent_log = Dir.glob("./log/*.log").select{|log_fname|  Time.now - File.mtime(log_fname) < 43200 }
		error_occurred = recent_log.select{|log_fname| m.report_error(log_fname)}.map{|log_fname| log_fname[/.RR[0-9]{6}/]}
		r.report_error(error_occured)
	end
end

