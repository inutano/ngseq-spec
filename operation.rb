#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "yaml"
require "json"
require "twitter"
require "fileutils"

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
		`df -h`.split("\n").select{|l| l=~ /home/ }.join.split(/\s+/).select{|w| w =~ /%/ }.join.gsub("%","").to_i
	end
	
	def ftpsession
		`ps aux`.split("\n").select{|l| l =~ /lftp/ }.length
	end
end

class Operation
	def initialize(run_id)
		@run_id = run_id
	end
	
	def ftp_location
		exp_id = open("./lib/SRA_Run_Members.tab").readlines.select{|l| l =~ /^#{@run_id}/}.join.split("\t")[2]
		exp_dbcenter = exp_id.slice(0,3)
		exp_header = exp_id.slice(0,6)
		"ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{exp_dbcenter}/#{exp_header}/#{exp_id}/#{@run_id}"
	end
	
	def get_sra(location)
		`lftp -c "open #{location} && pget -n 8 #{@run_id}.lite.sra -o ./data" > ./log/lftp_#{@run_id}_#{Time.now.strftime("%m%d%H%M%S")}.log`
		in_progress = open("./lib/in_progress.json"){|f| JSON.load(f)}
		open("./lib/in_progress.json","w"){|f| JSON.dump(in_progress.push(@run_id), f)}
	end
	
	def fastqc
		`qsub -o ./log/fastqc_#{@run_id}_#{Time.now.strftime("%m%d%H%M%S")}.log ./lib/fastqc.sh #{@run_id}`
	end
	
	def error_check
		log = open(Dir.glob("./log/#{@run_id}*.log")).read
		if log =~ /failed/m or log =~ /exception/m
			"error reported: #{@run_id}"
		end
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
	
	def report_stat(usage, session)
		message <<-MESSAGIO
@null #{@time}
disk usage: #{usage}%
#{session} ftp sessions
		MESSAGIO
		@tw.update(message)
	end
	
	def report_job(todo, done, in_progress)
		message <<-MESSAGIO
@null #{@time}
#{done.length} of runs finished,
#{in_progress.length} of runs in progress.
#{done.length / todo.length}%
		MESSAGIO
		@tw.update(message)
	end
	
	def report_error(error_message)
		message <<-MESSAGIO
@null #{@time}
#{error_message}
		MESSAGIO
		@tw.update(message)
	end
end

if __FILE__ == $0
	if ARGV[0] == "--transmit"
		m = Monitoring.new
		task = m.todo - m.done - m.in_progress
		threads = []
		while m.diskusage <= 60 && m.ftpsession <=12
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
		r.report_stat(m.diskusage, m.ftpsession)
		r.report_job(m.todo, m.done, m.in_progress)
		
	elsif ARGV[0] == "--cleaning"
		r = ReportTwitter.new
		m = Monitoring.new
		possibly_finished = m.in_progress - m.done # still in_progress list but have result directory
		possibly_finished.each do |run_id|
			error_message = Operation.new(run_id).error_check
			r.report_error(error_message) if error_message
		end
		
		finished = possibly_finished.delete_if{|run_id| Dir.glob("./result/#{run_id}/*fastqc.zip").empty? }
		open("./lib/in_progress.json","w"){|f| JSON.dump((m.in_progress - finished), f)}
	end
end
