#Methods that are used in multiple scripts.
#require "param_ils_helper.rb" # just for tmpdir

require "algo_specifics.rb"

def tmpdir()
	if is_win
		dir = "C:\\tmp\\"
		Dir.mkdir( dir ) unless File.exist?(dir) and File.stat(dir).directory?
		return dir
	else
		if (@temporary_output_dir.length > 0)
			return @temporary_output_dir
		else
			return "/tmp/"
		end
	end
end

def float_regexp()
	return '[+-]?\d+(?:\.\d+)?(?:[eE][+-]\d+)?';
end

def is_win()
	return RUBY_PLATFORM =~ /(win|w)32$/
end

unless $work_dir
	if is_win
		filename = "pwd_#{rand}.out"
		cmd = "dir | find \"Directory\" > #{filename}"
		system cmd
		File.open(filename){|file|
			line = file.gets
			line =~ /Directory of (.*)/
			$work_dir = $1
		}
		File.delete(filename)
#		puts $work_dir
	else
		File.popen("pwd"){|file| $work_dir = file.gets.chomp}
	end
end
$script_dir_for_cluster ="/.autofs/csother/ubccsprojectarrow/hutter/ParamILS/scripts/"


###########################################################################
#Perform a 2-sided Wilcoxon paired sign rank test. Return value: [p_value, median < 0]
###########################################################################
def wilcoxon_test(alpha, x, y)
	minlen = [x.length, y.length].min

	#=== With less than six observations you can't determine significance, so return right away.
	return [false, -1] if minlen < 6

	#=== Compute difference of the two vectors.
	diff = []
	for i in 0...minlen
		diff[i] = x[i] - y[i]
	end

	#=== Construct the file holding the R script.
	r_command_filename = "/tmp/tmp_r_cmd_#{random_number_without_rand}"
	r_result_filename = "/tmp/tmp_r_result_#{random_number_without_rand}"
	array_string = diff.join(", ")
	File.open(r_command_filename, "w"){|f|
		f.puts "diff<-c(#{array_string})"
		f.puts "p_value<-wilcox.test(diff, exact=FALSE)$p.value"
		f.puts "write(p_value, '#{r_result_filename}')"
	}

	#=== Call the R script and read the results from the result file.
	system "R CMD BATCH #{r_command_filename}"
	File.delete(r_command_filename)
	pval = -1
	File.open(r_result_filename){|f| pval = f.gets.chomp.to_f}
	File.delete(r_result_filename)
	dir, cmd_filename = File.split(r_command_filename)
	File.delete(cmd_filename + ".Rout")

	print diff.sort{|x,y| x.abs <=> y.abs}.map{|x| x<0 ? "-" : (x==0 ? "0" : "+" )}.join(" ")
	puts "  #{pval}"

	require "stats_ils.rb"
#	puts "Testing [#{x.join(", ")}] vs [#{y.join(", ")}]: pval=#{pval}"
	return [pval < alpha/2, pval]  #two-sided test, so divide alpha by 2.
end

###########################################################################
#Sample from an exponential distribution.
###########################################################################
def generate_samples_from_exponential(median, numSamples)
#=== Simple ruby wrapper that takes the mean of an exponential distribution and generates a sample by calling a built-in function in python.
#One sample works from the command line:	cmd = "python -c \"import random; print random.expovariate(#{1/mean})\""
	mean = 1/Math.log(2) * median
	cmd = "python ../scripts/exponential_samples.pyt #{1/mean} #{numSamples}"
	results = []
	File.popen(cmd){|f| results = f.readlines}
	return results.map{|x|x.chomp.to_f}
end


