#!/usr/bin/env bash
# =============================================================================
# Script Name: gpu_logger.sh
# Description: Logs GPU metrics (load, temperature, power, memory) every second into a CSV.
# Usage: ./gpu_logger.sh [--duration <seconds|Xm|Xh>] [output_file.csv]
# =============================================================================

set -euo pipefail

# --------------------------- #
#          DEFAULTS           #
# --------------------------- #
OUTPUT_FILE="gpu_log.csv"
INTERVAL=1
DURATION=""

# --------------------------- #
#        PARSE ARGUMENTS      #
# --------------------------- #
while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration)
      DURATION="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--duration <seconds|Xm|Xh>] [output_file.csv]"
      echo "Example: $0 --duration 10m my_log.csv"
      exit 0
      ;;
    *)
      OUTPUT_FILE="$1"
      shift
      ;;
  esac
done

# --------------------------- #
#     CONVERT DURATION        #
# --------------------------- #
convert_to_seconds() {
  local input="$1"
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    echo "$input"
  elif [[ "$input" =~ ^([0-9]+)s$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$input" =~ ^([0-9]+)m$ ]]; then
    echo "$(( ${BASH_REMATCH[1]} * 60 ))"
  elif [[ "$input" =~ ^([0-9]+)h$ ]]; then
    echo "$(( ${BASH_REMATCH[1]} * 3600 ))"
  else
    echo "Invalid duration format: $input (use seconds, Xm, or Xh)" >&2
    exit 1
  fi
}

# --------------------------- #
#        MAIN SCRIPT          #
# --------------------------- #
mkdir -p "$(dirname "$OUTPUT_FILE")"
echo "time,load_percentage,temp_Celsius,power_W,memory_MiB" > "$OUTPUT_FILE"

echo "Logging GPU stats every ${INTERVAL}s into ${OUTPUT_FILE} (Ctrl+C to stop)..."

start_time=$(date +%s)
if [[ -n "$DURATION" ]]; then
  duration_seconds=$(convert_to_seconds "$DURATION")
  echo "⏱ Duration set to ${DURATION} (${duration_seconds}s)"
else
  duration_seconds=0
fi

while true; do
  current_time=$(date +%s)
  elapsed=$((current_time - start_time))

  if [[ "$duration_seconds" -gt 0 && "$elapsed" -ge "$duration_seconds" ]]; then
    echo "✅ Duration reached. Logging stopped."
    break
  fi

  line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw,memory.used \
                    --format=csv,noheader,nounits)
  timestamp=$(date +"%b %d %Y %H:%M:%S")
  echo "$timestamp, $line" >> "$OUTPUT_FILE"

  sleep "$INTERVAL"
done
