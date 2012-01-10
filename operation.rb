#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "json"

class Operation
	def tasklist
		todo = open("./lib/todo.json"){|f| JSON.load(f)}
		done = Dir.entries("./result")
		open("./lib/in_progress.json"){|f| JSON.dump([],f)} if !File.exist?("./lib/in_progress.json")
		prog = open("./lib/in_progress.json"){|f| JSON.load(f)}
		todo - done - prog
	end
	
	def diskcheck
		usage = `df -h | grep 'home' | gawk '{print $5}'`.gsub("%","").chomp.to_i
		usage if usage <= 60
	end
	
	def ftpsession
		session = `ps aux | grep 'lftp' | wc -l`.to_i
		session -1 if session <= 12
	end

	def get_sra(run_id)
		exp_id = open("./lib/SRA_Run_Members.tab").readlines.select{|l| l =~ /^#{run_id}/}.join.split("\t")[2]
		exp_dbcenter = exp_id.slice(0,3)
		exp_header = exp_id.slice(0,6)
		location = "ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{exp_dbcenter}/#{exp_header}/#{exp_id}/#{run_id}"
		`lftp -c "open #{location} && pget -n 8 #{run_id}.lite.sra -o ./data"`
		in_progress = open("./lib/in_progress.json"){|f| JSON.load(f)}
		in_progress.push(run_id)
		open("./lib/in_progress.json","w"){|f| JSON.dump(in_progress, f)}
	end
	
	def fastqc(run_id)
		`qsub -o ./log/fastqc_#{run_id}_#{Time.now.strftime("%m%d%H%M%S")}.log ./lib/fastqc.sh #{run_id}`
	end
end	

if __FILE__ == $0
	if ARGV[0] == "--transmit"
		task = Operation.tasklist
		thraeds = []
		while Operation.diskcheck && Operation.ftpsession
			th = Thread.fork(task.shift){|run_id| Operation.get_sra(run_id) }
			threads << th
		end
		threads.each{|th| th.join}
	end
	
	if ARGV[0] == "--fastqc"
		compressed = Dir.entries("./data").select{|fname| fname =~ /sra$/ }
		while Operation.diskcheck
			run_id = compressed.shift.gsub(".lite.sra","")
			Operation.fastqc(run_id)
		end
	end
end
