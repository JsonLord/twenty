#!/bin/sh
set -eu

printf '%-20s %10s\n' 'component' 'RSS MiB'
printf '%-20s %10s\n' '--------------------' '----------'
total=0
report() {
  name=$1 expression=$2
  kib=$(ps -eo rss=,comm=,args= | awk "$expression { sum += \$1 } END { print sum + 0 }")
  mib=$(awk -v kib="$kib" 'BEGIN { printf "%.1f", kib / 1024 }')
  printf '%-20s %10s\n' "$name" "$mib"
  total=$((total + kib))
}

report 'Twenty server' '$2 == "node" && $0 ~ /node dist\/main/'
report 'Twenty worker' '$2 == "node" && $0 ~ /node dist\/queue-worker/'
report 'PostgreSQL' '$2 ~ /^postgres/'
report 'Redis' '$2 == "redis-server"'
report 'supervisor' '$2 == "dumb-init" || $2 ~ /^twenty-hf-entry/'
awk -v kib="$total" 'BEGIN { printf "%-20s %10.1f\n", "TOTAL", kib / 1024 }'
