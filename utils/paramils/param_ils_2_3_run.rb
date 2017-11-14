#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__))

require "param_reader.rb"
require "global_helper.rb" # for instance hash

$state_to_int = {}
$stripped_state_to_int = {}
$int_to_full_state = []
$int_to_full_state_string = []
$stripped_int_to_stripped_state = []
$full_int_to_stripped_int = []

# =========================================
# This procedure is called at the first encounter of a state and defines its associated integer for the full state and the stripped version.
# It can also be called again later on.
# Returns the int of the full state, to be used everywhere in connection with the caching Hashes/arrays set u here.
# =========================================
def full_state_to_full_int(full_state)
	full_state_as_string = state_string(full_state)
	unless $state_to_int.key?(full_state_as_string)
		state_int = $state_to_int.length
		$state_to_int[full_state_as_string] = state_int
		$int_to_full_state[state_int] = full_state
		$int_to_full_state_string[state_int] = full_state_as_string

		stripped_state = strip_state(full_state)
		stripped_state_as_string = state_string(stripped_state)
		#=== If we have not seen the stripped state before, set it up. (full -> stripped is N:1)
		unless $stripped_state_to_int.key?(stripped_state_as_string)
			stripped_state_int = $stripped_state_to_int.length
			#$stripped_int_to_one_of_its_full_ints[stripped_state_int] = state_int
			$stripped_state_to_int[stripped_state_as_string] = stripped_state_int
		end
		stripped_state_int = $stripped_state_to_int[stripped_state_as_string]
		$full_int_to_stripped_int[state_int] = stripped_state_int

		$stripped_int_to_stripped_state[stripped_state_int] = stripped_state
	end
	return $state_to_int[full_state_as_string]
end

# =========================================
#                  put string to output and outfile
# =========================================
def output(s)
	if @output_level >= 50
		puts s
		@out.puts s
		@out.flush
	end
end

# ==========================================
#  Output a string to the run log. 
# ==========================================
def runlog(s)
	if @use_run_log
		@param_ils_runlog_file.puts s
		@param_ils_runlog_file.flush
	end
end

# =========================================
# Get quality of a parameter setting without extra runs.
# =========================================
def eval(full_state_int)
	raise "eval() takes an int argument, not a #{full_state_int.class}" unless full_state_int.is_a?(Integer)
	level = detail(full_state_int)
	if level > 0
		n = @numRunsPerLevelOfDetail[level-1]
		c = @censoringThresholdPerLevelOfDetail[level-1]
		
		stripped_state_int = $full_int_to_stripped_int[full_state_int]
		res = @cachedResultScalars[stripped_state_int][level-1]
	else
		n = 0
		c = 0
		res = 100000000
	end
	return [res, n, c]
end


# =========================================
# Output evaluation of a state
# =========================================
def str(full_state_int, print_state=true)
	val, n, c = eval(full_state_int)
	if print_state
		return "#{$int_to_full_state_string[full_state_int]} (#{val} [based on #{n} runs with cutoff #{c}])" if val 
		return "#{$int_to_full_state_string[full_state_int]} (-- [no runs])"
	else
		return "(#{val} [based on #{n} runs with cutoff #{c}])" if val 
		return "(-- [no runs])"
	end
end


# =========================================
# Output more detailed information for a state.
# =========================================
def output_result(full_state_int)
	stripped_state_int = $full_int_to_stripped_int[full_state_int]

	entriesForObjective = []
	instance_names = []
	for entry in @instances
		if entry["resultForState"].key?(stripped_state_int)
			entriesForObjective << entry 
			instance_names << entry["name"] unless instance_names.include?(entry["name"])
		else
			break
		end
	end
#	raise "FATAL! Number of results #{numEvaluated(state)} does not equal results from the beginning #{entriesForObjective.length}" if ((@approach=~ /focused/) and not numEvaluated(state)==entriesForObjective.length)
	
	level = detail(full_state_int)
	censoringTime = @censoringThresholdPerLevelOfDetail[level-1]
	
	objectives = getAllObjectives(@algo, @run_obj, entriesForObjective, instance_names, stripped_state_int, censoringTime, @cutoff_length)
#	objectives = getObjectivesForComputedInstances(@algo, @run_obj, entriesForObjective, @instances_sorted, state_as_string)
	#instanceHash = makeStandardInstanceHash(@instances, state_string(stripped_state))

	outputObjectives(instance_names, objectives)
end


def isPruned(bound)
	if bound.class.to_s == "Array"
		return true if bound[0] == "pruned"
		raise "bound is array, but doesn't have pruned as first element."
	end
	return false
end

# =========================================
# Adaptive neighbourhood relation that takes into account conditional parameters.
# =========================================
def neighbourhood(full_state_int)
	stripped_state_int = $full_int_to_stripped_int[full_state_int]
	stripped_state = $stripped_int_to_stripped_state[stripped_state_int]
	full_state = $int_to_full_state[full_state_int]
	result = []
	for param in stripped_state.keys
		next if @fixed_ass.key?(param)
		for value in @domain[param]
			unless full_state[param] == value
				new_state = full_state.dup
				new_state[param] = value

				next if forbidden(new_state, @forbidden_combos)
				#=== Cannot convert state Hash to int yet - only do that for states we actually visit because of memory constraints.
				result << [new_state, param, new_state[param], value]
			end
		end
	end
	if result == []
		puts "fixed_ass:"
		p @fixed_ass
		puts "state.keys"
		p state.keys
		raise "neighbourhood can't be empty!!"
	end
	return result
end


# =========================================================================================
# Bundle actions to be taken when a state is visited in the search.
# =========================================================================================
def visit(full_state_int)
	#=== Update statistics. 
	unless @allVisitedStates.key?(full_state_int)
		@allVisitedStates[full_state_int] = {"number" => @allVisitedStates.size, "numVisited"=>0, "totalTime"=>0, "timesLM"=>0, "timesMadeIncumbent"=>0, "iteration"=>@iteration, "str"=>$int_to_full_state[full_state_int]}
		@orderedVisitedStates << full_state_int
		@statesVisited << full_state_int
	end
	@allVisitedStates[full_state_int]["numVisited"] += 1
end


# =========================================================================================
# Output incumbent state is found.
# =========================================================================================
def output_incumbent_state()
	val, n, c = @incumbent_res
	full_state = $int_to_full_state[@incumbent_state_int]

	numeval = $totalEvaluationCount

# "Total Time","Mean Performance","Wallclock Time","Incumbent ID","Automatic Configurator Time","Configuration..."

#	@param_ils_traj_file.print "#{$total_cputime}, #{val}, #{n}, #{@iteration}, #{@numFlip}, "
	@param_ils_traj_file.print "#{$total_cputime}, #{val}, #{n}, #{@iteration}, #{c}, "
	@param_ils_traj_file.puts @params.map{|x|x + "='" + full_state[x] + "'"}.join(", ") # output the current values
	@param_ils_traj_file.flush

	times = Process.times
	tuningTime = times.utime+times.stime

	curTime = Time.now
	wallclockSeconds = curTime.tv_sec - @start_time_wallclock.tv_sec
	wallclockMicroseconds = curTime.tv_usec - @start_time_wallclock.tv_usec
	if (wallclockMicroseconds < 0)
		wallclockMicroseconds += 1000000
	end

	wallclockTime = ("%d.%06d" % [wallclockSeconds, wallclockMicroseconds]).to_f

	totalTimeStr = ("%.4f" % [$total_cputime+tuningTime])
	wallclockStr = ("%.4f" % [wallclockTime])
	tuningTimeStr = ("%.4f" % [tuningTime])
	@param_ils_traj_csv.print "#{totalTimeStr}, #{val}, #{wallclockStr}, #{@incumbent_state_int}, #{tuningTimeStr}, "
	@param_ils_traj_csv.puts @params.map{ |x| x + "='" + full_state[x] + "'"}.join(", ")
	@param_ils_traj_csv.flush

	output "New Incumbent: #{$total_cputime}, #{val} [#{n}, #{c}]. With state " + @params.map{|x| "#{x}=#{full_state[x]}"}.join(", ") 
	@out.flush
end


# =========================================================================================
# Set a new incumbent state.
# =========================================================================================
def setNewIncumbent(full_state_int, res=nil, n=nil, c=nil)
	raise "setNewIncumbent() takes an int argument, not a #{full_state_int.class}" unless full_state_int.is_a?(Integer)
	@incumbent_state_int = full_state_int
	if res
		@incumbent_res = [res, n, c]
	else
		@incumbent_res = eval(full_state_int)
	end
	output_incumbent_state
	
	unless @allVisitedStates.key?(full_state_int) 
		@allVisitedStates[full_state_int] = {"number" => @allVisitedStates.size, "numVisited"=>0, "totalTime"=>0, "timesLM"=>0, "timesMadeIncumbent"=>0, "iteration"=>@iteration, "str"=>$int_to_full_state[full_state_int]}
		@orderedVisitedStates << full_state_int
	end
	@allVisitedStates[full_state_int]["timesMadeIncumbent"] += 1
end


# =========================================================================================
# Update the precision of the incumbent.
# =========================================================================================
def update_incumbent(new_inc_res=nil)
	new_inc_res = eval(@incumbent_state_int) unless new_inc_res
	if new_inc_res[1] >= @incumbent_res[1] and new_inc_res[2] >= @incumbent_res[2]
		output " Same incumbent, new precision:"
		setNewIncumbent(@incumbent_state_int, new_inc_res[0], new_inc_res[1], new_inc_res[2])
	end
end

# =========================================================================================
# Get the results for instance-seed combinations for a given param config.
# =========================================================================================
def getRunsOnEntriesWithParams(entries, full_state_int, cutoffTimeForState, test=false)
	stripped_state_int = $full_int_to_stripped_int[full_state_int]
	
	#=== Remove precision to match the one of the DB.
	cutoffTimeForState = (cutoffTimeForState*(10**5)).floor * (10**(-5.0))

