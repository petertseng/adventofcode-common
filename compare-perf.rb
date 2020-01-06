require 'pathname'

# times[case_name][language] = time
times = Hash.new { |h, k| h[k] = {} }

ARGV.each { |arg|
  content = if File.directory?(arg)
    # Directory? Run the test.rb
    STDERR.puts("running #{arg}")
    Dir.chdir(arg) { `ruby test.rb -s`.lines }
  elsif File.file?(arg)
    File.readlines(arg)
  end

  content.grep(/passed/) { |l|
    case_name, time = l.split.values_at(0, -1)
    times[case_name][Pathname.new(arg).realpath] = Float(time)
  }
}

langs = times.values.flat_map(&:keys).uniq

def colour_rank(s, rank)
  code = [32, 33, 31][rank]
  "\e[1;#{code}m#{s}\e[0m"
end

def colour_ratio(s, rat)
  code = if rat == 1
    34
  elsif rat <= 2
    32
  elsif rat <= 5
    33
  else
    31
  end
  "\e[1;#{code}m#{s}\e[0m"
end

TIME_WIDTH = 8
RATIO_WIDTH = 6
RANK_WIDTH = 1
FIELD_WIDTH = 1 + RANK_WIDTH + 1 + TIME_WIDTH + 2 + RATIO_WIDTH + 1

longest_case = times.keys.map(&:size).max
puts ' ' * (longest_case + 1) + langs.map { |path|
  lang_name = path.to_s.split(?-)[-2]
  "%#{FIELD_WIDTH}s" % lang_name
}.join(' ')
times.each { |case_name, case_times|
  left = case_name.ljust(longest_case, ' ')
  ranks = case_times.values.sort.each_with_index.to_a.uniq(&:first).to_h
  mintime = case_times.values.min
  l = langs.map { |lang|
    if (t = case_times[lang])
      ratio = t / mintime
      rank = ranks.fetch(t)
      [
        colour_rank("%#{RANK_WIDTH}d" % (rank + 1), rank),
        colour_ratio("%#{TIME_WIDTH}.3f (%#{RATIO_WIDTH}.2fx)" % [t * 1000, ratio], ratio),
      ].join(' ')
    else
      "\e[1;35m#{'???'.rjust(FIELD_WIDTH, ' ')}\e[0m"
    end
  }
  puts "#{left} #{l.join(' ')}"
}
