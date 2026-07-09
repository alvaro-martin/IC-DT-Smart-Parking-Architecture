#!/bin/bash
# =============================================================================
# Script Name: parse_inference_log.sh
# Description: Extracts inference metrics from container logs and saves as CSV.
# Usage: ./process_jetson_logs.sh --input-file <input_log> [--output-file <output_csv>]
# =============================================================================

set -euo pipefail

# --------------------------- #
#          FUNCTIONS          #
# --------------------------- #

usage() {
    echo "Usage: $0 --input-file <input_log> [--output-file <output_csv>]"
    echo
    echo "Parses log lines containing inference information like:"
    echo "  INFO:inference:Inference finished:  0.404425 sec, cars=2, CPU=2.9%, MEM=3456.2MB"
    echo
    echo "Outputs a CSV file with the following columns:"
    echo "  inference_time_s, cars, cpu_usage_percent, mem_used_MB"
    echo
    echo "Options:"
    echo "  --input-file <path>     Path to the log file (required)"
    echo "  --output-file <path>    Output CSV file (optional, default: parsed_inference.csv)"
    echo "  -h, --help              Show this help message"
    exit 1
}

# --------------------------- #
#       ARGUMENT PARSING      #
# --------------------------- #

input_file=""
output_file="parsed_inference.csv"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input-file)
            input_file="$2"
            shift 2
            ;;
        --output-file)
            output_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ -z "$input_file" ]]; then
    echo "Error: --input-file is required." >&2
    usage
fi

if [[ ! -f "$input_file" ]]; then
    echo "Error: input file '$input_file' not found." >&2
    exit 1
fi

# --------------------------- #
#        CSV CREATION         #
# --------------------------- #

echo "inference_time_s,cars,cpu_usage_percent,mem_used_MB" > "$output_file"

grep "INFO:inference:Inference finished:" "$input_file" | \
while IFS= read -r line; do
    time=$(echo "$line" | sed -E 's/.*Inference finished:[[:space:]]*([0-9.]+) sec.*/\1/')
    cars=$(echo "$line" | sed -E 's/.*cars=([0-9]+).*/\1/')
    cpu=$(echo "$line" | sed -E 's/.*CPU=([0-9.]+)%.*/\1/')
    mem=$(echo "$line" | sed -E 's/.*MEM=([0-9.]+)MB.*/\1/')

    echo "$time,$cars,$cpu,$mem" >> "$output_file"
done

echo "✅ CSV successfully created: $output_file"

