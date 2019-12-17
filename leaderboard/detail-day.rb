require_relative 'common'

def leaderboard_row(v)
  gt, st = %i(gold_time silver_time).map { |k|
    v.has_key?(k) ? '%4d' % v[k] : '    '
  }
  gr, sr = %i(gold_rank silver_rank).map { |k|
    v.has_key?(k) ? '#%3d' % v[k] : '    '
  }
  delta = v.has_key?(:delta) ? 'Δ%4d' % v[:delta] : '     '
  "%3d | #{gr} #{gt} | #{sr} #{st} | #{delta} | #{v[:person][:name]}" % v[:score]
end

def leaderboard(entries, by: k, best: :max)
  raise "unsupported best #{best}" unless %i(min max).include?(best)
  prev = nil
  prev_rank = nil
  entries.sort_by { |x| x[by] * (best == :max ? -1 : 1) }.each_with_index { |v, i|
    rank_shown = v[by] == prev ? prev_rank : (prev_rank = i + 1)
    puts "#%3d | #{leaderboard_row(v)}" % rank_shown
    prev = v[by]
  }
end

def banner(t)
  banner_width = 30
  puts (?- * banner_width) + t + (?- * banner_width)
end

def median(t)
  mid = t.size / 2
  t.size % 2 == 0 ? (t[mid] + t[mid - 1]) / 2.0 : t[mid]
end

def stats(t)
  return {size: 0} if t.empty?
  mid = t.size / 2
  if t.size % 2 == 0
    q1 = median(t.take(mid))
    q3 = median(t.drop(mid))
  else
    n = t.size / 4
    if t.size % 4 == 1
      q1 = 0.25 * t[n - 1] + 0.75 * t[n]
      q3 = 0.75 * t[3 * n] + 0.25 * t[3 * n + 1]
    else
      q1 = 0.75 * t[n] + 0.25 * t[n + 1]
      q3 = 0.25 * t[3 * n + 1] + 0.75 * t[3 * n + 2]
    end
  end
  {
    size: t.size,
    mean: t.sum.to_f / t.size,
    q1: q1,
    median: median(t),
    q3: q3,
    min: t.min,
    max: t.max,
  }
end

# being way too smart about our args.
if (arg = ARGV.first)
  if File.exist?(arg)
    # If it names a file, use it.
    file = arg
  else
    # Otherwise, assume standard directory, use the day named.
    file = "#{__dir__}/day/%02d" % arg.to_i
  end
else
  # Assume standard directory, look for the last existing day.
  fmt = "#{__dir__}/day/%02d"
  files = (0...25).map { |x| fmt % (25 - x) }
  file = files.find { |f| File.exist?(f) }
end

parsed = parse_daily_file(File.read(file))

banner('Best combined score')
leaderboard(parsed[:combined], by: :score)

banner('Best delta')
deltas = parsed[:combined].select { |x| x[:delta] }
leaderboard(deltas, by: :delta, best: :min)

puts stats(deltas.map { |x| x[:delta] }.sort)

# Overtaking and overtaken

def name_and_rank(o)
  {
    name: o[:person][:name],
    rank: '(S%3d%s -> G%3d%s)' % [
      o[:silver_rank] || 101,
      o[:silver_rank].nil? ? ?+ : ' ',
      o[:gold_rank] || 101,
      o[:gold_rank].nil? ? ?+ : ' ',
    ],
  }
end

def rank_overtakes(group, by:)
  {
    first: name_and_rank(group.min_by { |g| g[by] }),
    last: name_and_rank(group.max_by { |g| g[by] }),
    num: group.size,
  }
end

golds = parsed[:combined].select { |x| x[:gold_rank] }.sort_by { |x| x[:gold_rank] }
no_golds = parsed[:combined].reject { |x| x[:gold_rank] }
overtake_and_taken_rows = golds.map.with_index { |v, i|
  if (silver_rank = v[:silver_rank])
    silver_rank_str = '%3d ' % silver_rank
  else
    silver_rank = 101
    silver_rank_str = '101+'
  end
  info = {
    silver: silver_rank_str,
    gold: '%3d ' % v[:gold_rank],
    name: v[:person][:name],
    silver_top_100: silver_rank <= 100,
  }

  overtook = (golds[i..-1] + no_golds).select { |g|
    g[:silver_rank] && g[:silver_rank] < silver_rank
  }
  info[:overtook] = rank_overtakes(overtook, by: :silver_rank) unless overtook.empty?

  overtaken_by = golds[0...i].select { |g| (g[:silver_rank] || 101) > silver_rank }
  info[:overtaken_by] = rank_overtakes(overtaken_by, by: :gold_rank) unless overtaken_by.empty?

  info
}

overtake_and_taken_rows.concat(no_golds.map { |v|
  info = {
    silver: '%3d ' % v[:silver_rank],
    gold: '101+',
    name: v[:person][:name],
    silver_top_100: true,
  }

  overtaken_by = golds.select { |g| (g[:silver_rank] || 101) > v[:silver_rank] }
  info[:overtaken_by] = rank_overtakes(overtaken_by, by: :gold_rank) unless overtaken_by.empty?

  info
})

overtakes = [{
  banner: 'Overtaking',
  key: :overtook,
  warning: ->(r) {
    r[:silver_top_100] ? '' : ', there may be more non-top-100-silvers overtaken'
  },
}, {
  banner: 'Overtaken',
  key: :overtaken_by,
  warning: ->(r) { '' },
}]

overtakes.each { |overtake|
  banner(overtake[:banner])
  key = overtake[:key]
  verb = key.to_s.split(?_).join(' ')
  rows = overtake_and_taken_rows.select { |r| r[key] }

  # Highly unlikely.
  next if rows.empty?

  overtaker_width = rows.map { |r| r[:name].size }.max
  overtaken1_width = rows.map { |r| r[key][:first][:name].size }.max
  overtaken2_width = rows.map { |r| r[key][:last][:name].size }.max
  base_fmt = "S%s -> G%s %#{overtaker_width}s #{verb} %#{overtaken1_width}s %s".freeze
  overtaken2_fmt = "%#{overtaken2_width}s %s".freeze

  rows.each { |r|
    dat = r.values_at(:silver, :gold, :name) + r[key][:first].values_at(:name, :rank)
    line = base_fmt % dat
    if r[key][:num] > 1
      overtaken2 = overtaken2_fmt % r[key][:last].values_at(:name, :rank)
      if r[key][:num] > 2
        line << ', %2d more, ' % (r[key][:num] - 2)
      else
        line << ',          '
      end
      line << overtaken2
    end
    line << overtake[:warning][r]
    puts line
  }
}

banner('Difficulty')
%i(silver gold).each { |t|
  puts "#{t.capitalize} solve time: #{stats(parsed[t].map { |g| g[:time] }.sort)}"
}
