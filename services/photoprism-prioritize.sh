# Function to convert month abbreviations to numbers
function month_to_num() {
  case "$1" in
  Jan) echo 1 ;;
  Feb) echo 2 ;;
  Mar) echo 3 ;;
  Apr) echo 4 ;;
  May) echo 5 ;;
  Jun) echo 6 ;;
  Jul) echo 7 ;;
  Aug) echo 8 ;;
  Sep) echo 9 ;;
  Oct) echo 10 ;;
  Nov) echo 11 ;;
  Dec) echo 12 ;;
  esac
}

function ts() {
  date_string=$(echo $1 | awk -v FPAT='\\[[^][]*]|"[^"]*"|\\S+' '{ print $4}')
  # Extract date components using awk
  day=$(echo "$date_string" | awk -F'[][/: ]+' '{print $2}')
  month=$(month_to_num $(echo "$date_string" | awk -F'[][/: ]+' '{print $3}'))
  year=$(echo "$date_string" | awk -F'[][/: ]+' '{print $4}')
  hour=$(echo "$date_string" | awk -F'[][/: ]+' '{print $5}')
  minute=$(echo "$date_string" | awk -F'[][/: ]+' '{print $6}')
  second=$(echo "$date_string" | awk -F'[][/: ]+' '{print $7}')

  # Create a timestamp for the given date
  timestamp=$(date -d "$year-$month-$day $hour:$minute:$second" '+%s')
  echo $timestamp
}

function ts_journal() {
  # Extract the time field from the log line
  time_string=$(echo $1 | grep -o 'time="[^"]*"')
  # Remove the 'time="' prefix and '"' suffix
  clean_time=${time_string#time=\"}
  clean_time=${clean_time%\"}
  # Format for date command: replace T with space and remove timezone
  clean_time_formatted=$(echo "$clean_time" | sed 's/T/ /; s/+.*//')
  # Convert to timestamp
  timestamp=$(date -d "$clean_time_formatted" '+%s')
  echo $timestamp
}

function get_last_log() {
  grep 'photoprism' /var/log/nginx/access.log |
    grep -v '/slideshow' |
    tail -n 1
}

function get_last_journal() {
  journalctl -u photoprism --grep="index: (updated|added) main" --no-pager | tail -n 1
}

current_prio=0
function photoprism_prioritize() {
  if [ "$current_prio" != "300" ]; then
    current_prio=300
    systemctl set-property --runtime photoprism.service CPUQuota=300%
    echo "systemctl set-property --runtime photoprism.service CPUQuota=300%"
  fi
}

function photoprism_deprioritize() {
  if [ "$current_prio" != "20" ]; then
    current_prio=20
    systemctl set-property --runtime photoprism.service CPUQuota=20%
    echo "systemctl set-property --runtime photoprism.service CPUQuota=20%"
  fi
}

while true; do

  last_log=$(get_last_log)

  last_journal=$(get_last_journal)

  current_timestamp=$(date '+%s')

  if [ -n "$last_log" ]; then
    ts_log=$(ts "$last_log")
    seconds_ago_log=$((current_timestamp - ts_log))
  else
    seconds_ago_log=999999
  fi

  if [ -n "$last_journal" ]; then
    ts_journal_val=$(ts_journal "$last_journal")
    seconds_ago_journal=$((current_timestamp - ts_journal_val))
  else
    seconds_ago_journal=999999
  fi

  min_seconds=$(( seconds_ago_log < seconds_ago_journal ? seconds_ago_log : seconds_ago_journal ))

  if [ "$min_seconds" -gt 360 ]; then
    photoprism_deprioritize
    sleep 10
  else
    photoprism_prioritize
    sleep 360
  fi

done