###########################################################################
# Run a set of commands on the cluster.
###########################################################################
def runCommandsOnCluster(commands, waitToFinish=false, name = "", output=false, priorityclass="eh")
	t=Time.now
	datetime = t.strftime("%Y-%m-%d %H-%M-%S") # YYYY-MM-DD HH:MM:SS
	todoFilename = "#{tmpdir}#{name}-tmpAlgosToRun-#{datetime}-#{random_number_without_rand}".gsub(/ /,"")
	File.open(todoFilename, "w"){|f|
		for command in commands
			f.puts "#{command}"
		end
	}

	shFilename = "#{tmpdir}#{name}-tmpShFile-#{datetime}-#{random_number_without_rand}.sh".gsub(/ /,"")
	#puts "todoFilename: #{todoFilename}, shFilename: #{shFilename}"
	File.open(shFilename, "w"){|f|
		f.puts "#!/bin/sh"
		f.puts "echo \"Here's what we know from the SGE environment\""
		f.puts "echo HOME=$HOME"
		f.puts "echo USER=$USER"
		f.puts "echo JOB_ID=$JOB_ID"
		f.puts "echo JOB_NAME=$JOB_NAME"
		f.puts "echo HOSTNAME=$HOSTNAME"
		f.puts "echo SGE_TASK_ID=$SGE_TASK_ID"
		f.puts "echo STDOUT_FILE=$stdout"
		f.puts "echo STDERR_FILE=$stderr"
		f.puts "echo jobin=$jobin"
		f.puts "echo jobout=$jobout"
		f.puts "echo joberr=$joberr"
		f.puts "RUBYLIB=/ubc/cs/home/h/hutter/arrowspace/ParamILS/scripts:/cs/public/lib/pkg/ruby-1.8.2/lib/ruby/site_ruby/1.8:/.autofs/binaries/cspubliclib/pkg/ruby-mysql/mysql-ruby-2.7.1"
		f.puts "export RUBYLIB"
		#/cs/local/bin in the PATH is absolutely necessary for JAVA, get java.lang.NoClassDefFoundError otherwise !!!
		f.puts "PATH=/cs/beta/lib/pkg/sge-6.0u7_1/bin/lx24-x86:/cs/local/bin:/cs/local/generic/bin:/cs/local/bin/pbm+:/usr/local/bin:/usr/bin/X11:/bin:/usr/ucb:/usr/bin:/ubc/cs/home/h/hutter/bin:/ubc/cs/home/h/hutter/bin/ix86linux:/opt/kde3/bin:/opt/gnome/bin:/usr/games:/usr/sbin:/sbin:/usr/lib/java/bin:/cs/public/bin:/cs/public/generic/bin:/cs/public/bin/xwindows:/ubc/cs/home/h/hutter/ruby-scripts:/ubc/cs/home/h/hutter/ruby-scripts/autoparam/:/ubc/cs/home/h/hutter/bioinf/impl/scripts:/ubc/cs/home/h/hutter/lib:/ubc/cs/home/h/hutter/mcmc/bin/:/ubc/cs/home/h/hutter/arrowspace/ParamILS/testbed/scripts:/ubc/cs/home/h/hutter/arrowspace/ParamILS/scripts:/cs/public/lib/pkg/ruby-1.8.2/lib/ruby/site_ruby/1.8:/.autofs/binaries/cspubliclib/pkg/ruby-mysql/mysql-ruby-2.7.1:/ubc/cs/home/h/hutter/ant/bin:$SGE_BINARY_PATH:$PATH"
		f.puts "export PATH"
		f.puts "ILM_LICENSE_FILE=/cs/local/generic/lib/pkg/ilog/ilm/access.ilm"
		f.puts "ILOG_LICENSE_FILE=/cs/local/generic/lib/pkg/ilog/ilm/access.ilm"
		if output
			f.puts "#\$ -o /ubc/cs/home/h/hutter/arrowspace/sgeout -e /ubc/cs/home/h/hutter/arrowspace/sgeout"
		else
			f.puts "#\$ -o /dev/null -e /dev/null"
		end
		f.puts "line=`head -n $SGE_TASK_ID #{todoFilename} | tail -1`	# Get line of todoFilename."

		cmd = "cd #{$work_dir};"
		f.puts "echo Calling: #{cmd}  #output"
		f.puts cmd

		#cmd= "pwd"
		#f.puts "echo Calling: #{cmd}  #output"
		#f.puts cmd
		cmd= "$line"
		f.puts "echo Calling: #{cmd}  #output"
		f.puts cmd
	}

	if commands.length > 0
		consumables = ""
		consumables += " -l dbheavy=1" if $dbheavy
		consumables += " -l db=1" if $dblight
		consumables += " -l cplex=1" if $cplex
