if [ "$1" = "--yes" ]; then
  yes=1
else
  yes=0
fi

mkdir -p day

for year in $(seq 2015 2020); do
  for daypad in $(seq -w 1 25); do
    day=$(echo $daypad | sed -e s/^0//)
    cmd="curl https://adventofcode.com/$year/leaderboard/day/$day"
    tgt=day/$year-$daypad
    echo "$cmd > $tgt"
    if [ "$yes" -eq 1 ]; then
      if [ -f "$tgt" ]; then
        echo "$tgt already exist, no fetch"
      else
        $cmd > $tgt
        sleep 5
      fi
    fi
  done
done