#	raise "state_string error: strip_state(strip_state(s)) != strip_state(s): \n#{state_string(strip_state(param_state))} != \n#{state_string(param_state)}" unless state_string(param_state) == state_string(strip_state(param_state))
	oldTotalCpuTime = $total_cputime

	getAlgoResultsForEntryParamsPairs(@algo, entries.map{|entry| [entry, stripped_state_int]}, cutoffTimeForState, @cutoff_length, @oncluster, @db)

	@allVisitedStates[full_state_int]["totalTime"] += ($total_cputime - oldTotalCpuTime)

	#=== Assert that we now know all the entries. 
	for entry in entries
		unless entry["resultForState"][stripped_state_int][cutoffTimeForState]
			puts "Empty result! " 
			puts "State"
			p stripped_state_int
			puts "Entry"
			p entry
			p entry["resultForState"]
			p entry["resultForState"][stripped_state_int]
			raise "Empty result"
		end
	end

	#=== Compute the objective for each entry.
	results = entries.map{|entry| singleRunObjective(@algo, @run_obj, entry["resultForState"][stripped_state_int][cutoffTimeForState], entry["desired_qual"], entry["rest"], cutoffTimeForState, @cutoff_length)}

	unless test
		if $total_cputime > @lastOutputCPUTime + 10
			@lastOutputCPUTime  = $total_cputime
			output("#{$totalEvaluationCount}/#{@maxEvals}, #{$total_cputime}/#{@tunerTimeout}")
		end
		#=== Keep track of results for each <param, value> pair.
	end
	return results
end


#=========================================================================================
# Add new runs for param_state, for the original FocusedILS.
# Invariants: Before and after this, @incumbent_state_int is one of the states with the most evaluations, and amongst those, it is the best.
# The number of runs is limited by @N.
# =========================================================================================
def addNewRuns(param_state, numNewRuns)
#	numNewRuns.times{|i| incTimeSpentInState(param_state)}
	numNewRuns.times{|i| break if haveToStop(); boundedIncTimeSpentInState(param_state, nil)}
end

# =========================================================================================
# Return the current level of detail used to evaluate the  state.
# =========================================================================================
def detail(full_state_int)
	stripped_state_int = $full_int_to_stripped_int[full_state_int]
	raise "detail() takes an int argument, not a #{full_state_int.class}" unless full_state_int.is_a?(Integer)
#	state_as_string = state_string(state)
	unless @cachedResultScalars.key?(stripped_state_int)
		@cachedResultScalars[stripped_state_int] = []
	end
	return @cachedResultScalars[stripped_state_int].length
end


# =========================================================================================
# Helper function for better. 
# Returns true iff combination_of_results_1 - combination_of_results_2 <= eps, 
# i.e. iff the first state is better or equal to the second one using the lesser level of detail.
# =========================================================================================
def isBetterWithLesserDetail(state1_int, state2_int, equalIsBetter)
#	puts "comparing \n#{state1} and \n#{state2}"
	level1 = detail(state1_int)
	level2 = detail(state2_int)
	
	minLevel = [level1, level2].min
	return isBetterWithLevel(state1_int, state2_int, equalIsBetter, minLevel)
end

# =========================================================================================
# Returns true iff combination_of_results_1 - combination_of_results_2 <= eps, 
# i.e. iff the first state is better or equal to the second one using that level of detail.
# =========================================================================================
def isBetterWithLevel(state1_int, state2_int, equalIsBetter, level)
	raise "Level can't be <= 0: #{level}" if level <= 0
#	p level

	res1 = @cachedResultScalars[$full_int_to_stripped_int[state1_int]][level-1]
	res2 = @cachedResultScalars[$full_int_to_stripped_int[state2_int]][level-1]
	
#	p res1
#	p res2
#	p equalIsBetter
	
#	p @cachedResultScalars[state_as_string1]
#	p @cachedResultScalars[state_as_string2]
	
	#=== In case res1 was pruned before let's compute it now (enough for the comparison).
	if isPruned(res1)
		if isPruned(res2)
			doRunsBounded(state2_int, level-1, nil)
			res2 = @cachedResultScalars[$full_int_to_stripped_int[state2_int]][level-1]
		end
		doRunsBounded(state1_int, level-1, res2)
		res1 = @cachedResultScalars[$full_int_to_stripped_int[state1_int]][level-1]
	end

	#=== In case res2 was pruned before let's compute it now (enough for the comparison).
	if isPruned(res2)
		doRunsBounded(state2_int, level-1, res1)
		res2 = @cachedResultScalars[$full_int_to_stripped_int[state2_int]][level-1]
	end

	return shortBetter(res1, res2, equalIsBetter)
end


def shortBetter(res1, res2, equalIsBetter=true)
	return false if isPruned(res1) and not isPruned(res2)
	return true if isPruned(res2) and not isPruned(res1)
	
	#=== Both results are pruned, break the tie by the number of solved instances with X times the bound of the incumbent.
	if isPruned(res1) and isPruned(res2)
		return false if res1[1] < res2[1]
		return true if res1[1] > res2[1]
		return "tie" if equalIsBetter			
		return false
	end

	diff = res1 - res2
	if equalIsBetter
		result = true if diff < -@eps
		result = "tie" if diff >= -@eps and diff <= @eps
		result = false if diff > @eps
	else 
		result = true if diff < -@eps
		result = false if diff >= -@eps
	end
#	p res1 - res2
#	p result
	return result
end

# =========================================================================================
# State1 dominates state2 iff it has at least as much detail and is better with the lesser detail.
# =========================================================================================
def dominates(state1_int, state2_int, equalIsBetter=true)
	detailBetter = (detail(state1_int) >= detail(state2_int))
	return false unless detailBetter
	return isBetterWithLesserDetail(state1_int, state2_int, equalIsBetter) 
end


# =========================================================================================
# Do runs for a state with a lower level of detail than some other one, up to a total bound on performance (from that other one).
# How that bound influences censoring thresholds depends on the objective function:
# 1) Median: all runs are cut off just after the bound, can stop after 50% cutoffs (if the bound exists, otherwise need a tie breaking criterion).
# 2) Mean, mean10, mean1000, etc: Accumulate time t_new one run at a time, counting timeouts appropriately. The timeout for each run is min(bound*numRuns-t_new, regular censoring time at this level)
# 3) Other objectives: not implemented yet, didn't really think about ways to exploit the bound there.
# =========================================================================================
def doRunsBounded(full_state_int, level, paramBound=nil)
	stripped_state_int = $full_int_to_stripped_int[full_state_int]
	
	bound = paramBound
	bound = nil if isPruned(paramBound)
		
#	p "doRunsBounded #{full_state_int} #{level} #{bound}"	

	raise "Should not recompute runs for level #{level} that we already did and that weren't pruned: #{@cachedResultScalars[stripped_state_int][level]} for state #{stripped_state_int}." if @cachedResultScalars[stripped_state_int][level] and not isPruned(@cachedResultScalars[stripped_state_int][level])

	#=== Get the performance of the incumbent --- if that doesn't exist, get it first.
	incumbent_bound = @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][level]

#	p "incumbent bound is #{incumbent_bound}"

	if incumbent_bound == nil and not full_state_int == @incumbent_state_int
		if @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][level-1] == nil
			raise "incumbent state has performance nil at level #{level} and nil at level #{level-1}: #{@cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]].join("\n")}" 
		end
		
		output "State wants more detail (#{level}+1) than incumbent (#{detail(@incumbent_state_int)}), doing incumbent first:\n#{str(full_state_int)}\n#{str(@incumbent_state_int)}"
		boundedIncTimeSpentInState(@incumbent_state_int, nil)
		incumbent_bound = @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][level]
	end

	#=== This heuristic changes the trajectory but makes everything a lot faster: limit configurations by @boundMultiplier*bound from incumbent.
	if @boundMultiplier and not full_state_int == @incumbent_state_int
		raise "Incumbent still doesn't has a bound for level #{level}" if incumbent_bound == nil

		#=== For FocusedILS, the incumbent may actually have been pruned at that level -- in that case, leave the bound at whatever it is.
		unless isPruned(incumbent_bound)
			bound_from_incumbent = @boundMultiplier *  incumbent_bound
			bound = bound_from_incumbent unless bound
			bound = [bound, bound_from_incumbent].min
		end
	end

#	p "doRunsBounded, level #{level}, bound #{bound} (parambound #{paramBound}) maxDetail #{@maxDetail}"

	if level == @maxDetail
		output "Already at maximal level of detail #{@maxDetail} for state #{full_state_int}"
		return
	end

	numRuns = @numRunsPerLevelOfDetail[level]
	censorTime = @censoringThresholdPerLevelOfDetail[level]

#	puts "level=#{level}, bound=#{bound}, numRuns=#{numRuns}, censorTime=#{censorTime}"

	unless @cachedResultScalars.key?(stripped_state_int)
		@cachedResultScalars[stripped_state_int] = []
	end

	raise "doRunsBounded called with too low a level of detail - #{level} has been run for state #{stripped_state_int} already, result = #{@cachedResultScalars[stripped_state_int][level]}" if @cachedResultScalars[stripped_state_int].length > level and not isPruned(@cachedResultScalars[stripped_state_int][level])
	raise "doRunsBounded called with too high a level of detail - the highest level so far is #{@cachedResultScalars[stripped_state_int].length}, now supposed to do #{level} for state #{stripped_state_int}." if @cachedResultScalars[stripped_state_int].length < level

	#=== Compute the scalarResult depending on whether there is a bound and on the objective function. If censored it will be the threshhold + 1
	if bound and @pruning
		if @overall_obj == "median" and bound < censorTime - @eps
			########### This only works for the following definition of median:
			# ================ Let x1, x2, ..., x_n be an ordered series; then the median is x_{ceil(n/2)}. I.e. for 1 value, it's x_1; for 2 values, it's still x1; for 3 values, it's x_2, for 4 values, it is also x_2, etc.			
			singleResults = []
			allRunsPerformed = false

			thisCensorTime = bound + 0.01
			thisCensorTime = thisCensorTime.ceil.to_i if @algo =~ /spear/ or @algo =~ /sat4j/ or @algo =~ /smt/# Some algos can only handle full integers as cutoff.

			#=== We could be more pro-active here: it suffices to have >50% of the runs finish under the cutoff time.
			#=== So you can stop after that; but you only get an upper bound on your median and may have to rerun the rest later.
			#=== Since we want to keep it simple we don't do that here.
			
			#=== Just perform the runs with the target median as a bound.
			results = getRunsOnEntriesWithParams(@instances[0...numRuns], full_state_int, thisCensorTime)
			scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, results, @run_obj, thisCensorTime, @cutoff_length).to_f
