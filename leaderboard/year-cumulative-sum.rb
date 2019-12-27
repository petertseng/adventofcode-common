years = ARGV.to_h { |f|
  s = File.read(f)
  scores = s.scan(/<span class="leaderboard-totalscore">\s*(\d+)<\/span>/).map { |m| Integer(m[0]) }
  y = Integer(f[/\d+/])
  [y, scores]
}

puts "top | #{years.keys.join(' | ')}"
puts '-----' + '|-----' * years.size
100.step(10, by: -10) { |n|
  puts "#{n} | #{years.map { |_, v| v.take(n).sum }.join(' | ')}"
}
