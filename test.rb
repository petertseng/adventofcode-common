require 'time'

YEAR = Integer(Dir.pwd.scan(/\d+/).last)
PREFIXES = %w(secret sample).select { |prefix| File.directory?("#{__dir__}/#{prefix}-cases/#{YEAR}") }.map(&:freeze).freeze

JOINABLE = Object.new
def JOINABLE.join; end

def test_and_exit(args = ARGV)
  all_good = true

  if args.include?('--')
    i = args.index('--')
    pass_args = args.drop(i + 1)
    args = args.take(i)
  else
    pass_args = []
  end

  if args.delete('-as') || args.delete('-sa')
    parallel = false
    all = true
  else
    parallel = !args.delete('--no-parallel') && !args.delete('--seq') && !args.delete('-s')
    all = args.delete('-a') || args.delete('--all')
  end
  prefixes = all ? PREFIXES : PREFIXES.take(1)

  puts "testing #{prefixes} cases in #{parallel ? 'parallel' : 'sequence'}"

  to_test = args.empty? ? 1..25 : args.map(&:to_i)

  ran = to_test.flat_map { |day|
    daypad = day.to_s.rjust(2, ?0)
    unless (command = yield daypad)
      puts "No command for #{day}"
      next []
    end

    matching_inputs = prefixes.flat_map { |prefix| Dir.glob("#{__dir__}/#{prefix}-cases/#{YEAR}/#{daypad}*.{in,argv}") }.sort

    cases = if matching_inputs.empty?
      puts "no matching inputs for #{daypad}? Will try with no args?"
      matching_outputs = prefixes.flat_map { |prefix| Dir.glob("#{__dir__}/#{prefix}-cases/#{YEAR}/#{daypad}*.out") }.sort
      matching_outputs.map { |outfile|
        {
          name: daypad,
          argv: "",
          output: outfile,
        }
      }
    else
      matching_inputs.map { |infile|
        prefix = File.basename(File.dirname(File.dirname(infile))).split(?-).first
        argv = if infile.end_with?('in')
          infile
        elsif infile.end_with?('.argv')
          File.read(infile).chomp
        end
        {
          name: "#{prefix}/#{File.basename(infile)}",
          argv: argv,
          output: infile.sub(/\.(in|argv)$/, '.out'),
        }
      }
    end

    run = ->(c) {
      diff_command = "#{command} #{c[:argv]} #{pass_args.join(' ')} | diff -u - #{c[:output]}"
      start_time = Time.now
      if system(diff_command)
        puts "#{c[:name]} passed in #{Time.now - start_time}"
      else
        puts "#{c[:name]} failed in #{Time.now - start_time}"
        puts diff_command
        all_good = false
      end
    }

    if parallel
      cases.map { |c|
        {
          day: day,
          join: Thread.new { run[c] }
        }
      }
    else
      cases.map { |c|
        run[c]
        {
          day: day,
          join: JOINABLE,
        }
      }
    end
  }

  ran.each { |r| r[:join].join }
  puts "ran #{ran.size} from #{ran.uniq { |r| r[:day] }.size} days, #{all_good ? "\e[1;32mGOOD!\e[0m" : "\e[1;31mBAD!\e[0m"}"

  Kernel.exit(all_good ? 0 : 1)
end
