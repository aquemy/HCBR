require "global_helper.rb" # for instance hash

def output_help(out)
	out.puts "\n======================================================================================================"
	out.puts "Randomness is due to a) the tuning algorithm itself, b) Sampled instances, and c) different seeds.\n"
	
	out.puts "\nParameters"
	out.puts "=========="
	
	out.puts "-instanceFile <X>, where <X> is the path to a text file with instances (see README.TXT for details)"
	out.puts "-ordered <X>, where <X> in {0,1} [#{@ordered_instances}]. When this is 1, preserve the order of re-sampled instances (e.g. easy first)."
	out.puts "-numRepetitions <X>, where <X> is a positive integer [#{@numRepetitions}]"
	out.puts "-deterministic <X>, where <X> is in {0,1}[#{@deterministic_algorithm}]"
end

# =========================================
#                  MAIN
# =========================================

@instanceset_filename = "SW-saps-1M-to2M-scrambled-first100.txt"
@ordered_instances = 0
@numRepetitions = 100
@deterministic_algorithm = 0
@stratified = 1
meta = false
@ordered = false

if ARGV.length < 1
	output_help($stdout)
	exit
end

# =========================================
# Read in command line options.
# =========================================
passedArgIndices = []
0.step(ARGV.length-1, 2){|i|
	case ARGV[i]
	when "-instanceFile"
		@instanceset_filename = ARGV[i+1]
	when "-stratified"
		@stratified = ARGV[i+1]
	when "-ordered"
		@ordered_instances = ARGV[i+1]
	when "-numRepetitions"
		@numRepetitions = ARGV[i+1].to_i
	when "-deterministic"
		@deterministic_algorithm = ARGV[i+1]
	when "-meta"
		meta = ARGV[i+1]
	else
		output_help($stdout)
		puts "\n\n"
		raise "Unknown argument: #{ARGV[i]}"
	end
}
 
@ordered_instances = false if @ordered_instances == "0" or @ordered_instances == 0
@deterministic_algorithm= false if @deterministic_algorithm == "0" or @deterministic_algorithm == 0
@stratified = false if @stratified == "0" or @stratified == 0

#=== Read instance names, solution qualities and references from file.
i_Hash, orig_instances_sorted = getInstanceHash(@instanceset_filename)

# =========================================
# Set up the seeded instance files.
# =========================================
@order_str = ""
@order_str = "-ordered" if @ordered_instances

@det_str = ""
@det_str = "-det_algo" if @deterministic_algorithm

@strat_str = ""
@strat_str = "-strat" if @stratified

#=== If we go through in the original order, stratified is not needed (and actually not wanted).
if @ordered_instances
	@stratified = false
end

subdir = "#{@instanceset_filename.sub(/\.txt/,"")}#{@strat_str}#{@det_str}#{@order_str}"
system "mkdir #{subdir}" unless File.exist?(subdir)

seed = 1234
srand(seed)

#=== @numRepetitions times, take 2000 samples <instance, seed>, with replacement.
for repetition in 0...@numRepetitions 
	@inst_seeds = []
	strat_instances = orig_instances_sorted.dup
	for i in 0...2000
		if @stratified
			break if @deterministic_algorithm and strat_instances.empty?
			strat_instances = orig_instances_sorted.dup if strat_instances.empty?
			inst = strat_instances[rand(strat_instances.length)]
			strat_instances.delete(inst)
		elsif @ordered_instances
			inst = orig_instances_sorted[i.divmod(orig_instances_sorted.length)[1]]
		else
			inst = orig_instances_sorted[rand(orig_instances_sorted.length)]
		end
		algoseed = rand(2147483646)+1 	# Let's not use zero, some algos don't accept that as a seed.
		algoseed = i / (orig_instances_sorted.length) if meta # meta-tuning for ParamILS - the seed is the run number. 

		algoseed = -1 if @deterministic_algorithm
		#algoseed = 1851696952 if @deterministic_algorithm # -- only for Spear when using fixed seed

		@inst_seeds << [inst, algoseed]
	end

#	if @ordered_instances
#		@inst_seeds.sort!{|x,y| orig_instances_sorted.index(x[0])<=>orig_instances_sorted.index(y[0])}
#	end

	filename = "#{subdir}/instance_list_#{repetition}.txt"
	File.open(filename, "w"){|file|
		for inst_seed in @inst_seeds
			inst, algoseed = inst_seed
			i_Hash[inst]["reference"] = [] unless i_Hash[inst]["reference"]
			file.puts "#{algoseed} #{inst} #{i_Hash[inst]["desired_qual"]} #{i_Hash[inst]["reference"].join(" ")}"
		end
	}
end