#		sge_cmd = "qsub -cwd -m n -t 1-#{commands.length} -l memheavy=1 -P eh #{consumables} #{shFilename}"
		sge_cmd = "qsub -cwd -m n -t 1-#{commands.length} -P #{priorityclass} #{consumables} #{shFilename}"
	end

	puts sge_cmd
	puts shFilename
	jobid = nil
	#=== Start job and remember job id.
	File.popen(sge_cmd){|sge_response|
		line = sge_response.gets
		puts line
		if line =~ /Your job (\d+)\./
			jobid = $1.to_i
		elsif line =~ /Your job (\d+) \(/
			jobid = $1.to_i
		end
	}
##	File.delete(todoFilename)
#	File.delete(shFilename)

	if waitToFinish
	#=== Sleep until job done.
		puts "Waiting for SGE job #{jobid} to finish. TODO filename = #{todoFilename}"
		still_running = true
		while still_running
			sleep(10)
			still_running = false
			File.popen("qstat"){|qstat_output|
				while line = qstat_output.gets
					still_running = true if line =~ /^\s*#{jobid}\s*/
				end
				puts "Waiting for SGE job #{jobid} to finish. TODO filename = #{todoFilename}"
			}
		end
	end
	return [jobid, todoFilename]
end

###########################################################################
# Run a set of commands on the cluster, as a single job (not an array job). For commands that are too fast for the scheduler !
###########################################################################
def runCommandsOnClusterOneJob(commands, waitToFinish=false, name = "", output=false, priorityclass="eh")
	t=Time.now
	datetime = t.strftime("%Y-%m-%d %H-%M-%S") # YYYY-MM-DD HH:MM:SS
	todoFilename = "#{tmpdir}#{name}-tmpAlgosToRun-#{datetime}-#{random_number_without_rand}".gsub(/ /,"")
	File.open(todoFilename, "w"){|f|
		for command in commands
			f.puts "#{command}"
		end
	}

	shFilename = "#{tmpdir}#{name}-tmpShFile-#{datetime}-#{random_number_without_rand}.sh".gsub(/ /,"")
	#puts "todoFilename: #{todoFilename}, shFilename: #{shFilename}"
	File.open(shFilename, "w"){|f|
		f.puts "#!/bin/sh"
		f.puts "echo \"Here's what we know from the SGE environment\""
		f.puts "echo HOME=$HOME"
		f.puts "echo USER=$USER"
		f.puts "echo JOB_ID=$JOB_ID"
		f.puts "echo JOB_NAME=$JOB_NAME"
		f.puts "echo HOSTNAME=$HOSTNAME"
		f.puts "echo SGE_TASK_ID=$SGE_TASK_ID"
		f.puts "echo STDOUT_FILE=$stdout"
		f.puts "echo STDERR_FILE=$stderr"
		f.puts "echo jobin=$jobin"
		f.puts "echo jobout=$jobout"
		f.puts "echo joberr=$joberr"
		f.puts "RUBYLIB=/ubc/cs/home/h/hutter/arrowspace/ParamILS/scripts:/cs/public/lib/pkg/ruby-1.8.2/lib/ruby/site_ruby/1.8:/.autofs/binaries/cspubliclib/pkg/ruby-mysql/mysql-ruby-2.7.1"
		f.puts "export RUBYLIB"
		#/cs/local/bin in the PATH is absolutely necessary for JAVA, get java.lang.NoClassDefFoundError otherwise !!!
		f.puts "PATH=/ubc/cs/home/h/hutter/arrowspace/ParamILS/scripts:/cs/beta/lib/pkg/sge-6.0u7_1/bin/lx24-x86:/cs/local/bin:/cs/local/generic/bin:/cs/local/bin/pbm+:/usr/local/bin:/usr/bin/X11:/bin:/usr/ucb:/usr/bin:/ubc/cs/home/h/hutter/bin:/ubc/cs/home/h/hutter/bin/ix86linux:/opt/kde3/bin:/opt/gnome/bin:/usr/games:/usr/sbin:/sbin:/usr/lib/java/bin:/cs/public/bin:/cs/public/generic/bin:/cs/public/bin/xwindows:/ubc/cs/home/h/hutter/ruby-scripts:/ubc/cs/home/h/hutter/ruby-scripts/autoparam/:/ubc/cs/home/h/hutter/bioinf/impl/scripts:/ubc/cs/home/h/hutter/lib:/ubc/cs/home/h/hutter/mcmc/bin/:/ubc/cs/home/h/hutter/arrowspace/ParamILS/scripts:/cs/public/lib/pkg/ruby-1.8.2/lib/ruby/site_ruby/1.8:/.autofs/binaries/cspubliclib/pkg/ruby-mysql/mysql-ruby-2.7.1:/ubc/cs/home/h/hutter/ant/bin:$SGE_BINARY_PATH:$PATH"
		f.puts "export PATH"
		if output
			f.puts "#\$ -o /ubc/cs/home/h/hutter/arrowspace/sgeout_onejob -e /ubc/cs/home/h/hutter/arrowspace/sgeout_onejob"
		else
			f.puts "#\$ -o /dev/null -e /dev/null"
		end
		cmd = "cd #{$work_dir};"
		f.puts "echo Calling: #{cmd}  #output"
		f.puts cmd

		f.puts "for ((  i = 0 ;  i <= #{commands.length};  i++  ))"
		f.puts "do"
		f.puts "line=`head -n $i #{todoFilename} | tail -1`	# Get line of todoFilename."

		#cmd= "pwd"
		#f.puts "echo Calling: #{cmd}  #output"
		#f.puts cmd
		cmd= "$line"
		f.puts "echo Calling: #{cmd}  #output"
		f.puts cmd

		f.puts "done"
	}

	if commands.length > 0
		consumables = ""
		consumables += " -l dbheavy=1" if $dbheavy
		consumables += " -l db=1" if $dblight
		consumables += " -l cplex=1" if $cplex
#		sge_cmd = "qsub -cwd -m n -t 1-#{commands.length} -l memheavy=1 -P eh #{consumables} #{shFilename}"
		sge_cmd = "qsub -cwd -m n -t 1-1 -P #{priorityclass} #{consumables} #{shFilename}"
	end

	puts sge_cmd
	puts shFilename
	jobid = nil
	#=== Start job and remember job id.
	File.popen(sge_cmd){|sge_response|
		line = sge_response.gets
		puts line
		if line =~ /Your job (\d+)\./
			jobid = $1.to_i
		elsif line =~ /Your job (\d+) \(/
			jobid = $1.to_i
		end
	}
##	File.delete(todoFilename)
#	File.delete(shFilename)

	if waitToFinish
	#=== Sleep until job done.
		puts "Waiting for SGE job #{jobid} to finish. TODO filename = #{todoFilename}"
		still_running = true
		while still_running
			sleep(10)
			still_running = false
			File.popen("qstat"){|qstat_output|
				while line = qstat_output.gets
					still_running = true if line =~ /^\s*#{jobid}\s*/
				end
				puts "Waiting for SGE job #{jobid} to finish. TODO filename = #{todoFilename}"
			}
		end
	end
	return [jobid, todoFilename]
end



###########################################################################
# Run a set of algorithm runs the simple way (directly on the local machine).
###########################################################################
def runAlgosLocally(algosToRun)
	for algoToRun in algosToRun
		runalgo(algoToRun[0], algoToRun[1])
		#system "ruby #{$script_dir_for_cluster}/runalgo.rb #{algoToRun[0]} #{algoToRun[1]}"
	end
end

###########################################################################
# Run a set of algorithm runs on the cluster.
###########################################################################
def runAlgosOnCluster(algosToRun, waitToFinish=false, algo = "", output=false, priorityclass = "eh", oneJob=false)
	commandsToRun = []
	for algoToRun in algosToRun
	#cd #{$work_dir};
		commandsToRun << "/usr/bin/ruby #{$script_dir_for_cluster}/runalgo.rb #{algoToRun[0]} #{algoToRun[1]}"
	end
	if oneJob
		runCommandsOnClusterOneJob(commandsToRun, waitToFinish, algo, output, priorityclass)
	else
	        runCommandsOnCluster(commandsToRun, waitToFinish, algo, output, priorityclass)
        end
end


###########################################################################
# Run a set of algorithm runs with the jobserver.
###########################################################################
def runAlgosWithJobserver(algosToRun)
	require 'jobserver'

	#=== Put jobs in the queque.
	myJobQueue = []
	for algoToRun in algosToRun
		cmd = "cd #{$work_dir}; /usr/bin/ruby #{$script_dir_for_cluster}/runalgo.rb #{algoToRun[0]} #{algoToRun[1]}"
		myJobQueue << Job.new(:name=>"ALGORUN_CONFIG #{algoToRun[0]}, seed #{algoToRun[1]}.", :client_command=>cmd)
	end

	if myJobQueue.length > 0
		#=== Configure jobserver.
		Job.nicelevel = nil # nice doesn't work at UBC
		server = JobServer.new(myJobQueue, $work_dir, 0)

		hosts =  %w{arrow41 arrow42 arrow43 arrow44 arrow45 arrow46 arrow47 arrow48 arrow49 arrow50}
#		hosts =  %w{arrow25}
#		hosts =  %w{arrow01 arrow02 arrow03 arrow04 arrow05 arrow06 arrow07 arrow08 arrow09 arrow10 arrow11 arrow12 arrow13 arrow14 arrow15 arrow16 arrow17 arrow18 arrow19 arrow20 arrow21 arrow22 arrow23 arrow24 arrow25 arrow26 arrow27 arrow28 arrow29 arrow30 arrow31 arrow32 arrow33 arrow34 arrow35 arrow36 arrow37 arrow38 arrow39 arrow40 arrow41 arrow42 arrow43 arrow44 arrow45 arrow46 arrow47 arrow48 arrow49}

		while not hosts.empty? # Add workers in randomized order, so not everyone pounds on the last worker.
			randind = (random_number_without_rand*hosts.length).floor
			#randind = rand(hosts.length)
			host = hosts[randind]
			hosts.delete_at(randind)
			server.add_ssh_worker(host, $work_dir, 2)
		end

		#=== Dump out statistics on the progress every 5 seconds.
		server.dumpStatistics #($statsfile, 5)

		#=== Wait until all jobs have finished.
		server.serve
	end
end


###########################################################################
# Gets the results for running algo on multiple instances - keeps track of which runs are used and does not reuse them !
###########################################################################
def getAlgoResultsForInstsAndParams(algo, instanceAndParamsHash, cutoff_time, cutoff_length, sorted_instances, oncluster=0, db=false)
#	puts "getAlgoResultsForInstsAndParams begin"
#	$stdout.flush

	unless db
		#=== Do runs, save in instanceAndParamsHash, return
		for instance in instanceAndParamsHash.keys
			for param_string in instanceAndParamsHash[instance].keys
				stripped_state_int = instanceAndParamsHash[instance][param_string]["params"]
				params = $stripped_int_to_stripped_state[stripped_state_int]
				rest_of_instance_specific_info = instanceAndParamsHash[instance][param_string]["rest"]
				seeds = instanceAndParamsHash[instance][param_string]["seeds"]

				instanceAndParamsHash[instance][param_string]["results"] = {}
				for seed in seeds
					successful = false
					t = Time.now
					datetime = t.strftime("%Y-%m-%d %H:%M:%S") # YYYY-MM-DD HH:MM:SS
					algo_output_file = "#{tmpdir}tmp-#{datetime}-#{random_number_without_rand}".gsub(/ /,"")
					if is_win
						algo_output_file = algo_output_file.gsub(/(\d):/, "#{$1}_")
					end

					paramstring = params.keys.map{|x| "-#{x} #{params[x]}"}.join(" ")
					cmd = "#{algo} #{instance} \"#{rest_of_instance_specific_info}\" #{cutoff_time} #{cutoff_length} #{seed} #{paramstring} > #{algo_output_file}"

					try = 1
					begin
						puts "  Trial #{try} for calling: #{cmd}"
						puts "Executing cmd: #{cmd}"

						runresult = system(cmd)

						File.open(algo_output_file){|file|
							while line = file.gets
								if line =~ /Result for ParamILS: / or line =~ /Result for SMAC: /
									runlog cmd
									runlog line.strip
									runlog "\n"

									line = line.sub(/Result for ParamILS: /,"")
									line = line.sub(/Result for SMAC: /,"")
									puts "Result: #{line.strip}"

									solved, runtime, runlength, best_sol, seed, additionalRunData = line.split(",").map!{|x|x.strip}

									instanceAndParamsHash[instance][param_string]["results"][seed.to_i] = [solved, runtime.to_f, runlength.to_i, best_sol.to_f, seed.to_i]
									successful  = true
									break
								end
							end
							raise "No result in result file of #{cmd}:\n#{algo_output_file}" if instanceAndParamsHash[instance][param_string]["results"].empty?
						}
						File.delete(algo_output_file)

						raise "Call unsuccessful: #{cmd}" unless successful
						#raise "Solver crashed on #{cmd}" if instanceAndParamsHash[instance][param_string]["results"][seed.to_i][0] == "CRASHED"
						raise "No solver result for #{cmd}" unless instanceAndParamsHash[instance][param_string]["results"][seed.to_i][0]

						if (instanceAndParamsHash[instance][param_string]["results"][seed.to_i][0] == "ABORT")
							puts "ERROR: Target Algorithm signalled that we should abort"
							$stderr.puts "ERROR: Target Algorithm signalled that we should abort"
							puts "ERROR: Run returned ABORT status. ParamILS terminating as requested..."
							$stderr.puts "ERROR: Run returned ABORT status. ParamILS terminating as requested..."

							Kernel::exit(2)
						end

						if (instanceAndParamsHash[instance][param_string]["results"][seed.to_i][0] == "CRASHED")
							puts "WARNING: Run crashed."
						end

					# CF: Removing this because any algorithm with crashing configurations will waste all of its time here.
					#rescue #=== Catch error due to files disappearing or something similar
					#	if $!.to_s =~ /No such file or directory/ or $!.to_s =~ /Input\output error/ or $!.to_s =~ /Stale NFS file handle/ or (not runresult) or (not successful) or $!.to_s =~ /crashed/ or $!.to_s =~ /No solver result/
					#		try += 1
					#		sleep(10)
					#		retry if try < 500
					#   else
					#		raise
					#	end


					#FH on 3 June, 2014: to guard against bad wrappers, I at least put in some functionality to treat this as a CRASHED run and continue the configuration run instead of just exiting.
					rescue
						puts "Caught exception when executing target algorithm: #{$!.to_s}. Counting the target algorithm run as CRASHED with runtime #{cutoff_time + 0.01} and solution quality 1e100."
						instanceAndParamsHash[instance][param_string]["results"][seed.to_i] = ["CRASHED", cutoff_time + 0.01, cutoff_length, 1e100, seed.to_i]
					end
				end
			end
		end
		return true #results ready
	end

	begin
		if $fakedCensoringForExactSameResults
			#========================================= FOR DEBUGGING THE PRUNING (CPU time is not deterministic with the same seed :-( )
			#=== Temporary, for debugging, let everyone use the exact same results from the DB, but keep all entries as if used with the real time.
			real_cutoff_time = cutoff_time
			cutoff_time = [cutoff_time, $fakedCensoringRuntime].max
		end

		#=== Collect runs I still have to do.
		algosToRun = []
		for instance in sorted_instances
			next unless instanceAndParamsHash.key?(instance) # If not all the original instances are in the instanceHash
			for param_string in instanceAndParamsHash[instance].keys
				stripped_state_int = instanceAndParamsHash[instance][param_string]["params"]
	#			puts "getAlgoResultsForInstsAndParams algorun_config_id. Instance #{instance}, #{params.length} params #{params.keys.join(" ")}"
	#			$stdout.flush

				rest_of_instance_specific_info = instanceAndParamsHash[instance][param_string]["rest"]
				qual = 0
				algorun_config_id = get_algorun_config_id(algo, stripped_state_int, instance, qual, cutoff_time, cutoff_length)[0]
	#			puts "getAlgoResultsForInstsAndParams after algorun_config_id"
	#			$stdout.flush

				instanceAndParamsHash[instance][param_string]["algorun_config_id"] = algorun_config_id
				seeds = instanceAndParamsHash[instance][param_string]["seeds"].map{|x| x.to_i}
				computedSeeds = computedSeeds(algorun_config_id)

				#=== Make sure not to use runs that were used before.
				neededSeeds = seeds - computedSeeds # Ruby set difference.
				unless neededSeeds.empty?
					for seed in neededSeeds
						algosToRun << [algorun_config_id, seed]
					end
				end
				puts "Need #{neededSeeds.length} new runs. (Want #{seeds.length}, have #{computedSeeds.length}, #{(seeds&computedSeeds).length} matching) for algorun_config_id #{algorun_config_id}"
			end
		end

		#=== Remove duplicates. (Can't use uniq! because array entries)
		uniqAlgosToRun = []
		conf_seed_hash = Hash.new
		for algoToRun in algosToRun
			conf, seed = algoToRun
			if conf_seed_hash.key?(conf)
				next if conf_seed_hash[conf].include?(seed)
				conf_seed_hash[conf] << seed
			else
				conf_seed_hash[conf] = [seed]
			end
			uniqAlgosToRun << algoToRun
		end

		unless uniqAlgosToRun.empty?
			if oncluster==1 or oncluster=="1"
				runAlgosOnCluster(uniqAlgosToRun, false, algo)
			elsif oncluster==2 or oncluster=="2"
				runAlgosWithJobserver(uniqAlgosToRun)
			elsif oncluster==3 or oncluster=="3"
				runAlgosOnCluster(uniqAlgosToRun, true, "LS"+algo, true)
			elsif oncluster==4 or oncluster=="4"
				runAlgosOnCluster(uniqAlgosToRun, true, "LS"+algo, true, "eh2 -q arrowtest.q")
			elsif oncluster==8 or oncluster=="8"
				runAlgosOnCluster(uniqAlgosToRun, false, "one"+algo, false, "eh", true)
			else
				runAlgosLocally(uniqAlgosToRun)
			end
		end

		#=== Read all results if they are ready at this point (i.e. if nothing has to be run using SGE).
		if algosToRun.length == 0 or not (oncluster=="1" or oncluster == 1 or oncluster==8 or oncluster=="8")
			for instance in instanceAndParamsHash.keys
	#			puts "Read run results for instance #{instance}"
				for param_string in instanceAndParamsHash[instance].keys
	#				puts "   Read run results for param_string #{param_string}"
					algorun_config_id = instanceAndParamsHash[instance][param_string]["algorun_config_id"]
					seeds = instanceAndParamsHash[instance][param_string]["seeds"]

					results = readAlgoResults(algorun_config_id, seeds)
					unless results.class.to_s == "Array"
						raise "Results #{results} must be an array. Instance #{instance}, param_string #{param_string}"
					end
					for result in results
						raise "at least one result for algorun_config_id #{algorun_config_id} is nil" unless result
					end
					unless results[0].class.to_s == "Array"
						p results
						p seeds

						p "doing again: readAlgoResults(#{algorun_config_id}, #{seeds})"
						a = readAlgoResults(algorun_config_id, seeds)
						p "New result"
						p a
						raise "results[0] #{results[0]} must be an array. Instance #{instance}, param_string #{param_string}"
					end

					instanceAndParamsHash[instance][param_string]["results"] = Hash.new
					for seed in seeds
						res = results.shift

		if $fakedCensoringForExactSameResults
							#========================================= FOR DEBUGGING THE PRUNING (CPU time is not absolutely deterministic even with the exact same trajectory :-( )
							#=== If the run is too long and would've timed out, put in the real result.
							if res[1] > real_cutoff_time
								res[0] = "TIMEOUT"
								res[1] = real_cutoff_time
							end
		end
						instanceAndParamsHash[instance][param_string]["results"][seed] = res
					end
				end
			end
			return true #results ready
		end
		return false #results not ready yet
	rescue
		p "WARNING: run crashed"
		puts $!.to_s
		sleep(10)
		retry
	end
end


###########################################################################
# The new and improved version of running algorithms: we get a list of entry_param pairs, run them all (as an instanceAndParamsHash) and directly modify the entries.
# If a run has already been performed with a lower cutoff and was successful, then just copy that run and don't rerun it! Of course, also reuse runs with the same cutoff.
###########################################################################
def getAlgoResultsForEntryParamsPairs(algo, entry_paramint_pairs, cutoff_time, cutoff_length, oncluster=0, db=true)
	$total_cputime = 0 unless $total_cputime
	$totalEvaluationCount =0 unless $totalEvaluationCount
	#=== Check which of the entry param pairs we actually need to run.
#	puts "Collect runs I need to do."
	entry_paramints_to_run = []
	count = 1
	for entry_paramint in entry_paramint_pairs
		puts "count #{count}/#{entry_paramint_pairs.length}" if count.divmod(100)[1]==0
		count += 1
		entry, stripped_state_int = entry_paramint

#p "entry"
#p entry
#p params
#$stdout.flush

		if entry["resultForState"].key?(stripped_state_int)
			#=== If a successful result for a lower cutofftime exist don't rerun it, either.
			lower_cutofftimes = entry["resultForState"][stripped_state_int].keys
			for lower_cutoff in lower_cutofftimes.sort
				if lower_cutoff > cutoff_time
					# raise "We should NEVER perform a run with shorter cutoff than before"
					if entry["resultForState"][stripped_state_int][lower_cutoff][0] == "TIMEOUT"
						#=== If the run had a longer runtime and still timed out, copy the run and adapt its runtime.
						entry["resultForState"][stripped_state_int][cutoff_time] = entry["resultForState"][stripped_state_int][lower_cutoff].dup
						entry["resultForState"][stripped_state_int][cutoff_time][1] = cutoff_time
						break
					else
						#=== If the run had a longer runtime and solved the instance:
						if entry["resultForState"][stripped_state_int][lower_cutoff][1] <= cutoff_time
							#=== a) It solved the instance with a shorter runtime than we ask for, copy the run.
							entry["resultForState"][stripped_state_int][cutoff_time] = entry["resultForState"][stripped_state_int][lower_cutoff].dup
						else
							#=== a) It solved the instance with a longer runtime than we ask for, copy the run and adapt time and solution status.
							entry["resultForState"][stripped_state_int][cutoff_time] = entry["resultForState"][stripped_state_int][lower_cutoff].dup
							entry["resultForState"][stripped_state_int][cutoff_time][1] = cutoff_time
							entry["resultForState"][stripped_state_int][cutoff_time][0] = "TIMEOUT"
						end
					end
				else
					next if lower_cutoff == cutoff_time #=== No copying needed here.
					if entry["resultForState"][stripped_state_int][lower_cutoff][0] != "TIMEOUT"
	#					output "Successful lower cutoff: #{lower_cutoff} -- #{entry["resultForState"][state_as_string][lower_cutoff][0]}"
						entry["resultForState"][stripped_state_int][cutoff_time] = entry["resultForState"][stripped_state_int][lower_cutoff].dup
						break;
					end
				end
			end

			#=== If the result for this cutofftime exists don't rerun it.
			next if entry["resultForState"][stripped_state_int].key?(cutoff_time)

			#=== If none of the lower runtimes were successful and the current one hasn't been run, then it has to be run.
			entry_paramints_to_run << entry_paramint
		else
			entry_paramints_to_run  << entry_paramint
		end
	end
	return true if entry_paramints_to_run.empty?

#	output "Retrieve runtimes for #{entry_params_pairs_to_run.length} entry_params pairs."
#	puts "Construct instanceAndParamsHash for #{entry_params_pairs_to_run.length} entry_params pairs."
	#=== Construct instanceAndParamsHash to run.
	instanceAndParamsHash = Hash.new

	for entry_paramint in entry_paramints_to_run
		entry, stripped_state_int = entry_paramint
		inst = entry["name"]
		instanceAndParamsHash[inst] = Hash.new unless instanceAndParamsHash.key?(inst)

		unless instanceAndParamsHash[inst].key?(stripped_state_int)
			instanceAndParamsHash[inst][stripped_state_int] = {"rest" => entry["rest"], "params" => stripped_state_int, "seeds"=>[]}
		end
		instanceAndParamsHash[inst][stripped_state_int]["seeds"] << entry["seed"]
	end

	puts "getAlgoResultsForInstsAndParams."

	#=== Run everything in the instanceAndParamsHash.
	results_ready = getAlgoResultsForInstsAndParams(algo, instanceAndParamsHash, cutoff_time, cutoff_length, instanceAndParamsHash.keys, oncluster, db)

	if results_ready
		#=== Retrieve those results we had to run.
		for entry_paramint in entry_paramints_to_run
			entry, stripped_state_int = entry_paramint
			inst = entry ["name"]
			seed = entry["seed"]

			result = instanceAndParamsHash[inst][stripped_state_int]["results"][seed]
			puts instanceAndParamsHash[inst][stripped_state_int]
			unless result
				puts "ERROR - empty result."
				p instanceAndParamsHash[inst]
				p instanceAndParamsHash[inst][stripped_state_int]
				p instanceAndParamsHash[inst][stripped_state_int]["results"]

				raise "Empty result for instance #{inst}, seed #{seed}, and stripped_state_int #{stripped_state_int}"
			end
			unless entry["resultForState"].key?(stripped_state_int)
				entry["resultForState"][stripped_state_int] = Hash.new
			end
			entry["resultForState"][stripped_state_int][cutoff_time] = result

			#=== If the measured runtime is over the cutoff time the base algorithm should have terminated earlier - that's not our fault, so use the cutoff time instead. (Also helping to fix a bug with some entries in the DB.)
			#=== But NEVER count a run with less than 0.1 seconds - in order to account for any potential overhead and in order to not get endless loops with runtimes that are 0.0 seconds.
			#$total_cputime += [0.1, [cutoff_time, result[1]].min].max
			$total_cputime += [$minimum_runtime, [cutoff_time, result[1]].min].max  # new as of 09/22/07 in order to reduce runtimes of experiments.

			$totalEvaluationCount += 1
		end
	end
	return results_ready
end

#=== Run numbers for each instances MUST BE INCREASING !
def makeStandardInstanceHash(array_of_detailed_instances, stripped_state_int)
	instanceHash = Hash.new
	for entry in array_of_detailed_instances
		inst = entry["name"]
		run = entry["run"]
		instanceHash[inst] = {"runs"=>0, "rest"=>entry["rest"], "result"=>[]} unless instanceHash.key?(inst)
		instanceHash[inst]["runs"] += 1
		censortimes = entry["resultForState"][stripped_state_int].keys
#		p censortimes
#		p censortimes.max
		instanceHash[inst]["result"] << entry["resultForState"][stripped_state_int][censortimes.max]
	end
	return instanceHash
end

###########################################################################
# Returns the set of instances and their desired solution qualities contained in a file.
###########################################################################
def getInstanceHash(instanceset_name, algo="none")
	#=== Special case: the algorithm does not take input instances.
	return [{"_#{algo}_dummyInstance"=>{"desired_qual"=> 0, "reference"=>0}}, ["_#{algo}_dummyInstance"]] if instanceset_name == "_"

	#=== Read set of instances to run on. (array of arrays [instance_name, opt])
	instancesSorted = []
	instanceHash = Hash.new
	File.open(instanceset_name){|file|
	    while line=file.gets;
		raise "Incorrect number of entries #{line.strip.split.length} in #{line}" unless line.strip.split.length >= 2
		entries = line.chomp.strip.split
		inst = entries[0]
		qual = entries[1]
		rest = entries[2...entries.length]
		instanceHash[inst] = Hash.new
		instanceHash[inst]["desired_qual"] = qual
		instanceHash[inst]["rest"] = rest
		instancesSorted << inst
	    end
	}
	return [instanceHash, instancesSorted]
end
