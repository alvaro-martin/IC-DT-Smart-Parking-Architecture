#!/usr/bin/env python3
import argparse
import pandas as pd

def format_hour_bin(bin_id, bin_size):
    """Convert bin index + bin size to HH:MM string."""
    total_minutes = bin_id * bin_size
    hour = total_minutes // 60
    minute = total_minutes % 60
    return f"{hour:02d}:{minute:02d}"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-file", required=True,
                        help="Monte Carlo output CSV with sim_* columns")
    parser.add_argument("--output-file", required=True,
                        help="CSV to save probability of being full")
    parser.add_argument("--capacity", required=True, type=int,
                        help="Total number of parking spots")
    parser.add_argument("--bin-size", required=True, type=int,
                        choices=[5, 10, 15],
                        help="Bin size in minutes (5, 10, or 15)")

    args = parser.parse_args()

    # Load results
    df = pd.read_csv(args.input_file)

    # Find all simulation columns
    sim_cols = [c for c in df.columns if c.startswith("sim_")]

    if not sim_cols:
        raise ValueError("No simulation columns sim_* found in the input file.")

    # Probability that occupancy == capacity
    df["prob_full"] = (df[sim_cols] == args.capacity).mean(axis=1) * 100
    df["prob_full_percent"] = df["prob_full"].round(3)

    # NEW COLUMN: hour_bin
    df["hour_bin"] = df["bin_id"].apply(lambda x: format_hour_bin(x, args.bin_size))

    # Save output
    result = df[["bin_id", "hour_bin", "prob_full_percent"]]
    result.to_csv(args.output_file, index=False)

    # Print overall mean
    print("Mean bin probability of being full:", result["prob_full_percent"].mean().round(3), "%")
    print("Max bin probability of being full:", result["prob_full_percent"].max().round(3), "%")

    print("Saved:", args.output_file)
    print(result.head())

if __name__ == "__main__":
    main()