#			output "scalarResult #{scalarResult}, bound #{bound}"

			raise "Still need to implement @boundMultiplier for median" if @boundMultiplier
			#=== TODO: Make i the number of solved instances within the timelimit.
			i = 0
			scalarResult = ["pruned",i] if scalarResult > bound + @eps

		elsif @overall_obj =~ /mean/
			t_new = 0
			totalTimeBound = bound * numRuns
#			output " Bounded INCTIME: -> detail #{level}, N=#{numRuns}, censoring=#{censorTime}, totalTimeBound=#{totalTimeBound}"

			#=== Speed up the process by remembering some stuff from lower levels -- won't change trajectory.
			singleResults = []
			@savedResults = Hash.new unless @savedResults
			@savedResults[stripped_state_int] = Hash.new unless @savedResults.key?(stripped_state_int)
			unless level == 0
				if @savedResults[stripped_state_int][level-1].key?(censorTime)
					singleResults = @savedResults[stripped_state_int][level-1][censorTime].dup
					#=== Popping the last items from that list, since they might be pruned. One should have been enough, but there was still a difference in the trace - this may indicate something fishy, but it seems minor and not a priority.
					singleResults.pop
					singleResults.pop
				end
			end
			@savedResults[stripped_state_int][level] = Hash.new
			@savedResults[stripped_state_int][level][censorTime] = singleResults

			if singleResults == []
				t_new = 0
			else
				scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, singleResults, @run_obj, censorTime, @cutoff_length).to_f
				t_new = scalarResult * (singleResults.length)
			end

			allRunsPerformed = true
			while singleResults.length < numRuns
				i = singleResults.length
				#=== Compute result and then put it into @cachedResultScalars.
				thisCensorTime = [[censorTime,0.01].max, (totalTimeBound-t_new) + 0.01].min 
				thisCensorTime = [[censorTime,0.01].max, (totalTimeBound-t_new).ceil.to_i].min if @algo =~ /spear/ or @algo =~ /sat4j/ or @algo =~ /smt/ # Some algos can only handle full integers as cutoff.

				if thisCensorTime <= @eps # don't let this get too small, numerical problems can cause infinite loop/crash
					allRunsPerformed = false
					break 
				end
				singleResult = getRunsOnEntriesWithParams([@instances[i]], full_state_int, thisCensorTime)
				singleResults.concat singleResult
				
				scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, singleResults, @run_obj, censorTime, @cutoff_length).to_f
				t_new = scalarResult * (i+1)
				
#				puts "   Used #{t_new}/#{totalTimeBound} seconds for this state, ran #{i+1}/#{numRuns} runs."
			end
			scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, singleResults, @run_obj, censorTime, @cutoff_length).to_f

			#=== If the new configuration didn't have to do all runs, register it as pruned.
			if (scalarResult > bound+@eps and thisCensorTime < censorTime)
				scalarResult = ["pruned",i] 
			end
			scalarResult = ["pruned",i] unless allRunsPerformed
		else
			#=== Just perform the runs unboundedly.
			results = getRunsOnEntriesWithParams(@instances[0...numRuns], full_state_int, censorTime)
			scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, results, @run_obj, censorTime, @cutoff_length).to_f
		end
	else
		#=== Just perform the runs unboundedly.
		results = getRunsOnEntriesWithParams(@instances[0...numRuns], full_state_int, censorTime)
		scalarResult = combinationOfObjectiveFunctions(@algo, @overall_obj, results, @run_obj, censorTime, @cutoff_length).to_f

		#=== Speed up the process by remembering some stuff from lower levels -- won't change trajectory.
		@savedResults = Hash.new unless @savedResults
		@savedResults[stripped_state_int] = Hash.new unless @savedResults.key?(stripped_state_int)
		@savedResults[stripped_state_int][level] = Hash.new
		@savedResults[stripped_state_int][level][censorTime] = results

	end
	@cachedResultScalars[stripped_state_int][level] = scalarResult

	#=== Care for the invariants to remain true:
	#=== 1) If the detail for this state is higher than the detail of the incumbent, catch up.
	if detail(@incumbent_state_int) < detail(full_state_int)
		output "State got more detail (#{detail(full_state_int)}) than incumbent (#{detail(@incumbent_state_int)}), catching up:\n#{str(full_state_int)}\n#{str(@incumbent_state_int)}"
		raise "This situation should not occur anymore now that the incumbent is always run first"
#			boundedIncTimeSpentInState(@incumbent_state_int, state)
		boundedIncTimeSpentInState(@incumbent_state_int, nil)
	end
	
	#=== 2) If this state is itself the incumbent one, output its new value.
	if full_state_int == @incumbent_state_int
		update_incumbent
		return
	end

	#=== 3) If the detail for this state and the incumbent is identical, compare the two -- in case of ties take the old one.
	if detail(@incumbent_state_int) == detail(full_state_int)
		highest_level = detail(full_state_int)
		inc_qual = @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][highest_level-1]
		this_qual = @cachedResultScalars[stripped_state_int][highest_level-1]
#		output "inc_qual #{inc_qual}, this_qual #{this_qual}, highest level #{highest_level}" if @approach == "focused"
		output "bound for changing incumbent #{@nStart}" if @idn == 2
		unless shortBetter(inc_qual, this_qual, true)
			unless @idn == 2 and highest_level < @nStart
				output "New inc: #{this_qual}"

				raise "If two states have the same detail one must dominate the other: #{inc_qual}, #{this_qual}." unless shortBetter(this_qual, inc_qual, true)
				setNewIncumbent(full_state_int)
			end
		end
	end
end


# =========================================================================================
# Like boundedIncTimeSpentInState, but with bound on performance.
# =========================================================================================
def boundedIncTimeSpentInState(undetailedState_int, detailedState_int=nil)
	level = detail(undetailedState_int)
	return if level == @maxDetail
	
	bound = nil
	if detailedState_int
		raise "Detailed state must have larger detail than undetailed one: #{detail(detailedState_int)} > #{detail(undetailedState_int)} violates this" unless detail(detailedState_int) > detail(undetailedState_int)
		bound = @cachedResultScalars[$full_int_to_stripped_int[detailedState_int]][level]
		
		if isPruned(bound)
			doRunsBounded(detailedState_int, level, nil)
		end
		bound = @cachedResultScalars[$full_int_to_stripped_int[detailedState_int]][level]
	end
	doRunsBounded(undetailedState_int, level, bound)
end

# =========================================================================================
# Better: this is a completely symmetric comparison (except in the case of ties, in which case true is returned).
# At the end of this, one state must have at least as many evals as the other one and outperform it with the lower number of evals of the two.
# Cases:
# 1) state1 has more or equal number of evals and is better with those: return false (first is better)
# 2) state2 has more or equal number of evals and is better with less evals: return true (second is better)
# 3) state1 has less evals but is better with those: execute runs of state1 until either 1) or 2)
# 4) state2 has less evals but is better with those: execute runs of state2 until either 1) or 2)
# =========================================================================================
def better(new_state_int, old_state_int)
	visit(new_state_int)
	
	if @approach == "basic" or @approach == "random"
		raise "Old state must have been evaluated before" unless detail(old_state_int) == @maxDetail
		boundedIncTimeSpentInState(new_state_int, old_state_int)

		return true if dominates(new_state_int, old_state_int, false)
		return "tie" if dominates(new_state_int, old_state_int, true)
		return false if dominates(old_state_int, new_state_int, false) #=== The old state must really be better, ties don't count.
		return false if dominates(old_state_int, new_state_int, true) 
		raise "Still undecided at end of better between new state #{str(new_state_int)} and old state #{str(old_state_int)}. This shouldn't be possible."

	elsif @approach =~ /focused/
		#=== Everybody gets at least one more level of detail.
		if detail(new_state_int) < detail(old_state_int)
			boundedIncTimeSpentInState(new_state_int, old_state_int)
			@numEvaluationsThisIteration += 1
		elsif detail(new_state_int) > detail(old_state_int)
			boundedIncTimeSpentInState(old_state_int, new_state_int)
			@numEvaluationsThisIteration += 1
		else
			boundedIncTimeSpentInState(old_state_int, nil)
			@numEvaluationsThisIteration += 1

			if detail(new_state_int) < detail(old_state_int) # not always the case because if new_state is incumbent then we trigger a run of it.
				boundedIncTimeSpentInState(new_state_int, old_state_int)
				@numEvaluationsThisIteration += 1
			end
		end
		result = betterWithoutAutomaticIncrease(new_state_int, old_state_int)
	
		return result
	end
end

