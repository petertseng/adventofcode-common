if [ $# -eq 0 ]; then
  echo "usage: $0 year"
  exit 1
fi

year=$1

for day in $(seq -w 01 25); do
  cp ../adventofcode-rb-$year/expected_output/$day ./secret-cases/$year/${day}p.out
  if grep __END__ ~/src/adventofcode-rb-$year/$day*.rb > /dev/null; then
    grep -A9999 __END__ ~/src/adventofcode-rb-$year/$day*.rb | tail +2 > ./secret-cases/$year/${day}p.in
  else
    echo "$day no data"
  fi
done

