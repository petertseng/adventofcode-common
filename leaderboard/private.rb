require 'time'

def recalculate_private(people)
  max_day = people.flat_map { |v| v['completion_day_level'].keys }.map(&:to_i).max
  longest_name = people.map { |v| v['name'] || v['id'] }.map(&:size).max
  score = Hash.new(0)

  (1..max_day).each { |day|
    prev_completing = nil
    (1..2).each { |part|
      completing_people = people.map { |p|
        star = p.dig('completion_day_level', day.to_s, part.to_s)
        # star_index is meant to break ties between equal timestamps.
        # https://www.reddit.com/r/adventofcode/comments/za0ruh/leaderboard_json_what_is_star_index/
        star && [p['name'] || p['id'], [star.fetch('star_index'), Time.at(Integer(star.fetch('get_star_ts')))].freeze]
      }.compact.to_h.freeze
      puts "Day #{day} Part #{part}:"
      completing_people.sort_by(&:last).each_with_index { |(p, _), i|
        score[p] += people.size - i
      }
      fmt = [
        "%#{longest_name}s %s",
        "%3d pts #%#{completing_people.size.to_s.size}d/#{completing_people.size}",
        "%#{score.values.max.to_s.size}d pts #%#{people.size.to_s.size}d/#{people.size}",
      ].join(' - ')
      rank_by_total_score = score.sort_by(&:last).reverse.freeze

      if prev_completing
        delta = completing_people.to_h { |p, (_idx, t)|
          [p, t - prev_completing[p][1]]
        }.freeze
        rank_by_delta = delta.sort_by(&:last).freeze
      end

      completing_people.sort_by(&:last).each_with_index { |(p, (_idx, t)), i|
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
end