# =========================================================================================
# Helper function for better - add detail until one dominates.
# =========================================================================================
def betterWithoutAutomaticIncrease(new_state_int, old_state_int, haveToFinish=false)
	
	#=== If everything is clear, return.
	return true if dominates(new_state_int, old_state_int, false)
	return "tie" if dominates(new_state_int, old_state_int, true)   #=== new <= old handled first -> moving away from incumbent.
	return false if dominates(old_state_int, new_state_int, false)  #=== Here, the old state is really better, no tie
	if $stop_on_tie                                                 
		return false if dominates(old_state_int, new_state_int, true) 
	end
	
	#=== When we get here, the one with less evaluations looks better.
	#Case 1: new one has less and is better.
	if detail(new_state_int) < detail(old_state_int)
		while not (dominates(new_state_int, old_state_int, true) or dominates(old_state_int, new_state_int, false))
			break if haveToStop() and not haveToFinish
			boundedIncTimeSpentInState(new_state_int, old_state_int)
		end
	end

	#Case 2: old one has less and is better.
	if detail(old_state_int) < detail(new_state_int)
		while not (dominates(new_state_int, old_state_int, true) or dominates(old_state_int, new_state_int, false))
			break if haveToStop() and not haveToFinish
			boundedIncTimeSpentInState(old_state_int, new_state_int)
		end
	end

	#=== When we get here, both have the same #runs, so at least one dominates the other.
	return true if dominates(new_state_int, old_state_int, false)
	return "tie" if dominates(new_state_int, old_state_int, true) #=== new <= old handled first -> moving away from incumbent in case of ties.
	return false if dominates(old_state_int, new_state_int, false)  #=== The old state must really be better, ties don't count.)

	#=== If we have to stop, don't move.
	return false if haveToStop() and not haveToFinish

	raise "Still undecided at end of better between new state #{str(new_state_int)} and old state #{str(old_state_int)}. This shouldn't be possible."
end
	

# =========================================
# Random search, for comparison.
# =========================================
def random_search(init_state_int)
	output "========================================================\nStarting RANDOM SEARCH \n========================================================"
	@iteration = 1
	current_state_int = init_state_int
	setNewIncumbent(current_state_int)
	visit(current_state_int)

	visited_states = Hash.new
	visited_states = [current_state_int]
	boundedIncTimeSpentInState(current_state_int, nil)

	@numEvaluationsThisIteration = 0
	if @iterativeDeepening and @init_def
		def_state_int = init_default()
		if better(def_state_int, current_state_int)
			output("          -> With this level of detail, the default is better than the result of the last phase, moving back to default.\n\n")  
			current_state_int = def_state_int
		else 
			output "        -> Result from last phase is better than default, keeping it.}"
		end
	end

	while not haveToStop()
		#=== Stop if all configurations have been evaluated -- otherwise, endless loop !
		while true
			random_state_int = init_random()
			next if visited_states.include?(random_state_int)
			visited_states << random_state_int
			break
		end
				
		if better(random_state_int, @incumbent_state_int)
#			checkIfNewIncumbent(random_state)
			output("          -> Take improving step to random #{str(random_state_int)}\n\n")  
		else 
#			checkIfNewIncumbent(current_state)
			output "        -> Worse random: #{str(random_state_int)}"
		end
		@iteration += 1
	end
end

# =========================================================================================
# =========================================================================================
#                  HERE THE ITERATED LOCAL SEARCH AND ITS SUBFUNCTIONS BEGIN.
# =========================================================================================
# =========================================================================================


# =========================================
# Stop search if one of the termination criteria is fulfilled.
# =========================================
def haveToStop()
	if $totalEvaluationCount>=@maxEvals
		output("ParamILS has reached the specified maximum number of #{@maxEvals} function evaluations => stopping the search now.");
		return true 
	end

	if $total_cputime >= @tunerTimeout
		output("ParamILS has reached the specified CPU time limit of #{@tunerTimeout} seconds => stopping the search now.");
		return true 
	end

	if @iteration > @maxIts
		output("ParamILS has reached the specified maximum number of #{@maxIts} iterations => stopping the search now.");
		return true 
	end

	#return true if @algo =~ /saps/ and @allVisitedStates.size >2400
	#=== Also stop if we have already reached the minimum we can achieve
	if detail(@incumbent_state_int) == @maxDetail and @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][detail(@incumbent_state_int)-1] < @optimum_solqual + @eps
		output("ParamILS has reached the specified optimal solution quality of #{@optimum_solqual} up to an additive error of #{@eps} => stopping the search now.");
		return true 
	end

	puts "now " + Time.now.to_s + "; start " + @start_time_wallclock.to_s + "; time-start " + (Time.now - @start_time_wallclock).to_s + "; maxWall " + @maxWallTime.to_s
	if Time.now - @start_time_wallclock > @maxWallTime
		output("ParamILS has reached the specified maximum wall time limit of #{@maxWallTime} seconds => stopping the search now.");
		return true 
	end

	return false
end

def init_search
	#=== Init.
	if @init_def
		return init_default()
	else
		return  init_random()
	end
end


def iterative_deepening_ils(depth, init_state_int)
	@N = @nForDepth[depth-1]
	@cutoff_time = @cForDepth[depth-1]
	@tunerTimeout = @tForDepth[depth-1]
	@maxEvals = @eForDepth[depth-1]
	
	@iteration = 1
	@numFlip = 1

	@cachedResultScalars = Hash.new
	@numRunsPerLevelOfDetail = []
	@censoringThresholdPerLevelOfDetail = []

	puts("Level #{@depth}")
	@out.puts("Level #{@depth}")
#	@param_ils_traj_file.puts "Level #{@depth}"

	@allVisitedStates = {} # Hash indexed by state_string, containing number and all kinds of info.
	@orderedVisitedStates = []
	@statesVisited = []

	#=== Set up the schedule how many instances and which censoring thresholds to use at each level of detail.
	if @approach == "focused"
		@maxDetail = @N
		for i in 0...@maxDetail
			@numRunsPerLevelOfDetail[i] = i+1
			@censoringThresholdPerLevelOfDetail[i] = @cutoff_time
		end
		
	elsif @approach == "basic" or @approach == "random"
		@maxDetail = 1
		@numRunsPerLevelOfDetail[0] = @N
		@censoringThresholdPerLevelOfDetail[0] = @cutoff_time
	else
		raise "Unknown approach #{@approach}"
	end

	#=== Start the search for this level of ParamILS.
	output "========================================================\nStarting ILS for level #{depth}, i.e. a limit of N=#{@N}, and cutoff time=#{@cutoff_time}.\nCurrent CPU time = #{$total_cputime}, this run goes until #{@tunerTimeout} \n========================================================"
	if @approach == "random"
		random_search(init_state_int)
	else
		iterated_local_search(init_state_int)
	end
	output "Final solution for depth #{depth} with limit N=#{@N}, and cutoff time=#{@cutoff_time}."
	output_incumbent_state
	return @incumbent_state_int
end


# =========================================
# Standard ILS.
# =========================================
def iterated_local_search(init_state_int)
	current_state_int = init_state_int
	setNewIncumbent(current_state_int)
	visit(current_state_int)

	if @idn == 1
		@nStart.times{|i| boundedIncTimeSpentInState(current_state_int, nil)}
	else
		boundedIncTimeSpentInState(current_state_int, nil)
	end

	@numEvaluationsThisIteration = 0
	if @iterativeDeepening and @init_def
		def_state_int = init_default()
		if better(def_state_int, current_state_int)
			output("          -> With this level of detail, the default is better than the result of the last phase, moving back to default.\n\n")  
			current_state_int = def_state_int
		else 
			output "        -> Result from last phase is better than default, keeping it.}"
		end
	end

	#=== Perform @R random steps.
	@numEvaluationsThisIteration = 0
	for i in 0...@R
		break if haveToStop()
		random_state_int = init_random()
		
		@numEvaluationsThisIteration = 0
		if better(random_state_int, current_state_int)
			output("          -> Take improving step to random #{str(random_state_int)}\n\n")  
			current_state_int = random_state_int
		else 
			output "        -> Worse random: #{str(random_state_int)}"
		end
	end
	
	@numEvaluationsThisIteration=0
	last_ils_state_int = basic_local_search(current_state_int)
	current_state_int = last_ils_state_int
  
	@iteration += 1
	while not haveToStop()
		output("#{$totalEvaluationCount}/#{@maxEvals}, #{$total_cputime}/#{@tunerTimeout}")

                puts "iteration #{@iteration}, flip #{@numFlip}, evaluation count #{$totalEvaluationCount}"
                @out.puts "iteration #{@iteration}, flip #{@numFlip}, evaluation count #{$totalEvaluationCount}"

		current_state_int = perturbation(current_state_int, @pertubation_strength)
		visit(current_state_int)
		boundedIncTimeSpentInState(current_state_int, nil)

		current_state_int = basic_local_search(current_state_int)
		
		unless @pert_rand
			#=== Acceptance criterion.
			acc_state_int = acceptance_criterion(last_ils_state_int, current_state_int)
			#=== With low probability, random restart.
			if rand(100) < @p_restart*100
				output "Random re-initialisation to #{str(acc_state_int)}"
				acc_state_int = init_random() 
				visit(acc_state_int)
				boundedIncTimeSpentInState(acc_state_int, nil)
			end
			current_state_int = acc_state_int
		end
		last_ils_state_int = current_state_int
		@iteration += 1
	end
end

# =========================================
# Init local search with default.
# =========================================
def init_default()
	init_state = Hash.new
	for param in @params
		init_state[param] = @default[param]
	end
	for key in @start_ass.keys
		init_state[key] = @start_ass[key]
	end
	for key in @fixed_ass.keys
		init_state[key] = @fixed_ass[key]
	end
	return full_state_to_full_int(init_state)
end

# =========================================
# Init local search with random values whose combination is allowed.
# =========================================
def init_random()
	is_forbidden = true
	while is_forbidden
		init_state = Hash.new
		for param in @params
			init_state[param] = @domain[param][rand(@domain[param].length)]
		end
		for key in @fixed_ass.keys
			init_state[key] = @fixed_ass[key]
		end
		is_forbidden = forbidden(init_state, @forbidden_combos)
	end
	return full_state_to_full_int(init_state)
end

# =========================================
# Basic local search.
# =========================================
def basic_local_search(start_state_int)
	current_state_int = start_state_int
	
