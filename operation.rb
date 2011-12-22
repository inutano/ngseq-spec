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

while diskcheck && ftpsession
	puts "disk usage: #{diskcheck}"
	puts "number of lftp process: #{ftpsession - 1}"
	`./lftp.sh #{fileid}`
end
