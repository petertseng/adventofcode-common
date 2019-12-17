def parse_daily_file(txt)
  entries = entries_minus_supporter_tags(txt)
  raise "expect 200 entries, not #{entries.size}" if entries.size != 200

  gold = by_person(entries[0...100].map { |e|
    parse_daily_entry(e, :gold)
  })
  silver = by_person(entries[100...200].map { |e|
    parse_daily_entry(e, :silver)
  })

  combined = gold.merge(silver) { |k, v1, v2| v1.merge(v2) }.values.map(&:dup)
  combined.each { |v|
    v.delete(:rank)
    v.delete(:time)
    score = 0
    score += 101 - v[:gold_rank] if v[:gold_rank]
    score += 101 - v[:silver_rank] if v[:silver_rank]
    v[:score] = score
    v[:delta] = v[:gold_time] - v[:silver_time] if v[:gold_time] && v[:silver_time]
  }

  {
    gold: gold.values,
    silver: silver.values,
    combined: combined,
  }
end

def entries_minus_supporter_tags(file_content)
  file_content.scan(%r{<div class="leaderboard-entry">(.+?)</div>}).map { |e|
    # Be careful removing this </a>
    # A single </a> ends both the supporter and userpic/name <a> tags.
    # So AoC supporter will have $ instead of </a> at the end of their name.
    e.first.gsub(%r{ <a href="/20../support" class="supporter-badge" title="Advent of Code Supporter">\(AoC\+\+\)</a>}, '')
      .gsub(%r{ <a href="[^"]+" target="_blank" onclick="[^"]+" class="sponsor-badge" title="Member of sponsor: .*">\(Sponsor\)</a>}, '')
  }
end

def parse_person(txt)
  img_link = {
    img: txt.match(%r{img src="([^"]+)"})&.[](1)&.freeze,
    link: txt.match(%r{<a href="([^"]+)" target="_blank">})&.[](1)&.freeze
  }.compact

  if (m = txt.match(%r{<span class="leaderboard-anon">\(anonymous user #(\d+)\)</span>}))
    img_link.merge(anonymous: true, id: Integer(m[1]), name: "(anon ##{m[1]})".freeze).freeze
  else
    # Name = what comes after their (possibly empty) userphoto
    name = %r{<span class="leaderboard-userphoto">.*</span>(.*)$}.match(txt)[1]
    if (i = name.index('</a>'))
      name = name[0...i]
    end
    if (i = name.index('<a href'))
      name = name[0...i]
    end
    img_link.merge(name: name.strip.freeze).freeze
  end
end

def parse_daily_entry(e, type)
  # Assumption: It NEVER takes more than 24 hours for the leaderboard to fill.
  h, m, s = e.match(%r{<span class="leaderboard-time">Dec\s+\d\d\s+([\d:]+)})[1].split(?:).map(&:to_i)
  time = h * 3600 + m * 60 + s
  rank = Integer(e.match(%r{<span class="leaderboard-position">\s*(\d+)\)})[1])
  after_leaderboard_time = e.match(%r{<span class="leaderboard-time">[^<]+</span>(.*)})[1]
  {
    person: parse_person(after_leaderboard_time),
    score: 101 - rank,
    rank: rank,
    time: time,
    :"#{type}_rank" => rank,
    :"#{type}_time" => time,
  }.freeze
end

def by_person(entries)
  entries.group_by { |e| e[:person] }.transform_values { |vs|
    raise "#{vs} not unique" if vs.size != 1
    vs[0]
  }
end