#	@numEvaluationsThisIteration = 0
	output "   BLS in iteration #{@iteration}, start with #{str(current_state_int)}\n"
	visited_states = [current_state_int]
	changed = true
	while changed and not haveToStop() # local search.
		changed = false
		#=== Get array of [neighbouring state, param to change, old value, value to set it to]
		neighbours = neighbourhood(current_state_int)
		numNeighboursEvaluated = 0
		cpuBefore = $total_cputime
		numEvalsBefore = $totalEvaluationCount
		#=== Move to the first better neighbour
		while neighbours.length > 0 and not haveToStop()
			rand_index = rand(neighbours.length)
			
			neighbour_full_state, param, oldVal, newVal = neighbours[rand_index]
			neighbour_int = full_state_to_full_int(neighbour_full_state)
			neighbours.delete_at(rand_index)

			#=== To avoid loops, disallow state we have been at in this iteration.
			next if visited_states.include?(neighbour_int) 
			visited_states << neighbour_int 

			output("    Changing #{changed_between_states(current_state_int, neighbour_int)}, evaluating ...")
			if better(neighbour_int, current_state_int)
				#=== TODO: check if tie, increment counters accordingly. (and change output)
				output("          -> Take improving step to neighbour #{str(neighbour_int)} with flip #{@numFlip}\n\n")  
				current_state_int = neighbour_int
				
				#=== Bonus runs in FocusedILS.
				if @approach =~ /focused/
					numBonus = @numEvaluationsThisIteration
					output("          \n============= Performing #{numBonus} bonus runs of state: #{str(current_state_int)} ============ \n\n")  
					addNewRuns(current_state_int, numBonus)
					output("          -> After #{numBonus} bonus runs: #{str(current_state_int)}\n\n")  
					@numEvaluationsThisIteration=0
				end

				##=== Treat this state as a local minimum if we have reached a maximum level of detail for the generation of LMs (maximal path length).
				#break if detail(state_string(current_state)) == @maxDetail

				changed = true
				break
			else 
				#=== TODO: check if tie, increment counters accordingly. (and change output)
				output "        -> worse: #{str(neighbour_int,false)}"
			end
			numNeighboursEvaluated += 1
			break if numNeighboursEvaluated > @numNeighboursToEvaluate
		end
		incumbent_bound = @cachedResultScalars[$full_int_to_stripped_int[@incumbent_state_int]][detail(@incumbent_state_int)-1]
#		@stepstats_out.puts "#{@numFlip}, #{@iteration}, #{numNeighboursEvaluated+1}, #{$total_cputime-cpuBefore}, #{$totalEvaluationCount-numEvalsBefore}, #{incumbent_bound}"
#		@stepstats_out.flush
		@numFlip += 1
	end
	
	#=== We now found a local minimum (w.r.t. the limited random neighbourhood we looked at)
	lm_state_int = current_state_int
	
	#=== Bonus runs in FocusedILS
	if @approach =~ /focused/
		numBonus = @numEvaluationsThisIteration
		output("          \n============= Performing #{numBonus} bonus runs of state: #{str(lm_state_int)} ============ \n\n")  
		addNewRuns(lm_state_int, numBonus)
		output("          -> After #{numBonus} bonus runs for LM: #{str(lm_state_int)}\n\n")  
		@numEvaluationsThisIteration=0
	end
	
	@allVisitedStates[lm_state_int]["timesLM"] += 1

	output "   LM for iteration #{@iteration}: #{str(lm_state_int)}\n"
	output "\n========== DETAILED RESULTS (iteration #{@iteration}): =========="
	output_result(lm_state_int)
	output "================================================\n"

incumbent_stripped = $stripped_int_to_stripped_state[$full_int_to_stripped_int[@incumbent_state_int]]
res,n,c = eval(@incumbent_state_int)
output "\n==================================================================\nBest parameter configuration found so far (end of iteration #{@iteration}): #{incumbent_stripped.keys.map{|x| "#{x}=#{incumbent_stripped[x]}"}.join(", ") }\n"
output "==================================================================\nTraining quality of this incumbent parameter configuration: #{res}, based on #{n} runs with cutoff #{c}\n==================================================================\n\n"


	#=== Compare every LM against incumbent state.
	output "Comparing LM against incumbent:\n#{str(lm_state_int)}\n#{str(@incumbent_state_int)}"
	if betterWithoutAutomaticIncrease(lm_state_int, @incumbent_state_int, true)
		output "LM better, change incumbent"
		setNewIncumbent(lm_state_int)
	else
		output "Incumbent better, keeping it"
	end
	
	return lm_state_int
end

# =========================================
# Simple pertubation.
# =========================================
def perturbation(state_int, strength)
	if @pert_rand
		result_state_int = init_random
	else
		result_state_int = state_int
		strength.times{|x|
			neighbours = neighbourhood(result_state_int)
			rand_index = rand(neighbours.length)
			result_state_int = full_state_to_full_int(neighbours[rand_index][0])
#			puts "    perturb to ---> #{str(result_state_int)}" # Don't need to evaluate at this point!
			output "    perturb to ---> #{str(result_state_int)}" # Don't need to evaluate at this point!
		}
	end
	return result_state_int
end

# =========================================
# Acceptance criterion BETTER.
# =========================================
def acceptance_criterion(last_ils_state_int, current_state_int)
	if last_ils_state_int == current_state_int
		output "same state as last ILS: #{str(last_ils_state_int)}"
		@accepted_last = "same"
		return current_state_int
	end

	if betterWithoutAutomaticIncrease(current_state_int, last_ils_state_int) 
		output "   Accepting new better local optimum: #{str(current_state_int)}"
		@accepted_last = "acc"
		return current_state_int
	end

	output "rejecting worse #{str(current_state_int)}, going back to #{str(last_ils_state_int)}"
	@accepted_last = "rej"
	return last_ils_state_int
end

# =========================================
# Return what changed between two states.
# =========================================
def changed_between_states(old_state_int, new_state_int)
	res = []
	old_state = $int_to_full_state[old_state_int]
	new_state = $int_to_full_state[new_state_int]
	for key in old_state.keys
		res << "#{key}: #{old_state[key]}->#{new_state[key]}" if old_state[key] != new_state[key]
	end
	return res
end

def output_help(out)
#	puts ARGV.join(" --- ")
	
	out.puts "\n======================================================================================================"
	out.puts "PARAM_ILS version 2.3.8, copyright Frank Hutter, 2004-2013."
	out.puts "This software optimizes parameters of algorithms. See the quick start guide for a description."
	out.puts "For more details, see: \"Frank Hutter, Holger Hoos, and Thomas Stueztle:"
	out.puts  "Automatic Algorithm Configuration based on Local Search. In Proc. of AAAI-07\"."
	out.puts "======================================================================================================\n"
	out.puts "Usage: paramils -scenariofile <file> -numRun <numRun>, followed by a number of optional arguments."
	out.puts "======================================================================================================"
	out.puts "The default is FocusedILS with a maximum of N=2000 runs per configuration.\nTo get BasicILS use -approach basic, for random search use -approach random."
	out.puts "======================================================================================================"
	out.puts "To change N, use -N <N>.\nTo change the number of independent test runs for the final parameter configuration, use -validN <validN> (default 1000 runs)."
	out.puts "To change the initialization, use -init <X>, where <X> is in {0,1} (0=random, 1=default [used if unspecified]), or <X> = \"<param1> <val1> <param2> <val2> ...\""
	
	out.puts "======================================================================================================"
	if is_win
		out.puts "Windows example:\n(this has a VERY small training and test set and is just meant for demonstration!)\nIn real applications, please use larger sets to avoid overtuning!!\n"
		out.puts "======================================================================================================"
		out.puts "param_ils_2_3_run.exe  -numRun 0 -scenariofile example_saps\\scenario-win-Saps-SWGCP-sat-small-train-small-test.txt -validN 100"
	else
		out.puts "Examples (These have VERY small training and test sets, this is just meant for demonstration!)\nIn real applications, please use larger sets to avoid overtuning!!"
		out.puts "======================================================================================================"
		out.puts "ruby param_ils_2_3_run.rb -numRun 0 -scenariofile example_saps/scenario-Saps-SWGCP-sat-small-train-small-test.txt -validN 100"
		out.puts "ruby param_ils_2_3_run.rb -numRun 0 -scenariofile example_saps/scenario-Saps-single-QWH-instance.txt -validN 100"
		out.puts "ruby param_ils_2_3_run.rb -numRun 0 -scenariofile example_spear/scenario-Spear-SWGCP-sat-small-train-small-test.txt -validN 100"
		out.puts "ruby param_ils_2_3_run.rb -numRun 0 -scenariofile example_cplex/scenario-Cplex-CATS-smalltrain-smalltest.txt -validN 100"
		out.puts "ruby param_ils_2_3_run.rb -numRun 0 -scenariofile example_saps/scenario-Saps-SWGCP-sat-small-train-small-test.txt -validN 0 -maxWallTime 6"
	end
	out.puts "======================================================================================================"
end

	
# =========================================
#                  MAIN
# =========================================

# ==== Init.

@eps = 1e-5
$statsfile = "jobserver_paramils_stats_#{rand}.txt"

#===  Create outfile
t = Time.now
now= t.strftime("%Y-%m-%dat%I-%M%p")

# =========================================
# ParamILS defaults.
# =========================================
@approach = "focused"
@init_def = 1
@algo = "saps"
@outdir = "paramils_out/"
@numRun = ""
@instance_seed_file = ""
@test_instance_seed_file = ""

@temporary_output_dir = ""

@run_obj = "runtime"
@overall_obj = "adj_mean"
validN = 1000


@N = 2000
@cutoff_time = 10
@cutoff_length = "max"
@maxEvals = 100000000
@tunerTimeout = 8640000 # 100 days
@maxIts = 200000000
@maxWallTime = 8640000 # 100 days

@db = 0 #=== For public release - for my own experiments, I always use the DB.
@jobserver = 0

@fix_input = ""
start_input = ""

@output_level = 50

$fakedCensoringForExactSameResults = false
deterministic = false
 
@R = 10
@pertubation_strength = 3
@relative_pertubation_strength = 0.2
@pertubation_strength_scaling = false
@p_restart = 0.01
@numNeighboursToEvaluate = 1000000
@pruning = true
@iterativeDeepening = false
@boundMultiplier = 2
@idn = false
@use_run_log = false
$stop_on_tie = false # was true in Chris' version, need to eval which one is better

$minimum_runtime = 0.1
#=== lambda_t is the ratio of time allocated to ILS executions with lower N and c.
lambda_t = 0.5

