#!/bin/bash
# =============================================================================
# Script Name: parse_log.sh
# Description: Parse Jetson system logs into CSV format.
# Usage: ./parse_log.sh --input-file <input_log> [--output-file <output_csv>]
# =============================================================================

set -euo pipefail

# --------------------------- #
#          FUNCTIONS          #
# --------------------------- #

usage() {
  echo "Usage: $0 --input-file <input_log> [--output-file <output_csv>]"
  echo
  echo "Parses Jetson system monitor logs into CSV format."
  echo
  echo "Example:"
  echo "  $0 --input-file system_monitor.log"
  echo "  $0 --input-file system_monitor.log --output-file output.csv"
  echo
  echo "Options:"
  echo "  --input-file <path>     Path to input log file (required)"
  echo "  --output-file <path>    Path to output CSV file (optional, default: <input>.csv)"
  echo "  -h, --help              Show this help message"
  exit 1
}

# --------------------------- #
#       ARGUMENT PARSING      #
# --------------------------- #

input_file=""
output_file=""

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
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

# --------------------------- #
#         VALIDATION          #
# --------------------------- #

if [[ -z "$input_file" ]]; then
  echo "❌ Error: --input-file is required."
  usage
fi

if [[ ! -f "$input_file" ]]; then
  echo "❌ Error: File '$input_file' not found."
  exit 1
fi

if [[ -z "$output_file" ]]; then
  output_file="${input_file%.*}.csv"
fi

# --------------------------- #
#        CSV GENERATION       #
# --------------------------- #

# Write CSV header
echo "ram_used_MB,ram_total_MB,lfb_free_contiguous_blocks,lfb_block_size_MB,swap_used_MB,swap_total_MB,swap_data_cached_MB,cpu_0_percent,cpu_1_percent,cpu_2_percent,cpu_3_percent,external_memory_controller_percent,gpu_workload_percent,phase_locked_loop_Celsius,cpu_temp_Celsius,pmic_temp_Celsius,gpu_temp_Celsius,ao_temp_Celsius,combined_system_temperature_estimate_Celsius" > "$output_file"

# Process file line by line
while IFS= read -r line; do
  ram_used=$(grep -oP 'RAM \K[0-9]+(?=/)' <<< "$line" || true)
  ram_total=$(grep -oP 'RAM [0-9]+/\K[0-9]+' <<< "$line" || true)
  lfb_blocks=$(grep -oP 'lfb \K[0-9]+(?=x)' <<< "$line" || true)
  lfb_block_size=$(grep -oP 'lfb [0-9]+x\K[0-9]+' <<< "$line" || true)
  swap_used=$(grep -oP 'SWAP \K[0-9]+(?=/)' <<< "$line" || true)
  swap_total=$(grep -oP 'SWAP [0-9]+/\K[0-9]+' <<< "$line" || true)
  swap_cached=$(grep -oP 'cached \K[0-9]+' <<< "$line" || true)

  # Extract CPU percentages (remove @freq)
  cpu_vals=$(grep -oP 'CPU \[\K[^\]]+' <<< "$line" | sed 's/@[0-9]*//g' | tr -d '%' | tr ',' ' ' || true)
  cpu_0=$(awk '{print $1}' <<< "$cpu_vals")
  cpu_1=$(awk '{print $2}' <<< "$cpu_vals")
  cpu_2=$(awk '{print $3}' <<< "$cpu_vals")
  cpu_3=$(awk '{print $4}' <<< "$cpu_vals")

  emc_freq=$(grep -oP 'EMC_FREQ \K[0-9]+' <<< "$line" || true)
  gr3d_freq=$(grep -oP 'GR3D_FREQ \K[0-9]+' <<< "$line" || true)

  pll_temp=$(grep -oP 'PLL@\K[0-9.]+' <<< "$line" || true)
  cpu_temp=$(grep -oP 'CPU@\K[0-9.]+' <<< "$line" || true)
  pmic_temp=$(grep -oP 'PMIC@\K[0-9.]+' <<< "$line" || true)
  gpu_temp=$(grep -oP 'GPU@\K[0-9.]+' <<< "$line" || true)
  ao_temp=$(grep -oP 'AO@\K[0-9.]+' <<< "$line" || true)
  thermal_temp=$(grep -oP 'thermal@\K[0-9.]+' <<< "$line" || true)

  echo "$ram_used,$ram_total,$lfb_blocks,$lfb_block_size,$swap_used,$swap_total,$swap_cached,$cpu_0,$cpu_1,$cpu_2,$cpu_3,$emc_freq,$gr3d_freq,$pll_temp,$cpu_temp,$pmic_temp,$gpu_temp,$ao_temp,$thermal_temp" >> "$output_file"
done < "$input_file"

echo "✅ CSV generated successfully: $output_file"

