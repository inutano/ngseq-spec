#!/usr/env/ruby
# -*- coding: utf-8 -*-

require "pp"

# check disk information
def diskcheck
	usage = `df -h | grep '/home' | gawk '{print $5}'`.to_i
	if usage <= 50
		usage
	end
end

def ftpsession
	session = `ps aux | grep 'lftp' | wc -l`.to_i
	if session <= 9
		session - 1
	end
end

def checkdumplist
	dumplist = `ls ./litesra | grep '.lite.sra$'`.split.map{|n| n.gsub(".lite.sra","")}
	!dumplist.empty?
end

def checkfqlist
	fqlist = `ls ./fq | grep '.fastq'`.split.map{|n| n.gsub(".bz2","").gsub(".gz","")}
	!fqlist.empty?
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
