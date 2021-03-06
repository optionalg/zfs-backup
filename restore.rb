#!/usr/bin/env ruby19

require_relative 'commons.rb'

# The list of things we want to restore, with old and new location

# Get the list of files on the distant server.
dist_ls = 'ls ' << @dist_path
IO.popen(@sshCommand + [dist_ls], mode = "r") { |dist_io|
	distfiles = dist_io.readlines()

	@distsnaps = {}
	distfiles.each { |s|
		s2 = s.split('@')
		if (s2.size == 2) then
			@distsnaps[s2[0]] << s2[1].chomp
		elsif (s2.size == 3) then
			@distsnaps[s2[0]] = [s2[1]]
		end
	}
}

@fsrestorelist.each { |fs|
	puts "Plan for restoring " + fs[:old] + " into " + fs[:new]
	i = 0
	@distsnaps[fs[:old]].each { |snapshot|
		if (i == 0) then
			puts snapshot + '@full'
		else
			puts snapshot
		end
		i+=1
	}
	print "You have 10 seconds to abort"
	10.times { print '.'
		sleep 1
	}
	puts ''

	i = 0
	@distsnaps[fs[:old]].each { |snapshot|
		file = @dist_path + fs[:old] + '@' + snapshot 
		if i == 0 then 
			file = file + '@full'
		end
		i+=1
		dist_cmd = "cat " + file

		print "Restoring from " + file + '... '
		IO.popen(["zfs","receive",fs[:new]], mode='w') { |local_io|
			IO.popen(@sshCommand + [dist_cmd], mode='r') { |dist_io|
				while(true) do
					tmp = dist_io.read(@buffersize)
					if (tmp == nil) then
						print "!"
						break
					elsif (tmp.size < @buffersize) then
						print "<"
					elsif (tmp.size == @buffersize) then
						print "="
					end
					local_io.write tmp
					local_io.flush
				end
				Process.wait local_io.pid
				if ($?.exitstatus == 0) then
					puts "done."
				else
					puts "fail!"
				end
			}
		}
	}
}
