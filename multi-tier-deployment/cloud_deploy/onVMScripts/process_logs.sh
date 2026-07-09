#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# process_logs.sh
#
# Extract inference statistics from a Docker log file and convert them to CSV.
# -----------------------------------------------------------------------------
# Usage:
#   ./process_logs.sh --input <log_file> [--out-dir <output_directory>]
#
# Example:
#   ./process_logs.sh --input ./logs/app.log
#   ./process_logs.sh --input ./logs/app.log --out-dir ./processed
#
# Output:
#   CSV file named processed_<basename>.csv in the given or default directory.
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $0 --input <log_file> [--out-dir <output_directory>]

Options:
  --input    Path to the input log file (required)
  --out-dir  Directory to save results (default: ./results)
  -h, --help Show this help message and exit

Example:
  $0 --input ./docker_output.log
  $0 --input ./docker_output.log --out-dir ./processed
EOF
    exit 1
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
INPUT=""
OUT_DIR="./results"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input)
            INPUT="${2:-}"
            shift 2
            ;;
        --out-dir)
            OUT_DIR="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "❌ Unknown parameter: $1"
            usage
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
if [[ -z "$INPUT" ]]; then
    echo "❌ Error: --input argument is required."
    usage
fi

if [[ ! -f "$INPUT" ]]; then
    echo "❌ Error: Input file '$INPUT' not found."
    exit 1
fi

# -----------------------------------------------------------------------------
# Main processing
# -----------------------------------------------------------------------------
mkdir -p "$OUT_DIR"

# Get clean base filename (strip path and .log if present)
BASENAME="$(basename "${INPUT%.*}")"
OUTPUT="${OUT_DIR}/processed_${BASENAME}.csv"

# Write CSV header safely (overwrite if exists)
{
    echo "inference_time_s,cars_detected,cpu_usage_percentage,memory_usage_MB"
    grep -F "Inference finished" "$INPUT" | \
    sed -E 's/.*: +([0-9.]+) sec, cars=([0-9]+), CPU=([0-9.]+)%, MEM=([0-9.]+)MB/\1,\2,\3,\4/'
} > "$OUTPUT"

# -----------------------------------------------------------------------------
# Success message
# -----------------------------------------------------------------------------
echo "✅ Successfully processed:"
echo "   Input : $INPUT"
echo "   Output: $OUTPUT"
echo "📄 CSV file created with columns: inference_time_s, cars_detected, cpu_usage_percentage, memory_usage_MB"

