#!/usr/bin/env bash
set -euo pipefail

serviceName="home-assistant.service"

startTime=$(systemctl show -p ActiveEnterTimestamp "$serviceName")
startTime=$(echo $startTime | awk '{print $2 $3}')

echo "Missing modules reported since $serviceName start at $startTime:"

lines=$(journalctl -u "$serviceName" --output=cat --no-pager --since="$startTime")
regex="Unable to set up dependencies of \w+. Setup failed for dependencies: (\w+)"

allMatches=()
while IFS= read -r line; do
  if [[ $line =~ $regex ]]; then
    allMatches+=("${BASH_REMATCH[1]}")
  fi
done <<< "$lines"

uniqueMatches=()
while IFS= read -r -d '' match; do
    uniqueMatches+=("$match")
done < <(printf "%s\0" "${allMatches[@]}" | sort -uz)

for match in "${uniqueMatches[@]}"; do
  echo "$match"
done
