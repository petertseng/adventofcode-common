require 'time'

# Checks for missing or incompete tests
#
# Run with no arguments

red = "\e[1;31m"
yellow = "\e[1;33m"
norm = "\e[0m"

%w(secret sample).each { |test_type|
  Dir.glob("#{__dir__}/#{test_type}-cases/2*/") { |year_path|
    year = Integer(File.basename(year_path))
    files = Dir.glob("#{year_path}/*").map(&File.method(:basename)).group_by { |v| v.split(?.)[0] }.freeze
    files.each { |without_ext, files|
      has_ext = ->ext { files.any? { |f| f.end_with?(?. + ext) } }
      case v = [has_ext['in'] || has_ext['argv'], has_ext['out']]
      when [true, true]; # OK
      when [true, false]; puts "#{red}#{test_type}/#{year}/#{basename} has input but no output#{norm}"
      when [false, true]; puts "#{red}#{test_type}/#{year}/#{basename} has output but no input#{norm}"
      else raise "#{year}/#{basename}: what is #{v}?"
      end
    }
    (1..25).each { |day|
      break if Date.today < Date.new(year, 12, day)
      daypad = '%02d' % day
      next if files.keys.any? { |k| k.start_with?(daypad) }
      puts "#{yellow}#{test_type}/#{year}/#{day} has no tests#{norm}"
    }
  }
}
