require 'json'
require 'time'

jsons = ARGV.map { |a| JSON.parse(File.read(a)) }
people = jsons.flat_map { |j| j['members'].values }
years = jsons.map { |j| Integer(j['event']) }

raise "mismatching years #{years}" if years.uniq.size > 1

max_day = people.flat_map { |v| v['completion_day_level'].keys }.map(&:to_i).max
longest_name = people.map { |v| v['name'] || v['id'] }.map(&:size).max
score = Hash.new(0)

disabled_days = case years[0]
when 2020
  [1]
when 2018
  [6]
else
  []
end.freeze

(1..max_day).each { |day|
  prev_completing = nil
  (1..2).each { |part|
    completing_people = people.map { |p|
      ts = p.dig('completion_day_level', day.to_s, part.to_s, 'get_star_ts')
      ts && [p['name'] || p['id'], Time.at(Integer(ts))]
    }.compact.to_h
    puts "Day #{day} Part #{part}:"
    completing_people.sort_by(&:last).each_with_index { |(p, _), i|
      score[p] += (disabled_days.include?(day) ? 0 : people.size - i)
    }
    fmt = [
      "%#{longest_name}s %s",
      "%3d pts #%#{completing_people.size.to_s.size}d/#{completing_people.size}",
      "%#{score.values.max.to_s.size}d pts #%#{people.size.to_s.size}d/#{people.size}",
    ].join(' - ')
    rank_by_total_score = score.sort_by(&:last).reverse

    if prev_completing
      delta = completing_people.to_h { |p, t|
        [p, t - prev_completing[p]]
      }
      rank_by_delta = delta.sort_by(&:last)
    end

    completing_people.sort_by(&:last).each_with_index { |(p, t), i|
      s = fmt % [
        p, t,
        people.size - i, i + 1,
        score[p], rank_by_total_score.index { |n, _| n == p } + 1,
      ]

      if prev_completing
        seconds = delta[p]
        minutes, seconds = seconds.divmod(60)
        hours, minutes = minutes.divmod(60)
        s << " - delta %3d:%02d:%02d #%#{completing_people.size.to_s.size}d/#{completing_people.size}" % [
          hours, minutes, seconds, rank_by_delta.index { |n, _| n == p } + 1,
        ]
      end

      puts s
    }
    prev_completing = completing_people
    puts
  }
}

fmt = "%#{longest_name}s %#{score.values.max.to_s.size}d #%#{people.size.to_s.size}d/#{people.size}"
score.sort_by(&:last).reverse_each.with_index { |x, i|
  puts fmt % [*x, i + 1]
}
