#!/bin/bash

# Function to show usage information
usage() {
  echo "Usage: $0 <csv_file>"
  echo "Calculates the mean value of the 'inference_time_s' column in a CSV file."
  echo
  echo "Example:"
  echo "  $0 data.csv"
  exit 1
}

# Check if an argument (file name) was provided
if [ $# -ne 1 ]; then
  usage
fi

FILE="$1"

# Check if the file exists
if [ ! -f "$FILE" ]; then
  echo "Error: File not found -> $FILE"
  exit 1
fi

# Calculate the mean of the inference_time_s column (skipping header)
mean=$(awk -F',' 'NR>1 {sum+=$1; count++} END {if (count>0) print sum/count; else print "NaN"}' "$FILE")

echo "Mean inference_time_s: $mean"

