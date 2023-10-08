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

function get_last_log() {
  grep 'photoprism' /var/log/nginx/access.log |
    grep -v '/slideshow' |
    tail -n 1
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

  if [ "${#last_log}" -eq 0 ]; then
    photoprism_deprioritize
    sleep 10
    continue
  fi

  ts_from_log=$(ts "$last_log")
  current_timestamp=$(date '+%s')

  # Calculate the difference in seconds
  seconds_ago=$((current_timestamp - ts_from_log))

  if [ "$seconds_ago" -gt 360 ]; then
    photoprism_deprioritize
    sleep 10
  else
    photoprism_prioritize
    sleep 360
  fi

done
