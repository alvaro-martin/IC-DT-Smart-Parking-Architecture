#!/usr/bin/env python3
import argparse
import pandas as pd
import numpy as np

def format_hour_bin(bin_id, bin_size):
    """Convert bin index + bin size to HH:MM."""
    total_min = bin_id * bin_size
    hour = total_min // 60
    minute = total_min % 60
    return f"{hour:02d}:{minute:02d}"

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-file", required=True,
                        help="CSV with sim_* columns containing occupied spots")
    parser.add_argument("--output-file", required=True,
                        help="CSV to save confidence interval results")
    parser.add_argument("--bin-size", required=True, type=int,
                        choices=[5, 10, 15],
                        help="Bin size in minutes")

    args = parser.parse_args()

    # Load input CSV
    df = pd.read_csv(args.input_file)

    # Extract simulation columns
    sim_cols = [c for c in df.columns if c.startswith("sim_")]
    if not sim_cols:
        raise ValueError("No simulation sim_* columns found.")

    # Number of simulations
    n = len(sim_cols)

    # Compute statistics
    df["mean"] = df[sim_cols].mean(axis=1)
    df["std"] = df[sim_cols].std(axis=1, ddof=1)      # sample standard deviation
    df["se"] = df["std"] / np.sqrt(n)                 # Standard Error

    z = 1.96                                          # 95% confidence interval

    df["lower_confidence_limit"] = df["mean"] - z * df["se"]
    df["upper_confidence_limit"] = df["mean"] + z * df["se"]

    # Round results to 3 decimals
    df["lower_confidence_limit"] = df["lower_confidence_limit"].round(3)
    df["mean"] = df["mean"].round(3)
    df["upper_confidence_limit"] = df["upper_confidence_limit"].round(3)

    # Add hour_bin
    df["hour_bin"] = df["bin_id"].apply(lambda b: format_hour_bin(b, args.bin_size))

    # Final output
    result = df[[
        "bin_id",
        "hour_bin",
        "lower_confidence_limit",
        "mean",
        "upper_confidence_limit"
    ]]

    # Save to CSV
    result.to_csv(args.output_file, index=False)

    print("Saved:", args.output_file)
    print(result.head())

if __name__ == "__main__":
    main()