#=== lambda_N is the ratio of @N allocated to the second last ILS execution.
lambda_n = 0.5

#=== lambda_c is the ratio of @cutoff_time allocated to the second last ILS execution.
lambda_c = 0.5

@pert_rand = false
@optimum_solqual = -1000000000 # stop once we reach this !

lambda_str = ""

# =========================================
# Read in ParamILS-specific command line options.
# =========================================
0.step(ARGV.length-1, 2){|i|
	case ARGV[i]
	#=== The scenariofile may define any parameter.
	when "-scenariofile"
		@scenariofile = ARGV[i+1]
	when "-userunlog"
		if (ARGV[i+1] == "0" || ARGV[i+1] == "false")
			@use_run_log = false	
		elsif (ARGV[i+1] == "1" || ARGV[i+1] == "true")
			@use_run_log = true	
		end
	when "-temporary_output_dir"
		@temporary_output_dir = ARGV[i+1]
		begin
			 Dir.mkdir(@temporary_output_dir) unless FileTest.exist?(@temporary_output_dir) and FileTest.directory?(@temporary_output_dir)
		rescue
		end
	when "-instance_seed_file"
		@instance_seed_file = ARGV[i+1]
	when "-test_instance_seed_file"
		@test_instance_seed_file = ARGV[i+1]
	when "-instance_file"
		@instance_file = ARGV[i+1]
	when "-test_instance_file"
		@test_instance_file = ARGV[i+1]

	when "-approach"
		@approach = ARGV[i+1]
	when "-numRun"
		@numRun = ARGV[i+1].to_i
	when "-outdir"
		@outdir = ARGV[i+1]
	when "-deterministic"
		deterministic = ARGV[i+1]

	when "-algo"
		@algo = ARGV[i+1]
	when "-run_obj"
		@run_obj = ARGV[i+1]
	when "-overall_obj"
		@overall_obj = ARGV[i+1]
	when "-mintime"
		$minimum_runtime = ARGV[i+1].to_f
		
	when "-cutoff_time"
		@cutoff_time = ARGV[i+1]
	when "-cutoff_length"
		@cutoff_length = ARGV[i+1]
	when "-maxEvals"
		tmp = ARGV[i+1]
		tmp = 100000000000000000 if tmp == "max"
		@maxEvals = tmp.to_i
	when "-maxIts"
		tmp = ARGV[i+1]
		tmp = 100000000000000000 if tmp == "max"
		@maxIts = tmp.to_i
	when "-tunerTimeout"
		tmp = ARGV[i+1]
		tmp = 100000000000000000 if tmp == "max"
		@tunerTimeout = tmp.to_f
	when "-maxWallTime"
		tmp = ARGV[i+1]
		tmp = 100000000000000000 if tmp == "max"
		@maxWallTime = tmp.to_f
	when "-wallclock-limit"
		tmp = ARGV[i+1]
                tmp = 100000000000000000 if tmp == "max"
                @maxWallTime = tmp.to_f
	when "-pruning"
		@pruning = ARGV[i+1]
	when "-faked"
		$fakedCensoringForExactSameResults = ARGV[i+1]
	when "-validN"
		validN = ARGV[i+1].to_i
	when "-idn"
		@idn = ARGV[i+1].to_i
	when "-lambda_c"
		lambda_c = ARGV[i+1].to_f
		lambda_str += "-lambda_c#{lambda_c}"
	when "-lambda_t"
		lambda_t = ARGV[i+1].to_f
		lambda_str += "-lambda_t#{lambda_t}"
	when "-lambda_n"
		lambda_n = ARGV[i+1].to_f
		lambda_str += "-lambda_n#{lambda_n}"
	when "-stopOnTie"
		$stop_on_tie = ARGV[i+1]
			
#=== tuning parameter
	when "-ps"
		@pertubation_strength = ARGV[i+1].to_i
	when "-rps"
		@relative_pertubation_strength = ARGV[i+1].to_f
	when "-psr"
		@pertubation_strength_scaling = ARGV[i+1].to_i
	when "-rw_prob"
		@p_restart = ARGV[i+1].to_f
	when "-R"
		@R = ARGV[i+1].to_i
	when "-mN"
		@numNeighboursToEvaluate = ARGV[i+1].to_i
#	when "-maxDetail"
#		@maxDetail = ARGV[i+1].to_i
	when "-prand"
		@pert_rand = ARGV[i+1]
	when "-id"
		@iterativeDeepening =  ARGV[i+1].to_i
	when "-bm"
		@boundMultiplier =  ARGV[i+1].to_f

	when "-init"
		if ARGV[i+1].to_s == "0" or  ARGV[i+1].to_s == "1"
			@init_def  = ARGV[i+1].to_s
			@init_def = false if @init_def == "0"
		else
			#=== Start input values are at least partly user-defined, rest: default.
			@init_def  = ARGV[i+1]
			fileWithDef = ARGV[i+1]
			File.open(fileWithDef, "r"){|file| start_input = file.gets.chomp}
		end
	when "-N"
		@N = ARGV[i+1].to_i
		
		
	when "-db"
		@db = ARGV[i+1]
	when "-jobserver"
		@jobserver = ARGV[i+1].to_i

	when "-paramfile"
		$param_file = ARGV[i+1]
	when "-fix"
		@fix_input  = ARGV[i+1]

	when "-output_level"
		@output_level = ARGV[i+1].to_i
		
	when "-execdir"
		$execdir = ARGV[i+1]

	else
		output_help($stdout)
		puts "\n\n"
		raise "Unknown argument: #{ARGV[i]}"
	end
}

if ARGV.length < 1
	output_help($stdout)
	exit -1
end

if @numRun == ""
	output_help($stdout)
	puts "\n\n"
	puts "Input error. You HAVE to specify #{-numRun} <numRun> (different runs use different training sets and seeds)" 
	exit -1
end

#=== If a scenariofile is provided, use that to override any specified parameters.
#=== Currently, this is limited to the specified parameters - would be nicer to have it automatic for all parameters...
if @scenariofile
	scenarioparams = {"algo" => @algo, "run_obj"=>@run_obj, "overall_obj"=>@overall_obj, "cutoff_time"=>@cutoff_time, 
			"cutoff_length"=>@cutoff_length, "tunerTimeout"=>@tunerTimeout, "deterministic"=>deterministic,
			"instance_seed_file"=>@instance_seed_file, "test_instance_seed_file"=>@test_instance_seed_file,
			"instance_file"=>@instance_file, "test_instance_file"=>@test_instance_file,
			"execdir"=>$execdir, "outdir"=>@outdir, "paramfile"=>$param_file, "feature_file"=>nil, "wallclock-limit"=>@maxWallTime} # FH: added feature_file for convenient reading of SMAC scenario files
	File.open(@scenariofile){|file|
		while line = file.gets
			recognized = false
			next if line =~ /^\s*$/
			for paramindicator in scenarioparams.keys
				if line =~ /^#{paramindicator}\s*=(.*)/
					entry = $1.strip
					scenarioparams[paramindicator] = entry
					recognized = true
					break
				end
			end
			unless recognized 
				puts "Input error: Unrecognized entry #{line} in scenario file #{@scenariofile}:\n\n#{line}\n\nEach line has to start with one of the following: [#{scenarioparams.keys.sort.join(", ")}], and then be followed by = <value> (where <value> is the desired value)." 
				exit -1
			end
		end
	}
	#=== Assign the values to the parameters in question - I know things like this can be automized in Ruby, but I'm lacking the time ...
	deterministic = scenarioparams["deterministic"]
	@algo = scenarioparams["algo"]
	@run_obj = scenarioparams["run_obj"]
	@overall_obj = scenarioparams["overall_obj"]
	@cutoff_time = scenarioparams["cutoff_time"]
	@cutoff_length = scenarioparams["cutoff_length"]
	@tunerTimeout = scenarioparams["tunerTimeout"].to_f
	@instance_seed_file = scenarioparams["instance_seed_file"].sub(/<numRun>/,"#{@numRun}")
	@test_instance_seed_file = scenarioparams["test_instance_seed_file"].sub(/<numRun>/,"#{@numRun}")
	@instance_file = scenarioparams["instance_file"]
	@test_instance_file = scenarioparams["test_instance_file"]
	
	$execdir = File.expand_path(scenarioparams["execdir"])
	@outdir = File.expand_path(scenarioparams["outdir"])
	$param_file = File.expand_path(scenarioparams["paramfile"])
	@maxWallTime = scenarioparams["wallclock-limit"]

	if ((@run_obj =~ /qual/ || @run_obj =~ /approx/) && 
			(@overall_obj =~ /mean/ || @overall_obj =~ /avg/))
		@pruning = false
	end
=begin
# HACK TO OVERWRITE CERTAIN SCENARIO FILE SETTINGS

0.step(ARGV.length-1, 2){|i|
        case ARGV[i]
	when "-algo"
                @algo = ARGV[i+1]
	when "-execdir"
                $execdir = ARGV[i+1]
 	end
}
=end

end

puts "max wall time = " + @maxWallTime.to_s

raise "Input error: If instance_file is specified the instance_seed_file is automatically generated - but you provided both." if @instance_seed_file != "" and @instance_file
raise "Input error: If test_instance_file is specified the test_instance_seed_file is automatically generated - but you provided both." if @test_instance_seed_file != "" and @test_instance_file
raise "Input error: You must provide an instance_file or an instance_seed_file." unless (@instance_seed_file != "" or @instance_file)
raise "Input error: You must provide a test_instance_file or a test_instance_seed_file." unless (@test_instance_seed_file != "" or @test_instance_file)
	
# =========================================
#=== Deal with parameters.
# =========================================

$param_file = "#{$execdir}params.txt" unless $param_file
puts $param_file

@maxDetail = @N

