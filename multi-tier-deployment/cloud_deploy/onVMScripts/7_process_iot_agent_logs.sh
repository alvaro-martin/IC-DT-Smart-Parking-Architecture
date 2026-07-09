#!/usr/bin/env bash
set -euo pipefail

# 7_process_iot_agent_logs.sh
# Processes the single raw_docker_logs_fiware-iot-agent_M_*.log file
# and writes a processed CSV in the same directory.

process_file() {
  local LOG_FILE="$1"
  local CSV_FILE="$2"

  echo "➡️  Processing $LOG_FILE → $CSV_FILE"
  echo "correlationID,entity_id,observedAt,response_time_ms" > "$CSV_FILE"

  declare -A ENTITY
  declare -A OBSERVED
  local current_corr=""

  while IFS= read -r line; do
    if [[ $line =~ corr=([a-f0-9-]+) ]]; then
      current_corr="${BASH_REMATCH[1]}"
    fi

    if [[ $line =~ \"id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      ENTITY["$current_corr"]="${BASH_REMATCH[1]}"
    fi

    if [[ $line =~ \"observedAt\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      OBSERVED["$current_corr"]="${BASH_REMATCH[1]}"
    fi

    if [[ $line =~ response-time:\ ([0-9]+) ]]; then
      rt="${BASH_REMATCH[1]}"
      eid="${ENTITY[$current_corr]:-}"
      obs="${OBSERVED[$current_corr]:-}"

      if [[ -n "$eid" && -n "$obs" ]]; then
        printf '%s,%s,%s,%s\n' \
          "$current_corr" "$eid" "$obs" "$rt" \
          >> "$CSV_FILE"
        unset ENTITY["$current_corr"]
        unset OBSERVED["$current_corr"]
      fi
    fi
  done < "$LOG_FILE"

  echo "✅ Done! Processed data written to $CSV_FILE"
}

# ─── MAIN ─────────────────────────────────────────────────────────────

OUT_DIR="."

# Parse args (only --out-dir is supported)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Match the *first* file starting with "raw_docker_logs_fiware-iot-agent_M_" in OUT_DIR
LOG_FILE=$(ls "$OUT_DIR"/*.log-agent 2>/dev/null | head -n 1 || true)

if [[ -z "$LOG_FILE" ]]; then
  echo "❌ No matching log file found in $OUT_DIR"
  exit 1
fi

base="$(basename "$LOG_FILE" .log)"
out="$OUT_DIR/processed_${base}.csv"
process_file "$LOG_FILE" "$out"

