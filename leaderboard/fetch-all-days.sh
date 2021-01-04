if [ "$1" = "--yes" ]; then
  yes=1
else
  yes=0
fi

mkdir -p day

for year in $(seq 2015 2022); do
  for daypad in $(seq -w 1 25); do
    day=$(echo $daypad | sed -e s/^0//)
    tgt=day/$year-$daypad
    cmd="curl --user-agent 'https://github.com/petertseng/adventofcode-common/blob/master/leaderboard/fetch-all-days.sh' -o $tgt https://adventofcode.com/$year/leaderboard/day/$day"
    echo "$cmd"
    if [ "$yes" -eq 1 ]; then
      if [ -f "$tgt" ]; then
        echo "$tgt already exist, no fetch"
      else
        $cmd
        sleep 5
      fi
    fi
  done
done
