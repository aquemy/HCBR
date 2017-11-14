def float_regexp()
	return '[+-]?\d+(?:\.\d+)?(?:[eE][+-]\d+)?';
end

# ================================================
# Read parameters from executable.
# ================================================
def read_params(paramfile) 
	params = []
	domain = Hash.new
	default = Hash.new
	conditionals = Hash.new
	forbidden_combos = []

	File.open(paramfile){|file|
		#=== Match parameter format: param_name {value1,value2,...}[default_value]
		while line = file.gets
			next if line =~ /^\s*(#.*)?\n$/ # deal with empty and comment lines
			next unless line =~ /^(.*)\s*\{(.*)\}\s*\[(.*)\]/ 
			line =~ /^(.*)\s*\{(.*)\}\s*\[([^\]]*)\]/
			parname, vals, default_val = $1.strip, $2.strip, $3.strip
			values = vals.strip.split(",").map{|x|x.strip} #Match values.
			#=== Check whether possible values include default - deal with possible different number formats.
			unless values.include?(default_val)
				if default =~ /(#{float_regexp})/
					def_f = $1.to_f
					for val in values
						default = $1 if val =~ /(#{float_regexp})/ and $1.to_f == def_f
					end
				end
				raise "default value #{default_val} is not a possible value for #{parname}. Only #{values.join(",")} are ok." unless values.include?(default_val)
			end
			domain[parname] = values
			default[parname] = default_val
		end
#		p line
#		p domain
		params = domain.keys.sort
	}

	File.open(paramfile){|file|
		#=== Deal with conditional parameters.
		#=== Example: parameter a is only relevant if c=1 or c=2: "a|c in {1,2}"
		#=== Match lines with conditional rules.
		while line=file.gets 
			next if line =~ /^\s*(#.*)?\n$/ # deal with empty and comment lines
			next unless line =~ /^(.*)\|(.*) in \{(.*)\}/ 
			line =~ /^(.*)\|(.*) in \{(.*)\}/
			conditional_param, deciding_param, deciding_vals = $1, $2, $3
			conditional_param.strip!
			deciding_param.strip!
			deciding_vals = deciding_vals.strip.split(",").map{|x|x.strip}
			
			#=== Make sure there are no errors.
			puts "WARNING. Conditional parameter #{conditional_param} does not exist." unless params.include?(conditional_param) 
			puts "WARNING. Variable #{deciding_param} which #{conditional_param} is conditional on does not exist." unless params.include?(deciding_param)
			deciding_vals.each{|x| 
#				puts "WARNING. Value #{x} of variable #{deciding_param} which #{conditional_param} is conditional on does not exist." unless domain[deciding_param].include?(x)
			}
#			deciding_vals.map!{|x| domain[deciding_param].index(x)}
			conditionals[conditional_param] = Hash.new unless conditionals.key?(conditional_param)
			conditionals[conditional_param][deciding_param] = deciding_vals
		end
#			puts line
	}
	
	File.open(paramfile){|file|
		while line=file.gets
			next if line =~ /^\s*(#.*)?\n$/ # deal with empty and comment lines
#			puts "1: #{line}"
			next unless line =~ /\{.*\}/
#			puts "2: #{line}"
			next if line =~ /\[.*\]/ 
#			puts "3: #{line}"
			next if line =~ /\|/
#			puts "4: #{line}"
			line =~ /\{(.*)\}/
#p line
			combo =$1
			#TODO: implement debugging info in case specified values don't exist.
			forbidden_combos << combo.split(",").map{|x|x.strip.split("=")} # One entry: "a=1,b=2,c=3" => ["a=1","b=2","c=3"] => [[a,1],[b,2],[c,3]]
		end
	}

	combos = 1
	num_params = 0
	for param in params
		num_params += 1 if domain[param].length>1
		combos *= domain[param].length
	end

	puts "#{num_params} parameters in total"
	puts "#{conditionals.length} parameters are conditional."
        puts "#{forbidden_combos.length} parameter combinations are forbidden."
#		puts "Number of parameters with >1 value: #{num_params}"
#		puts "Number of parameter configurations (less forbidden ones): #{combos}"
	
	return [params, domain, default, conditionals, forbidden_combos]
end

# =========================================
#  Remove all irrelevant conditional parameters from state. When one is removed that may trigger others to be removed, too.
# =========================================
def strip_state(state)
	removedParam = true
	activeParams = state.keys.sort.dup
	while removedParam
#		p activeParams
		removedParam = false
		paramsForLoop = activeParams.dup
		for param in paramsForLoop
			if $conditionals.key?(param)
				for parent in $conditionals[param].keys
					if (not $conditionals[param][parent].index(state[parent])) or (not activeParams.include?(parent))
#						p $conditionals[param][parent]
						activeParams.delete(param)
						removedParam = true
						next
					end
				end
			end
		end
	end
	result = Hash.new
	for param in activeParams
		result[param] = state[param]
	end
	return result
end

# =========================================
#                  state as string
# =========================================
def state_string(state)
	return state["param_string"] if state.key?("param_string")
	stripped_state = strip_state(state)
	stripped_state.keys.sort.map{|param| param + "=" + stripped_state[param].to_s}.join(" ")
end


def output_to_s(params, domain, default, conditionals, forbidden_combos)
	output = []
	output << "======================================================\nparameters begin: "
	for param in params
		output << "   #{param}: domain=#{domain[param].join(",")}, default=#{default[param]}"
	end
	output << "parameters end.\n======================================================"

	output << "======================================================\nconditionals begin: "
	for key in conditionals.keys.sort
		output << "   #{key}| #{conditionals[key].to_a.join(" ")}"
	end
	output << "conditionals end.\n======================================================"

	output << "======================================================\nforbidden begin: "
	for forbidden_combo in forbidden_combos
		output << "   #{forbidden_combo.map{|x|x.join("=")}.join(", ")}"
	end
	output << "forbidden end.\n======================================================"
	return output.join("\n")
end


# =========================================
# Returns true iff state is forbidden by $forbidden_combos.
# =========================================
def forbidden(state, forbidden_combos)
	forbidden = false
	for forbidden_combo in forbidden_combos
		#A combo is satisfied if all its assignments are satisfied.
		match = true
		for assignment in forbidden_combo
			param, forbidden_value = assignment
			match = false unless state[param] == forbidden_value
#			puts "#{param}, #{forbidden_value}"
#			puts "#{param}, #{state[param]}"
		end
		return true if match # a forbidden combo is matched.
	end
	return false
end


# =========================================
# Binary counter for increasing the state one at a time. Return value true/false, changing state itself!
# =========================================
def increase_state(state, domain, sorted_params, fixed_ass)
#	p $conditionals
#	err
	for param in sorted_params
		next if fixed_ass.key?(param)
		
		#=== If parameter is conditional, skip it if it is inactive.
		if $conditionals.key?(param)
			active = true
#			puts "param"
#			p param
			for deciding_param in $conditionals[param].keys
#				puts "deciding_param"
#				p deciding_param
				good_vals= $conditionals[param][deciding_param]
#				puts good_vals
#				p good_vals
				active = false unless good_vals.include?(state[deciding_param])
			end
			next unless active
		end
		
		idx = domain[param].index(state[param])
		raise "idx can't be nil but it is for state #{state} and param #{param} with domain #{$domain[param]} and value state[param]" if idx == nil

		if idx == domain[param].length-1
			state[param] = domain[param][0]
		else
			state[param] = domain[param][idx+1]
			return true
		end
	end
	return false # can't increase state anymore
end

# =========================================
# Return true if y is (indirectly) dependent on x. (Recursive procedure to determine)
# =========================================
def predecessor(x,y)
	return false if not $conditionals.key?(y)
	return true if $conditionals[y].key?(x)
	for pred in $conditionals[y].keys
		return true if predecessor(x,pred)
	end
	return false
end

###########################################################################
#=== Build array containing all possible parameter settings. 
#=== Internally also build hash for quick checks if an equivalent state is already in there.
###########################################################################
def get_all_distinct_states(params, domain, forbidden_combos, out, fixed_ass)
	sorted_params = params.sort{|x,y| predecessor(x,y) ? -1 :1}

	all_distinct_states = []
	all_states = Hash.new
	curr_state = Hash.new
	sorted_params.map{|x| curr_state[x] = domain[x][0]}
	fixed_ass.keys.map{|x| curr_state[x] = fixed_ass[x]}

	all_states = {}
	count = 0
	allcount = 0
	nonforbidden_count = 0
	loop do
		allcount += 1
		unless forbidden(curr_state, forbidden_combos)
			nonforbidden_count +=1
			
			stripped_state = strip_state(curr_state)
			state_as_string = state_string(curr_state)
			unless all_states.key?(state_as_string)
				count += 1
#				puts "#{count} (#{nonforbidden_count}, #{allcount}): #{state_as_string}"
				puts "#{count} (#{nonforbidden_count}, #{allcount})" if  count.modulo(1000)[1]==1
#				out.puts "#{count} (#{allcount}): #{state_as_string}"

				all_distinct_states << [stripped_state, state_as_string]
				all_states[state_as_string] = 0
			end
		end
		break unless increase_state(curr_state, domain, sorted_params, fixed_ass)
	end
	puts "nonforbidden count: #{nonforbidden_count}"
	return all_distinct_states
end


# ================================================
# Build string of fixed parameters.
# ================================================
def fixed_string(fixed_ass)
	fixed_string = ""
	for param in fixed_ass.keys
		fixed_string << "#{param}=#{fixed_ass[param]} "
	end
	return fixed_string
end

# ================================================
# Build Hash of fixed parameters.
# ================================================
def set_fixed_params(fix_input, domain, params, out)
	fixed_ass = Hash.new
	#=== Parse fix and remember them in hash.
	if fix_input 
		# p fix_input
		fix_input = fix_input.split.map! {|x| x.strip.to_s} 
#		p fix_input
		0.step(fix_input.length-1,2){|i|
			param = fix_input[i]
			value = fix_input[i+1]
			# p [param, value]
			out.puts "*************************** WARNING *****************************\nparam #{param} set to fixed value #{value}, which is not included in its domain #{domain[param].join(", ")}\n*****************************************************************" unless domain[param].include?(value)
			puts "*************************** WARNING *****************************\nparam #{param} set to fixed value #{value}, which is not included in its domain #{domain[param].join(", ")}\n*****************************************************************" unless domain[param].include?(value)
			fixed_ass[param] = value
		}
	end
#	out.puts "manually fixed: #{fixed_string(fixed_ass)}"
#	puts "manually fixed: #{fixed_string(fixed_ass)}"
	return fixed_ass
end
