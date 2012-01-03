#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "json"
require "fileutils"

class OperationQC
	def loading
		task = open("./lib/task.json"){|f| JSON.load(f)}
		done = Dir.entries("./result")
		task - done
	end
	
	def diskcheck
		usage = `df -h | grep '/home' | gawk '{print $5}'`.to_i
		usage if usage <= 50
	end

	def ftpsession
		session = `ps aux | grep 'lftp' | wc -l`.to_i
		session -1 if session <= 9
	end

	def checkdumplist
		dumplist = `ls ./litesra | grep '.lite.sra$'`.split.map{|n| n.gsub(".lite.sra","")}
		!dumplist.empty?
	end

	def checkfqlist
		fqlist = `ls ./fq | grep '.fastq'`.split.map{|n| n.gsub(".bz2","").gsub(".gz","")}
		!fqlist.empty?
	end
end

if __FILE__ == $0
	if ARGV[0] == "--transmit"
		loading = OperationQC.loading
		while OperationQC.diskcheck && OperationQC.ftpsession
			id = loading.shift
			OperationQC.lftp(id)
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
