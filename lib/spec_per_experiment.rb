# :)
# spec_per_experiment.rb <unitespec.tab>
#

require "parallel"
require "time"

def sjoin(array, column)
  array.map{|l| l[column] }.join(",")
end

def fjoin(array, column)
  array.map{|l| l[column].to_f }.reduce(:+)
end

# number of reads: sum or mean?
# i.e. separated sequencing or replicates?
# if
#   one experiment has multiple runs
#   && not include 'tagged' in alias (tag sequencing separated into multiple files)
#   && not include 'lane' in alias (separated sequencing on multiple lanes)
#   && not include 'run{n}' in alias (numbered run, would be merged)

# define methods for array of array-of-values
class Array
  def extract_column(column, type)
    self.map{|array| array[column].send(type) }
  end
  
  def sjoin(column)
    extract_column(column, :to_s).uniq.join(",")
  end
  
  def fsort(column)
    extract_column(column, :to_f).sort
  end
  
  def fjoin(column)
    extract_column(column, :to_f).reduce(:+)
  end
  
  def fmean(column)
    fjoin(column) / self.size
  end
end

# define methods for array of strings
class Array
  def scan_string(pattern)
    !self.map{|string| string =~ pattern }.include?(nil)
  end
  
  def are_replicates? # self is an array of strings
    if self.uniq.size != 1
      !self.scan_string(/tagged/) &&\
      !self.scan_string(/lane/) &&\
      !self.scan_string(/run\d/)
    end
  end
end

if __FILE__ == $0
  raw_path = ARGV.first
  raw = open(raw_path).read.split("\n")
  rm_header = raw.shift
  
  # grouping experiment id to generate hash from array
  exp_hash = raw.map{|l| l.split("\t") }.group_by{|l| l[13] }
  
  # num of threads to use
  num_of_threads = 16
  
  # merge lines of run to one experiment
  experiments = Parallel.map(exp_hash, :in_threads => num_of_threads) do |expid, aol| # array of lines
    aoa = aol.map{|l| l[15] } # array of aliases
    num_of_reads, reps = if aoa.are_replicates?
                           [aol.fmean(1), "T"]
                         else
                           [aol.fjoin(1), "F"]
                         end
    
    min_length = aol.fsort(2).first
    max_length = aol.fsort(3).last
    
    mean_length = aol.fmean(4)
    median_length = aol.fmean(5)
    gc = aol.fmean(6)
    phred = aol.fmean(7)
    n_cont = aol.fmean(8)
    duplicate = aol.fmean(9)
    
    layout = aol.sjoin(10)
    strategy = aol.sjoin(18)
    source = aol.sjoin(19)
    selection = aol.sjoin(20)
    platform = aol.sjoin(21)
    instrument = aol.sjoin(22)
    sname = aol.sjoin(24)
    gsize = aol.sjoin(26)
    
    received = aol.extract_column(27, :to_s).map{|s| Time.parse(s.sub("T","\s")) }.sort.first
    num_of_run = aol.size
    
    [ expid, num_of_reads, min_length, max_length, mean_length, median_length,
      gc, phred, n_cont, duplicate, layout, strategy, source, selection, platform,
      instrument, sname, gsize, received, num_of_run, reps ].join("\t")
  end
  
  header = %w{ expid sumOfReads minLength maxLength meanLength medianLength
               gc phred n_cont duplicate layout strategy source selection platform
               instrument sname gsize received numOfRun isReplicates}.join("\t")
  
  fname = "../result/experiments.tab"
  open(fname,"w"){|f| f.puts([header] + experiments) }
end