@db = false if @db == "0" or @db  == "false" or @db  == 0
@pruning = false if @pruning == "0" or @pruning  == "false" or @pruning  == 0
$fakedCensoringForExactSameResults = false if $fakedCensoringForExactSameResults == "0" or $fakedCensoringForExactSameResults  == "false" or $fakedCensoringForExactSameResults == 0
@iterativeDeepening = false if @iterativeDeepening == "0" or @iterativeDeepening  == "false" or @iterativeDeepening == 0
@idn = false if @idn == "0" or @idn == "false" or @idn == 0
deterministic = false if deterministic == "0" or deterministic == "false" or deterministic == 0

@pertubation_strength_scaling = false if @pertubation_strength_scaling == "0" or @pertubation_strength_scaling == "false" or @pertubation_strength_scaling == 0

id_string = ""
id_string = "-id" if @iterativeDeepening
id_string = "-idn" if @idn == 1
id_string = "-idnn" if @idn == 2

raise "idn but no id" if @idn and not @iterativeDeepening 

@pert_rand = false if @pert_rand == "0" or @pert_rand == "false" or @pert_rand == 0
@pert_rand = true if @pert_rand == "1" or @pert_rand == "true" or @pert_rand == 1

pstring = ""
pstring = "prand-" if @pert_rand

#=== Only I am using the database.
$user_frank = @db
$fakedCensoringRuntime = @cutoff_time

fakedExactString = ""
fakedExactString = "faked-" if $fakedCensoringForExactSameResults

pruning_string = ""
pruning_string = "-prune" if @pruning
	
@cutoff_time = 1000000000 if @cutoff_time == "max"
@cutoff_time = @cutoff_time.to_f

@maxWallTime = 1000000000 if @maxWallTime == "max"
@maxWallTime = @maxWallTime.to_f

@cutoff_length = 2147483647 if @cutoff_length == "max"
@cutoff_length = @cutoff_length.to_i

@maxEvals = 1000000000 if @maxEvals == "max"

@oncluster = @jobserver

if @outdir == ""
	if @instance_seed_file != ""
		@outdir, tmp = File.split(@instance_seed_file)
	else
		@outdir, tmp = File.split(@instance_file)
	end
	@outdir = @outdir + "/paramils-out"
end

# =========================================
# Initial setup.
# =========================================
require "dbi_ils_accessor.rb" if @db
$total_cputime = 0

dir, subdir = File.split(@outdir)
begin
	Dir.mkdir(dir) unless FileTest.exist?(dir) and FileTest.directory?(dir)
rescue 
end
begin
	Dir.mkdir(@outdir) unless FileTest.exist?(@outdir) and FileTest.directory?(@outdir)
rescue
end

#=== Read params from param file.
@params, @domain, @default, $conditionals, @forbidden_combos = read_params($param_file) # Need conditionals as global to enable strip_state in param_reader
num_params = 0
num_combos = 1
for param in @params
	num_params += 1 if @domain[param].length>1
	num_combos *= @domain[param].length
end
puts "num_params = #{num_params}, num_combos=#{num_combos}"

if @pertubation_strength_scaling
	pert_string = "psr#{@relative_pertubation_strength}-"
	@pertubation_strength = [2, (@relative_pertubation_strength*num_params).ceil].max
else
	pert_string = "ps#{@pertubation_strength}-"
end

bm_string = ""
bm_string = "-bm#{@boundMultiplier}" if @pruning

mNString = ""
mNString = "#-mN{@numNeighboursToEvaluate}" unless @numNeighboursToEvaluate == 1000000

max_it_string = ""
max_it_string = "-maxit#{@maxIts}" unless @maxIts == 20000

#log_filename = "#{@outdir}/#{@approach}-#{fakedExactString}#{pstring}#{pert_string}log-algo#{@algo}-runobj#{@run_obj}-overallobj#{@overall_obj}-runs#{@N}-time#{@cutoff_time}#{mNString}-init#{@init_def}#{id_string}#{seed_string}#{pruning_string}#{bm_string}#{lambda_str}#{max_it_string}_#{@numRun}#{meta_string}.txt"
#traj_filename = "#{@outdir}/#{@approach}-#{fakedExactString}#{pstring}#{pert_string}traj-algo#{@algo}-runobj#{@run_obj}-overallobj#{@overall_obj}-runs#{@N}-time#{@cutoff_time}#{mNString}-init#{@init_def}#{id_string}#{seed_string}#{pruning_string}#{bm_string}#{lambda_str}#{max_it_string}_#{@numRun}#{meta_string}.txt"
#stats_filename = "#{@outdir}/#{@approach}-#{fakedExactString}#{pstring}#{pert_string}stats-algo#{@algo}-runobj#{@run_obj}-overallobj#{@overall_obj}-runs#{@N}-time#{@cutoff_time}#{mNString}-init#{@init_def}#{id_string}#{seed_string}#{pruning_string}#{bm_string}#{lambda_str}#{max_it_string}_#{@numRun}#{meta_string}.txt"
#stepstats_filename = "#{@outdir}/#{@approach}-#{fakedExactString}#{pstring}#{pert_string}stepstats-algo#{@algo}-runobj#{@run_obj}-overallobj#{@overall_obj}-runs#{@N}-time#{@cutoff_time}#{mNString}-init#{@init_def}#{id_string}#{seed_string}#{pruning_string}#{bm_string}#{lambda_str}#{max_it_string}_#{@numRun}#{meta_string}.txt"
#test_output_filename = "#{@outdir}/#{@approach}-#{fakedExactString}#{pstring}#{pert_string}algo#{@algo}-runobj#{@run_obj}-overallobj#{@overall_obj}-runs#{@N}-time#{@cutoff_time}#{mNString}-init#{@init_def}#{id_string}#{seed_string}#{pruning_string}#{bm_string}#{lambda_str}#{max_it_string}_#{@numRun}#{meta_string}_test.txt"

