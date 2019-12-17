require_relative 'common'

DISABLED_DAYS = {}

people_named = Hash.new { |h, k| h[k] = [] }
people = Hash.new { |h, k| h[k] = {day_score: [0] * 26, cumulative_rank: [nil] * 26} }

num_args, not_num_args = ARGV.partition { |arg| arg.match?(/^\d+$/) }

not_num_args.each { |f|
  content = File.read(f)
  unless DISABLED_DAYS.frozen?
    DISABLED_DAYS[6] = true if content.include?('2018/leaderboard')
    DISABLED_DAYS[1] = true if content.include?('2020/leaderboard')
    DISABLED_DAYS.freeze
    puts "Disabled #{DISABLED_DAYS}"
  end

  day = Integer(File.basename(f).split(?-).last, 10)
  parse_daily_file(content)[:combined].each { |person|
    people_named[person[:person][:name]] << person[:person]
    people[person[:person]][:day_score][day] += person[:score]
  }
}

people_named.each { |k, v| puts "Multiple people named #{k}: #{v.uniq}" if v.uniq.size > 1 }

people.each_value { |person|
  sum = 0
  person[:cumulative_score] = person[:day_score].map.with_index { |v, i|
    next sum if DISABLED_DAYS[i]
    sum += v
  }
}

(0..25).each { |day|
  day_cumulative_sort = people.values.sort_by { |person| -person[:cumulative_score][day] }

  prev = nil
  prev_rank = nil

  day_cumulative_sort.each_with_index { |person, i|
    cumulative_score = person[:cumulative_score][day]

    rank_shown = cumulative_score == prev ? prev_rank : (prev_rank = i + 1)
    person[:cumulative_rank][day] = rank_shown

    prev = cumulative_score
  }
}

people = people.sort_by { |_, v| -v[:cumulative_score][25] }

if (n = num_args[0]&.to_i)
  people = people.take(n)
end

longest_name = people.map { |p, _| p[:name].size }.max

header = ("%#{longest_name}s" + ' %3d' * 25) % ['', *(1..25)]
puts header
people.each { |person, v|
  puts ("%#{longest_name}s" + ' %3d' * 25 + ' %4d') % ([person[:name]] + v[:cumulative_rank][1..25] + [v[:cumulative_score][25]])
}
puts header
