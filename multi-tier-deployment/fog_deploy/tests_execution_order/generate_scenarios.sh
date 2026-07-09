#!/usr/bin/env bash

# generate_scenarios.sh
# Generates a randomized list of load test scenarios in CSV format.
# Automatically names output file as: randomized_load_test_scenario_seed_<SEED>.csv
# Usage: ./generate_scenarios.sh --seed <SEED>

set -euo pipefail  # Strict error handling

# Default values
SEED=""
OUTPUT_FILE=""

# Help message
usage() {
  cat <<EOF
Usage: $0 --seed <SEED> [--output <FILE>]

Options:
  --seed <SEED>     Integer seed for randomization (required)
  --output <FILE>   Output CSV file (optional; auto-generated if omitted)
  --help            Show this help message

Generates a CSV of randomized load test scenarios with columns:
M, N, alpha, beta

If --output is not given, the file will be named:
  randomized_load_test_scenario_seed_<SEED>.csv
EOF
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --seed requires a positive integer." >&2
        exit 1
      fi
      SEED="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Validate required argument
if [[ -z "$SEED" ]]; then
  echo "Error: --seed is required." >&2
  usage >&2
  exit 1
fi

# Auto-generate output filename if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
  OUTPUT_FILE="randomized_load_test_scenario_seed_${SEED}.csv"
fi

# Define all scenarios as "M,t,alpha,beta"
read -r -d '' SCENARIOS <<EOF || true
136,30,1,1
136,30,1,5
136,30,5,1
136,30,5,5
136,30,2,5
136,30,5,2
136,30,2,2
136,30,10,10
136,30,100,100
136,60,1,1
136,60,1,5
136,60,5,1
136,60,5,5
136,60,2,5
136,60,5,2
136,60,2,2
136,60,10,10
136,60,100,100
136,120,1,1
136,120,1,5
136,120,5,1
136,120,5,5
136,120,2,5
136,120,5,2
136,120,2,2
136,120,10,10
136,120,100,100
136,180,1,1
136,180,1,5
136,180,5,1
136,180,5,5
136,180,2,5
136,180,5,2
136,180,2,2
136,180,10,10
136,180,100,100
136,240,1,1
136,240,1,5
136,240,5,1
136,240,5,5
136,240,2,5
136,240,5,2
136,240,2,2
136,240,10,10
136,240,100,100
136,300,1,1
136,300,1,5
136,300,5,1
136,300,5,5
136,300,2,5
136,300,5,2
136,300,2,2
136,300,10,10
136,300,100,100
250,60,1,1
250,60,1,5
250,60,5,1
250,60,5,5
250,60,2,5
250,60,5,2
250,60,2,2
250,60,10,10
250,60,100,100
500,60,1,1
500,60,1,5
500,60,5,1
500,60,5,5
500,60,2,5
500,60,5,2
500,60,2,2
500,60,10,10
500,60,100,100
1000,60,1,1
1000,60,1,5
1000,60,5,1
1000,60,5,5
1000,60,2,5
1000,60,5,2
1000,60,2,2
1000,60,10,10
1000,60,100,100
EOF

# Optional: validate scenario count
TOTAL=$(echo "$SCENARIOS" | grep -c '^')
if [[ $TOTAL -ne 81 ]]; then
  echo "Warning: Expected 81 scenarios, found $TOTAL." >&2
fi

# Generate CSV with seeded random order
{
  echo "M,N,alpha,beta"
  echo "$SCENARIOS" | awk -v seed="$SEED" '
    BEGIN { srand(seed) }
    { print rand(), $0 }
  ' | sort -n | cut -d" " -f2-
} > "$OUTPUT_FILE"

echo "Scenarios written to: $OUTPUT_FILE"
