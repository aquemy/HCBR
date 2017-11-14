def float_regexp()
        return '[+-]?\d+(?:\.\d+)?(?:[eE][+-]\d+)?';
end

# #########################
# ADDITIONAL STATS FOR ARRAYS only filled with numbers.
# #########################
class Array
	#===== Average
	def avg
		return nil if length == 0
		result = 0;
		each {|x| 
			return x if x.to_s == "Infinity" 
			if x.to_s =~ /#{float_regexp}/
				result += x.to_f 
			else
				raise "Trying to compute mean of array with non-float entry: #{x.inspect} !"
			end
		}
	return result / length
	end
	#===== Standard deviation
	def std
		return nil if length == 0
		return 0 if length == 1 # no std dev if only one run 
		sum_of_squ = 0
		each {|x|
			return x if x.to_s == "Infinity" 
			if x.to_s =~ /#{float_regexp}/
				sum_of_squ += x.to_f**2
			else
				raise "Trying to compute stddev of array with non-float entry: #{x.inspect} !"
			end
		}
		numerator = [0,sum_of_squ - length*(avg**2)].max
		return Math.sqrt(numerator/(length-1))
	end
	
        def hacksort(x,y)
          return -1 if x == nil
          return 1 if y == nil
          x=x.to_s
          y=y.to_s
          return -1 unless x =~ /#{float_regexp}/
          return 1 unless y =~ /#{float_regexp}/
          return x.to_f<=>y.to_f;
        end

	def quantile(p)
          tmp=self.sort#{|x,y| hacksort(x,y)}
#		p tmp 
		index = (p*tmp.length).ceil.to_i-1
		return tmp[index]
	end

	def median
          tmp=self.sort#{|x,y| hacksort(x,y)}
		if tmp.length.modulo(2)==1
			index = (tmp.length/2).floor.to_i
			return tmp[index]
		else
			index1 = (tmp.length/2).to_i-1
			index2 = (tmp.length/2).to_i
			return 0.5*(tmp[index1]+tmp[index2])
		end
	end
end

def log_zero()
	return -100000
end

def log10_or_small(x)
	raise "shall compute log10_or_small from non-float #{x}" unless x.to_s =~ /#{float_regexp}/
	raise "shall compute log10_or_small from number #{x} <= 0" unless x >= 0
	if x == 0 
		return log_zero()
	else 
		return Math.log10(x)
	end
end

def correlation_coefficient(array1, array2)
	unless array1.length == array2.length
		puts "Trying to compute correlation coefficient of two array of different size:"
		p array1
		puts ""
		p array2
		raise "Trying to compute correlation coefficient of two array of different size: #{array1.length}, #{array2.length}"
	end
	n=array1.length
	unless n > 1
		puts "Cannot compute correlation coefficient of array with length #{n} < 2"
		p array1
		puts ""
		p array2
		raise "Cannot compute correlation coefficient of array with length #{n} < 2"
	end
	sum=0
	for i in 0...n
		sum += array1[i].to_f * array2[i].to_f
	end
	cov = 1.0 / (n - 1.0) * (sum-n*array1.avg*array2.avg)
	return cov / (array1.std * array2.std)
end

# #########################
# BUILD HISTOGRAM for each step/time step a run showed an improvement on.
# Each run in runs must be an array out of which we extract entry index for the x-axis (#steps / time).
# The zero'th entry of each run array must be solution quality.
# #########################
def build_histo(runs, index) 
	histo = []
	for run in runs 
		histo += run.map{ |tupel| tupel[index]}
	end
	histo.uniq!
	histo.sort!

	# #########################
	# For each step in the histogram compute avg. sol. quality and std. deviation
	# #########################
	histo.map! {|step|
		run_quals_at_step = []
		for run in runs
			i=0 # this IS necessary since ruby does not assign i if the loop is not entered at all.
			for i in 0...run.length # ... is exclusive ( < )
				break if run[i][index] > step
			end
			run_quals_at_step << run[i][0];
		end
#		[step, run_quals_at_step.avg, run_quals_at_step.std]
		[step, run_quals_at_step.avg, run_quals_at_step.min, run_quals_at_step.max]
	}
end

def output_histo(header, num_run, histo, outputname, format_string)
#	return if histo.length == 0
	file = File.open(outputname, "w")
	file.puts "# #{header}"
	file.puts "# #{num_run} iterations"
	for out_tupel in histo
		#step, avg qual. at step, stddev qual. at step
		file.puts format_string % out_tupel
	end
	file.close
end

def build_qrtd(runs, index, qual_to_reach)
	times = []
	maxtime = 100
	for run in runs
		r = run.find{|r| r[0] >= qual_to_reach-(1e-4)}
#		puts "run #{run}, qual_to_reach #{qual_to_reach-(1e-4)}, r #{r}"
		times << r[index] if r
		if run.length > 0 
                  maxtime = [run[run.length-1][index], maxtime].max
                end
	end
	times.sort!
#	times << maxtime # such that the qrtd file indicates how long the algorithm has been run.
#	times.sort!{|x,y| x == nil ? 1 : (y==nil ? -1 : x<=>y) } # nil is bigger than anything
	result = []
	result << [0.0,0] unless times[0]==0
	for i in 0...times.length
#		break if times[i] == maxtime
		next if (i != times.length-1 and times[i+1]==times[i])
		result << [times[i], (i+1.0)*100/runs.length]
	end
	result << [maxtime, (times.length)*100.0/runs.length]

	return result
end

def qual_at_time(filename, time)
	last_avg, last_min, last_max, last_std = nil,nil,nil,nil
	avg,min,max, std = nil,nil,nil,nil
	File.open(filename) do |file| 
		while line = file.gets 
#			t,avg,std = line.split
			t,avg,min,max = line.split
			break if t.to_f > time
			last_avg, last_min, last_max, last_std  = avg, min, max, std
		end
	end
#	return [nil, nil] if last_avg == nil
#	return [last_avg.to_f, last_std.to_f]
	return [nil, nil, nil] if last_avg == nil
	return [last_avg.to_f, last_min.to_f, last_max.to_f]
end

def quantile(filename, quantile_prob)
	raise "filename is nil in quantile" if filename == nil
	# filename has to be an .qrtd / .qrld filename !
	time, prob = nil,nil
	File.open(filename) do |file|
		while line = file.gets 
			next if line =~ /^#/
			tmp, prob = line.split
			if prob.to_f >= quantile_prob * 100
				time = tmp
				break 
			end
		end
	end
	if time 
		return (time.to_f*100).floor/100.0
	else 
		return nil
	end
end

# Returns nicely formatted avg and stddiv.
def avg_std(array, *divby)
	avg = array.avg
	std = array.std
	if divby[0]
		avg /= divby[0].to_f
		std /= divby[0].to_f
	end
	return "%.2f(%.2f)" % [avg,std]
end

def min_max(array)
	return "[" + array.min.to_s + ", " + array.max.to_s + "]"
end

def min_max_f(array)
	return "[%.5f, %.5f]" % [array.min,array.max]
end
