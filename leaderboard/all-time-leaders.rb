require_relative './common'

# total scores for people who repeatedly appear in the top 100.
# Can give it either a list of yearly boards (in which case it will report when some results may be inaccurate),
# or a list of daily boards.

def parse_yearly_entry(txt)
  score = Integer(%r{<span class="leaderboard-totalscore">\s*(\d+)</span>}.match(txt)[1])
  person = if (m = %r{<span class="leaderboard-anon">\(anonymous user #(\d+)\)</span>}.match(txt))
    {anonymous: true, id: Integer(m[1]), name: "(anon ##{m[1]})"}.freeze
  else
    link = %r{<a href="([^"]+)" target="_blank">}.match(txt)&.[](1)
    # Name = what comes after their userphoto (possibly empty)
    name = %r{<span class="leaderboard-userphoto">.*</span>(.*)$}.match(txt)[1]
    if (i = name.index('</a>'))
      name = name[0...i]
    end
    if (i = name.index('<a href'))
      name = name[0...i]
    end
    {name: name.strip, link: link}.freeze
  end
  {score: score, person: person}.freeze
end

all = ARGV.delete('--all')

boards = ARGV.flat_map { |f|
  s = File.read(f)
  if s.include?('overall leaderboard; these are the 100 users with the highest total')
    entries = entries_minus_supporter_tags(s)
    scores = entries.map { |m| parse_yearly_entry(m) }.freeze
    [
      {t: :yearly, year: Integer(f[/\d+/]), scores: scores}.freeze
    ]
  elsif s.include?('leaderboard-daylinks-selected')
    yearday = f.scan(/\d+/).map { |n| Integer(n, 10) }
    unless yearday.size == 2 && yearday.one?(2015..) && yearday.one?(1..25)
      raise "don't know which is year and day among #{yearday}"
    end
    daily = parse_daily_file(s)
    common = {t: :daily, year: yearday.max, day: yearday.min}.freeze
    [
      common.merge(part: 1, scores: daily[:silver]).freeze,
      common.merge(part: 2, scores: daily[:gold]).freeze,
    ]
  else
    raise "don't know what to do with #{f}"
  end
}.freeze

board_types = boards.map { |b| b[:t] }.uniq
raise "can't deal with board types #{board_types}" if board_types.size != 1

canceled_boards, boards = boards.partition { |board|
  next true if board[:year] == 2018 && board[:day] == 6
  next true if board[:year] == 2020 && board[:day] == 1
}.map(&:freeze)

years = boards.map { |b| b[:year] }.uniq.sort.freeze

people = Hash.new { |h, k| h[k] = {
  total: 0,
  max: 0,
  max_boards: [],
  boards: [],
  year_scores: Hash.new(0),
} }
flat_board = []

by_name = boards.flat_map { |board| board[:scores].map { |s| s[:person] } }.group_by { |p| p[:name] }
by_name.each { |name, people|
  next if people.uniq.size == 1
  puts "#{name} has #{people.uniq.size} people: #{people.uniq}"
}

boards.each { |board|
  board_id = board.slice(:year, :day, :part).freeze
  board[:scores].each { |score|
    person = score[:person]

    # If I want to collapse people with same name but different other attributes into one:
    #person = by_name[person[:name]][0]

    stat = people[person]
    stat[:total] += score[:score]
    stat[:boards] << board_id
    stat[:year_scores][board[:year]] += score[:score]

    case stat[:max] <=> score[:score]
    when 0
      stat[:max_boards] << board_id
    when 1
      # nothing
    when -1
      stat[:max] = score[:score]
      stat[:max_boards] = [board_id]
    else raise 'bad cmp'
    end

    if board[:t] == :yearly
      flat_board << {score: score[:score], person: score[:person], year: board[:year]}.freeze
    end
  }
}
people.each { |_, p|
  p[:max_boards].freeze
  p[:boards].freeze
  p[:year_scores].freeze
}
people.freeze
flat_board.freeze

puts "#{people.size} unique individuals among #{boards.size} boards#{" (#{canceled_boards.size} canceled)" unless canceled_boards.empty?}"

may_be_inaccurate_below = if board_types == [:yearly]
  # Actually, yearly totals may be inaccurate above this number too.
  # Consider someone who may be in the top 100 one year but outside for another year.
  # However, I'll treat this as a good cutoff point anyway.
  boards.sum { |board| board[:scores].map { |s| s[:score] }.min }
else
  0
end

def fmt_person(rank, k, v)
  '%4d tot %5d max %4d%s brds %3d %s' % [
    rank,
    v[:total],
    v[:max],
    (v[:max_boards].size > 1 ? 'x%2d' % v[:max_boards].size : '   '),
    v[:boards].size,
    k,
  ]
end

def fmt_boards(boards)
  boards.group_by { |b| b[:year] }.map { |year, year_boards|
    next year if year_boards.size == 1 && !year_boards[0][:day]
    by_day = year_boards.group_by { |b| b[:day] }
    "#{year_boards.size} in #{year}: #{by_day.map { |day, day_boards|
      parts = if day_boards.size == 2
        ' both'
      elsif day_boards[0][:part]
        " part #{day_boards[0][:part]}"
      else
        ''
      end
      "#{day}#{parts}"
    }.join(', ')}"
  }
end

puts 'top by total:'
prev_score = 0
prev_rank = 0
by_total = people.sort_by { |_, v| -v[:total] }.freeze
by_total.each.with_index(1) { |(k, v), i|
  tied_rank = if v[:total] == prev_score
    prev_rank
  else
    prev_score = v[:total]
    prev_rank = i
  end
  if v[:total] <= may_be_inaccurate_below
    puts "may be inaccurate below #{may_be_inaccurate_below}"
    break
  end
  if i > 50 && !all
    puts 'stopping at 50 (arbitrary number), use --all if you really want to see them all'
    break
  end
  puts fmt_person(tied_rank, k, v)
}
puts

def club(n, members, key)
  puts "#{members.size} people in the #{n} club"
  members.each.with_index(1) { |(k, v), i|
    puts fmt_person(i, k, v) + ' ' + fmt_boards(v[key]).join(' ')
  }
  puts
  puts "#{n} club tally"
  puts members.map { |k, v| v[key].size }.tally
  puts
  members = members.sort_by { |_, v| -v[key].size }
  repeat_members = members.take_while { |_, v| v[key].size > 1 }
  puts "#{repeat_members.size} in the multiple #{n} club:"
  prev_score = 0
  prev_rank = 0
  repeat_members.each.with_index(1) { |(k, v), i|
    tied_rank = if v[key].size == prev_score
      prev_rank
    else
      prev_score = v[key].size
      prev_rank = i
    end
    puts '* %d) %s with %d' % [tied_rank, k[:name], v[key].size]
    fmt_boards(v[key]).each { |fmted|
      puts "    * #{fmted}"
    }
  }
end

by_boards = people.sort_by { |_, v| [v[:boards].size, v[:total]] }.reverse

if board_types == [:yearly]
  puts 'top 30 (arbitrary number) scores:'
  flat_board.sort_by { |x| x[:score] }.reverse.take(30).each.with_index(1) { |v, i|
    puts '%2d. %4d points in %4d by %s' % [i, v[:score], v[:year], v[:person][:name]]
  }
  puts

  puts "tally of # boards: #{by_boards.map { |_, v| v[:boards].size }.tally}"
  puts '>= 4 boards:'

  by_boards = by_boards.take_while { |_, v| v[:boards].size >= 4 }
  by_boards.each.with_index(1) { |(k, v), i|
    puts fmt_person(i, k, v) + ' ' + v[:boards].map { |b| b[:year] }.join(', ')
  }
elsif board_types == [:daily]
  puts 'detail top 30 (arbitrary):'
  by_total.take(30).each.with_index(1) { |(k, v), i|
    puts '%d. %s with %d (%s)' % [i, k[:name], v[:total], years.map { |y| v[:year_scores][y] }.join(' + ')]
  }
  puts

  one_hundred_club = people.select { |_, v| v[:max] == 100 }.sort_by { |_, v| -v[:max_boards].size }.freeze
  club(100, one_hundred_club, :max_boards)
  puts

  two_hundred_club = one_hundred_club.map { |k, v|
    by_year_day = v[:max_boards].group_by { |b| b.slice(:year, :day) }
    two_hundred_days = by_year_day.select { |k, v| v.size == 2 }.keys
    [k, v.merge(two_hundred_days: two_hundred_days.freeze).freeze].freeze
  }.reject { |_, v| v[:two_hundred_days].empty? }
  club(200, two_hundred_club, :two_hundred_days)
  puts

  puts 'top 30 (arbitrary number) by # leaderboard appearances:'
  by_boards = by_boards.take(30)
  by_boards.each.with_index(1) { |(k, v), i|
    # too many to show all, so instead show sum by year
    board_by_year = v[:boards].group_by { |b| b[:year] }

    puts '%d. %s with %d (%s)' % [i, k[:name], v[:boards].size, years.map { |y| (board_by_year[y] || []).size }.join(' + ')]
  }
  puts

  puts 'most leaderboards in a single year:'
  most_in_year = []
  people.each { |k, v|
    v[:boards].group_by { |b| b[:year] }.each { |year, boards|
      most_in_year << {person: k, year: year, boards: boards}.freeze
    }
  }
  unique_sizes = []
  most_in_year.sort_by { |miy| -miy[:boards].size }.each { |miy|
    size = miy[:boards].size
    unique_sizes << size unless unique_sizes[-1] == size
    break if unique_sizes.size >= 5
    potential = (1..25).flat_map { |day| (1..2).map { |part| {year: miy[:year], day: day, part: part} } }
    puts "#{size} in #{miy[:year]} #{miy[:person][:name]} missing #{potential - miy[:boards]}"
  }
end
