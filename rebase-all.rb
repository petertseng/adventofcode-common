branches = `git branch --remotes | grep -v master | grep origin`

good = []
bad = []
noop = []

branches.split.each { |branch|
  localname=branch.delete_prefix('origin/')

  num_commits = Integer(`git rev-list --count #{branch} ^origin/master`.chomp)
  puts "\e[1;32m#{branch}\e[0m: #{num_commits} commits"

  rebase_on_log = `git show --format="%s" -s #{branch}#{?~ * num_commits}`.chomp
  puts "\e[1;32m#{branch}\e[0m: looking for \e[1;33m#{rebase_on_log}\e[0m"

  targets = `git log master --format="%H" --grep '^#{rebase_on_log}$'`.lines
  if targets.size != 1
    puts "\e[1;32m#{branch}\e[0m: \e[1;31mExpected one target\e[0m: #{targets}"
    bad << branch
    next
  end
  target = targets[0].chomp

  system("git merge-base --is-ancestor #{target} #{branch}")
  if $?.exitstatus == 0
    puts "\e[1;32m#{branch}\e[0m: already has \e[1;33m#{target}\e[0m"
    noop << branch
    next
  else
    puts "\e[1;32m#{branch}\e[0m: will rebase on \e[1;33m#{target}\e[0m"
  end

  system("git checkout #{localname}")
  system("git rebase -i #{target}")

  remote_ref = `git show-ref #{branch}`.split[0]
  local_ref = `git show-ref #{localname}`.split[0]
  puts "\e[1;32m#{branch}\e[0m: remote #{remote_ref} local #{local_ref}"

  if remote_ref == local_ref
    noop << branch
    system("git checkout master")
    system("git branch --delete #{localname}")
    next
  end

  system("git diff #{branch} HEAD")

  puts 'CONFIRM??? (anything starting with n for no, otherwise yes)'

  if STDIN.gets.downcase.start_with?(?n)
    bad << branch
    next
  end

  system("git push --force-with-lease")
  system("git checkout master")
  system("git branch --delete #{localname}")

  good << branch
}

puts "good #{good.size}: #{good}"
puts "bad #{bad.size}: #{bad}"
puts "noop #{noop.size}: #{noop}"
