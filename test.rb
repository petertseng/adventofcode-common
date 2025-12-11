require 'time'
require 'thread'

if Dir.pwd.include?('adventofcode')
  YEAR = Integer(Dir.pwd.scan(/\d+/).last)
  TEST_TYPES = %w(secret sample).select { |test_type| File.directory?("#{__dir__}/#{test_type}-cases/#{YEAR}") }.map(&:freeze).freeze
  MAX_DAY = YEAR >= 2025 ? 12 : 25
else
  YEAR = ?..freeze
  TEST_TYPES = %w(secret sample).freeze
  MAX_DAY = 20
end

JOINABLE = Object.new
def JOINABLE.join; end

def test_and_exit(args = ARGV, dir: __dir__)
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
  test_types = all ? TEST_TYPES : TEST_TYPES.take(1)

  puts "testing #{test_types} cases in #{parallel ? 'parallel' : 'sequence'}"

  to_test = args.empty? ? 1..MAX_DAY : args.map(&method(:Integer))

  fail_by_day = Hash.new(0)
  fail_lock = Mutex.new

  ran = to_test.flat_map { |day|
    daypad = day.to_s.rjust(2, ?0)
    unless (command = yield daypad)
      puts "No command for #{day}"
      next []
    end

    matching_inputs = test_types.flat_map { |test_type| Dir.glob("#{dir}/#{test_type}-cases/#{YEAR}/#{daypad}*.{in,argv}") }.sort

    cases = if matching_inputs.empty?
      puts "no matching inputs for #{daypad}? Will try with no args?"
      matching_outputs = test_types.flat_map { |test_type| Dir.glob("#{dir}/#{test_type}-cases/#{YEAR}/#{daypad}*.out") }.sort
      matching_outputs.map { |outfile|
        {
          name: daypad,
          argv: "",
          output: outfile,
        }
      }
    else
      matching_inputs.group_by { |v| v[0...v.rindex(?.)] }.map { |without_ext, with_exts|
        test_type = File.basename(File.dirname(File.dirname(without_ext))).split(?-).first
        argv = with_exts.map { |infile|
          if infile.end_with?('.in')
            infile
          elsif infile.end_with?('.argv')
            File.read(infile).chomp
          end
        }.join(' ')
        {
          name: "#{test_type}/#{File.basename(without_ext)}",
          argv: argv,
          output: without_ext + '.out',
        }
      }
    end

    run = ->(c) {
      diff_command = "#{command} #{c[:argv]} #{pass_args.join(' ')} | diff -u - #{c[:output]}"
      start_time = Time.now
      system(diff_command).tap { |success|
        puts "#{c[:name]} #{success ? :pass : :fail}ed in #{Time.now - start_time}"
        puts diff_command unless success
      }
    }

    if parallel
      cases.map { |c|
        {
          day: day,
          join: Thread.new { fail_lock.synchronize { fail_by_day[day] += 1 } unless run[c] }
        }
      }
    else
      cases.map { |c|
        fail_by_day[day] += 1 unless run[c]
        {
          day: day,
          join: JOINABLE,
        }
      }
    end
  }

  ran.each { |r| r[:join].join }
  fails = fail_by_day.values.sum
  successes = ran.size - fails
  all_good = fails == 0
  puts "ran #{ran.size} from #{ran.uniq { |r| r[:day] }.size} days #{all_good ? "\e[1;32m#{successes}/#{ran.size} pass\e[0m" : "#{successes}/#{ran.size} pass \e[1;31m#{fails}/#{ran.size} fail\e[0m (from #{fail_by_day.size} days)"}"

  Kernel.exit(all_good ? 0 : 1)
end