algostr = @algo
algostr = algostr.gsub(/ /,"")
algostr = algostr.gsub(/\//,"")
#filepart = "#{@outdir}/#{@approach}-runs#{@N}-runobj#{@run_obj}-overallobj#{@overall_obj}#{max_it_string}#{bm_string}-time#{@cutoff_time}-tunerTime#{@tunerTimeout}-algo#{algostr}"
filepart = "#{@outdir}/#{@approach}-runs#{@N}-runobj#{@run_obj}-overallobj#{@overall_obj}#{max_it_string}#{bm_string}-time#{@cutoff_time}-tunerTime#{@tunerTimeout}-algoAlgo" # to avoid too long filenames

runlog_filename = "#{filepart}-runlog_#{@numRun}.txt"
log_filename = "#{filepart}-log_#{@numRun}.txt"
traj_filename = "#{filepart}-traj_#{@numRun}.txt"
traj_csv_filename = "#{filepart}-traj_#{@numRun}.csv"
test_output_filename = "#{filepart}-test_#{@numRun}.txt"
result_filename = "#{filepart}-result_#{@numRun}.txt"

@out = File.open(log_filename, "w")
@param_ils_traj_file = File.open(traj_filename, "w")
@param_ils_traj_csv = File.open(traj_csv_filename, "w")
@param_ils_runlog_file = File.open(runlog_filename, "w")
#@stepstats_out = File.open(stepstats_filename , "w")

string_arguments = ARGV.map{|x| "\"#{x}\""}.join(" ")
#string_arguments = ARGV.join(" ")
@out.puts "Call: /usr/bin/ruby ../scripts/param_ils_2_3_run.rb #{string_arguments}\n\n\n"
#output_help(@out)
@out.flush

#=== Build fixed parameters.
@fixed_ass = set_fixed_params(@fix_input, @domain, @params, @out)
@start_ass = set_fixed_params(start_input, @domain, @params, @out)

@number_of_params_to_opt = @params.length - @fixed_ass.keys.length


#=== Use random seed dependent on the run number. 
seedForParamILS = (@numRun+1)*1234 # Seed for Param_ILS, not the one to pass on to algorithms.
srand(seedForParamILS)

#=== Build @instances from file
@instances = []
if @instance_seed_file == ""
	line_list = []
	File.open(File.expand_path(@instance_file)){|file| 
		while line=file.gets;
			line_list << line.chomp.strip unless line.chomp.empty?
		end
	}
	orig_list = line_list.dup

	2000.times{|i|
		if line_list.empty?
			line_list = orig_list.dup
			break if deterministic
		end
		line = line_list[rand(line_list.length)]

		line_list.delete(line)
		if deterministic
			seed = -1
		else
			seed = rand(2147483647)
		end
		
		entries = line.strip.split
		inst = entries[0]
#		inst = File.expand_path(inst)                # FH: dropped; this might not even be a path, and even if it is relative should be fine
		rest = entries[1...entries.length].join(" ")
		@instances << {"seed"=>seed, "name"=>inst, "rest"=>rest, "resultForState"=>Hash.new}
	}
	
	#=== For repeatibility, output the corresponding instance_seed_file:
	tmp, basename = File.split(@instance_file)
	filename = "#{@outdir}/instance_seed_file_saved-#{basename}-numRun_#{@numRun}.txt"
	File.open(filename, "w"){|file|
		@instances.map{|entry| file.puts "#{entry["seed"]} #{entry["name"]} #{entry["rest"]}"}
	}
else
	File.open(File.expand_path(@instance_seed_file)){|file| 
	    while line=file.gets;
		raise "Have to have at least 2 entries per line, namely seed and instance name; line #{line.chomp} only has #{line.strip.split.length} entries" unless line.strip.split.length >= 2 
		next if line.chomp.empty?
		entries = line.strip.split
		seed = entries[0].to_i
		inst = entries[1] # was: inst = File.expand_path(entries[1]), but that doesn't use the right instance names and puts new instances into the DB
		rest = entries[2...entries.length].join(" ")
		@instances << {"seed"=>seed, "name"=>inst, "rest"=>rest, "resultForState"=>Hash.new}
	    end
	}
end

#=== Build @test_instances from file
@test_instances = []
if @test_instance_seed_file == ""
	line_list = []
	File.open(File.expand_path(@test_instance_file)){|file| 
		while line=file.gets;
			line_list << line.chomp.strip unless line.chomp.empty?
		end
	}
	orig_list = line_list.dup
	2000.times{|i|
		if line_list.empty?
			line_list = orig_list.dup
			break if deterministic
		end
		line = line_list[rand(line_list.length)]
		line_list.delete(line)
		if deterministic
			seed = -1
		else
			seed = rand(2147483647)
		end
		
		entries = line.strip.split
		
		inst = entries[0]
#		inst = File.expand_path(inst)                # FH: dropped; this might not even be a path, and even if it is relative should be fine
        rest = entries[1...entries.length].join(" ")

		@test_instances << {"seed"=>seed, "name"=>inst, "rest"=>rest, "resultForState"=>Hash.new}
	}
	#=== For repeatibility, output the corresponding instance_seed_file:
	tmp, basename = File.split(@test_instance_file)
	filename = "#{@outdir}/test_instance_seed_file_saved-#{basename}-numRun_#{@numRun}.txt"
	File.open(filename, "w"){|file|
		@test_instances.map{|entry| file.puts "#{entry["seed"]} #{entry["name"]} #{entry["rest"]}"}
	}
else
	File.open(File.expand_path(@test_instance_seed_file)){|file| 
	    while line=file.gets;
		next if line.chomp.empty?
		raise "Have to have at least 2 entries per line, namely seed and instance name; line #{line.chomp} only has #{line.strip.split.length} entries" unless line.strip.split.length >= 2 
		entries = line.strip.split
		seed = entries[0].to_i
		inst = entries[1]
#		inst = File.expand_path(inst)            # FH: dropped; this might not even be a path, and even if it is relative should be fine
		rest = entries[2...entries.length].join(" ")
		@test_instances << {"seed"=>seed, "name"=>inst, "rest"=>rest, "resultForState"=>Hash.new}
	    end
	}
end

if (@N > @instances.length)
        output "WARNING: N=#{@N} is greater than the number of entries
in the @instances array. This can happen if the algorithm is
deterministic and the number of training instances is smaller than N,
or if the instance_seed_file is provided by the user and has less
entries than N. Clamping N and maxDetail to #{@instances.length}"

        @N = @instances.length
        @maxDetail = @N
end

if (validN > @test_instances.length)
        output "WARNING: validN=#{validN} is greater than the number
of entries in the @test_instances array. This can happen if the
algorithm is deterministic and the number of test instances is smaller
than validN, or if the test_instance_seed_file is provided by the user
and has less entries than validN. Clamping validN to
#{@test_instances.length}"

        validN = @test_instances.length
end

@instances = @instances[0...@N]
@test_instances = @test_instances[0...validN]
Dir.chdir($execdir) if $execdir


# =========================================
#=== Output parameters.
# =========================================
puts "seed: #{seedForParamILS}"
@out.puts "seed: #{seedForParamILS}"

@out.puts "algo: #{@algo}"
@out.puts "tunerTimeout (CPU time): #{@tunerTimeout}"
@out.puts "maxWallTime: #{@maxWallTime}"
@out.puts "maxEvals: #{@maxEvals}"

@out.puts "run_obj: #{@run_obj}"
@out.puts "overall_obj: #{@overall_obj}"

if @instance_seed_file != ""
	@out.puts "instance_seed_file: #{@instance_seed_file}"
else
	@out.puts "instance_file: #{@instance_file}"
end

if @test_instance_seed_file != ""
	@out.puts "test_instance_seed_file: #{@test_instance_seed_file}"
else
	@out.puts "test_instance_file: #{@test_instance_file}"
end
@out.puts "N: #{@N}"

@out.puts "cutoff_time: #{@cutoff_time}"
@out.puts "cutoff_length: #{@cutoff_length}"

@out.puts "R: #{@R}"
@out.puts "pertubation_strength_basic: #{@pertubation_strength_basic}"
@out.puts "pertubation_strength_scaling: #{@pertubation_strength_scaling}"
@out.puts "p_restart: #{@p_restart}"

#=== Reset the seed at this point to get exactly the same behaviour as ParamILS version 2.1
srand(seedForParamILS) 
# =========================================
#=== Execute ParamILS.
# =========================================

$total_cputime = 0
$totalEvaluationCount = 0
@lastOutputCPUTime = 0

puts("Run #{@numRun+1}")
@out.puts("Run #{@numRun+1}")

@param_ils_traj_file.puts "Run #{@numRun+1}"
@param_ils_traj_csv.puts "\"Total Time\",\"Mean Performance\",\"Wallclock Time\",\"Incumbent ID\",\"Automatic Configurator Time\",\"Configuration...\""

@start_time_wallclock = Time.now

init_state_int = init_search()

if @iterativeDeepening
	if lambda_n < 1-@eps
		numDepths = (Math.log(@N) / Math.log(1.0/lambda_n)).ceil + 1
	else
		numDepths = (Math.log(@cutoff_time) / Math.log(1.0/lambda_c)).ceil + 1
		p numDepths 
	end

	@nForDepth = []
	@cForDepth = []
	@tForDepth = []
	@eForDepth = []

	numDepths.times{|i| 
		@nForDepth[i] = ((@N+0.0) * (lambda_n**(numDepths-1-i))).ceil
		@cForDepth[i] = ((@cutoff_time+0.0) * (lambda_c**(numDepths-1-i))).ceil
		@tForDepth[i] = (@tunerTimeout+0.0) * (lambda_t**(numDepths-1-i))
		@eForDepth[i] = @maxEvals # (@maxEvals+0.0) * (lambda_t**(numDepths-1-i))
		puts "#{@nForDepth[i]} #{@cForDepth[i]} #{@tForDepth[i]}"
	}

	@nStart = 1
	numDepths.times{|depth|
		init_state_int = iterative_deepening_ils(depth+1, init_state_int)
		@R = 0 #=== Don't need random moves anymore.
		
		#=== For FocusedILS: Compute number of runs to give the incumbent from the last phase to start the new phase.
		if @idn and depth != numDepths-1
			@nStart = (detail(init_state_int) * @cForDepth[depth]) / @cForDepth[depth+1]
		else
			@nStart = 1
		end
	}
else
	@nStart = 1
	@nForDepth = [@N]
	@cForDepth = [@cutoff_time]
	@tForDepth = [@tunerTimeout]
	@eForDepth = [@maxEvals]
	iterative_deepening_ils(1, init_state_int)
end

# =========================================
#=== Statistics after the execution is over.
# =========================================

=begin
#=== Output gathered statistics.
puts stats_filename
File.open(stats_filename, "w"){|file|
	for full_state_int in @orderedVisitedStates
		hash = @allVisitedStates[full_state_int]
		resDetail = detail(full_state_int)
		cens = @censoringThresholdPerLevelOfDetail[resDetail-1]
		n = @numRunsPerLevelOfDetail[resDetail-1]
		res = @cachedResultScalars[$full_int_to_stripped_int[full_state_int]][resDetail-1]

		file.puts "#{hash["number"]}, #{res}, #{n}, #{hash["iteration"]}, #{cens}, #{hash["str"]}"	
#		file.puts "#{hash["number"]}, #{resDetail}, #{res}, #{hash["numVisited"]}, #{hash["totalTime"]}, #{hash["timesLM"]}, #{hash["timesMadeIncumbent"]}"
	end
}
=end

#=== Evaluate test/validation performance.
final_state = $int_to_full_state[@incumbent_state_int]
final_stripped_state = $stripped_int_to_stripped_state[$full_int_to_stripped_int[@incumbent_state_int]]
res,n,c = eval(@incumbent_state_int)

output "\n==================================================================\nParamILS is finished.\n==================================================================\n\nFinal best parameter configuration found: "+@params.map{|x| "#{x}=#{final_state[x]}"}.join(", ")+"\n"
output "=================================================================="
output "Active parameters: #{@params.select{|x| final_stripped_state.keys.include?(x)}.map{|x| "#{x}=#{final_state[x]}"}.join(", ")}\n"
output "\n==================================================================\nTraining quality of this final best found parameter configuration: #{res}, based on #{n} runs with cutoff #{c}\n==================================================================\n\n"
output "\n==================================================================\nComputing validation result on independent data -- #{@test_instances.length} runs with cutoff time #{@cutoff_time}...\n=================================================================="

test_results = getRunsOnEntriesWithParams(@test_instances, @incumbent_state_int, @cutoff_time, true)
for i in 0...@test_instances.length
	output "#{@test_instances[i]["name"]}: #{test_results[i]}"
end
test_result = combinationOfObjectiveFunctions(@algo, @overall_obj, test_results, @run_obj, @cutoff_time, @cutoff_length)
output "Combined result: #{test_result}"
File.open(test_output_filename, "w"){|file|
	file.puts test_result
}

output "\n================================================================\n\Final best parameter configuration: "+@params.map{|x| "#{x}=#{final_state[x]}"}.join(", ")+"\n"
output "=================================================================="
output "Active parameters: #{@params.select{|x| final_stripped_state.keys.include?(x)}.map{|x| "#{x}=#{final_state[x]}"}.join(", ")}\n"
output "\n================================================================\nTraining quality of this final best found parameter configuration: #{res}, based on #{n} runs with cutoff #{c}"
output "Test quality of this final best found parameter configuration: #{test_result}, based on #{@test_instances.length} independent runs with cutoff #{@cutoff_time}\n=================================================================="

@out.close
@param_ils_traj_file.close
@param_ils_traj_csv.close
@param_ils_runlog_file.close

#=== Write these last lines into the result file.
File.open(result_filename, "w"){|file|
	file.puts "Final best parameter configuration: "+@params.map{|x| "#{x}=#{final_state[x]}"}.join(", ")+"\n"
	file.puts "=================================================================="
	file.puts "Active parameters: #{@params.select{|x| final_stripped_state.keys.include?(x)}.map{|x| "#{x}=#{final_state[x]}"}.join(", ")}\n"
	file.puts "=================================================================="
	file.puts "Training quality of this final best found parameter configuration: #{res}, based on #{n} runs with cutoff #{c}"
	file.puts "Test quality of this final best found parameter configuration: #{test_result}, based on #{@test_instances.length} independent runs with cutoff #{@cutoff_time}"
}
