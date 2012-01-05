#!/usr/env/ruby　
# -*- coding: utf-8 -*-

require "json"
require "fileutils"

class Monitoring
	def initialize
		open("./lib/in_progress.json","w"){|f| JSON.dump([], f)} if !File.exist?("./lib/in_progress.json")
	end
	
	def tasklist
		todo = open("./lib/todo.json"){|f| JSON.load(f)}
		done = Dir.entries("./result")
		in_progress = open("./lib/in_progress.json"){|f| JSON.load(f)}
		todo - done - in_progress
	end
	
	def diskcheck
		usage = `df -h | grep 'home' | gawk '{print $5}'`.gsub("%","").chomp.to_i
		usage if usage <= 70
	end
	
	def ftpsession
		session = `ps aux | grep 'lftp' | wc -l`.to_i
		session -1 if session <= 9
	end
end

class QueueSubmission
	def initialize(id)
		@id = id
		@expid = open("./lib/SRA_Run_Members.tab").readlines{|l| l =~ /^#{id}/}.join.split("\t")[2]
		@exp_dbcenter = @expid.slice(0,3)
		@exp_header = @expid.slice(0,6)
	end
	
	def get_sra
		location = "ftp.ddbj.nig.ac.jp/ddbj_database/dra/sralite/ByExp/litesra/#{@exp_dbcenter}/#{@exp_header}/#{@expid}/#{@id}/#{@id}.lite.sra"
		`./lib/get_sra.sh #{location}`
		in_progress = open("./lib/in_progress.json"){|f| JSON.load(f)}
		in_progress.push(@id)
		open("./lib/in_progress.json","w"){|f| JSON.dump(in_progress, f)}
	end
	
	def get_fastq # will implement later
	end
	
	def unarchive
	end
	
	def fastqc
	end
end

if __FILE__ == $0
	if ARGV[0] == "--transmit"
		monitor = Monitoring.new
		task = monitor.tasklist
		while monitor.diskcheck && monitor.ftpsession
			id = task.shift
			queue = QueueSubmission.new(id)
			queue.get_sra
		end
	end
	
	if ARGV[0] == "--unarchive"
		compressed = Dir.entries("./data").select{|fname| fname =~ /sra/ }
		while OperationQC.diskcheck
			fname = compressed.shift
			OperationQC.unarchive(fname)
		end
	end
	
	if ARGV[0] == "--fastqc"
		decompressed = Dir.entries("./data").select{|fname| fname =~ /fastqc/ }
		while Operation.diskcheck
			fname = decompressed.shift
			OperationQC.fastqc(fname)
		end
	end
end




## ignition
while diskcheck && ftpsession
	puts "disk usage: #{diskcheck}"
	puts "number of lftp process: #{ftpsession - 1}"
	#`./lftp.sh -o ./litesra #{fileid}`
end

while checkdumplist
	puts "start fastq-dump for #{fileid}"
	#`qsub -j y -o log/fqdump_#{Time.now.strftime("%4Y%m%d%H%M%S")}.log fastqdump.sh`
end

while checkfqlist
	puts "start fastqc for #{fileid}"
	#`qsub -j y -o log/fastqc_#{Time.now.strftime("%4Y%m%d%H%M%S")}.log fastqc.sh`
end
