require_relative 'private'
require 'json'
require 'optparse'

OptionParser.new { |opts|
  opts.banner = "Usage: #$PROGRAM_NAME [options]"
  opts.on('-s STARS', '--stars', Integer, 'required number of stars')
}.parse!(into: opts = {})

jsons = ARGV.map { |a| JSON.parse(File.read(a)) }

years = jsons.map { |j| Integer(j['event']) }
raise "mismatching years #{years}" if years.uniq.size > 1

people = jsons.flat_map { |j| j['members'].values }
if required_stars = opts[:stars]
  people.select! { |p| p['stars'] >= required_stars }
end
recalculate_private(people, year: years[0])
