require_relative 'private'
require 'json'

jsons = ARGV.map { |a| JSON.parse(File.read(a)) }

years = jsons.map { |j| Integer(j['event']) }
raise "mismatching years #{years}" if years.uniq.size > 1

people = jsons.flat_map { |j| j['members'].values }
recalculate_private(people, year: years[0])
