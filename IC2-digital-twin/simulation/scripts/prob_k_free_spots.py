#!/usr/bin/env python3
import argparse
import pandas as pd
import numpy as np

# =====================================================================
# Helpers
# =====================================================================

def generate_hour_label(bin_id, bin_size):
    """
    Convert a bin_id into HH:MM based on the bin size in minutes.
    """
    minutes = bin_id * bin_size
    hh = minutes // 60
    mm = minutes % 60
    return f"{hh:02d}:{mm:02d}"


def compute_probability_free_spots(row, sim_cols, capacity, k):
    """
    Given a row and simulation columns, compute P(free_spots >= k)
    """
    occupied = row[sim_cols].values
    free = capacity - occupied

    return round(np.mean(free >= k) * 100.0, 3)   # return in percent


# =====================================================================
# Main
# =====================================================================

def main():
    parser = argparse.ArgumentParser(description="Compute probability of k or more free spots for each bin")
    parser.add_argument("--input-file", required=True, help="CSV containing bin_id, means, and simulation columns")
    parser.add_argument("--output-file", required=True, help="Output CSV file")
    parser.add_argument("--bin-size", type=int, required=True, help="Bin size in minutes (5, 10, 15, etc.)")
    parser.add_argument("--free-spots", type=int, required=True, help="k = number of free spots required")
    parser.add_argument("--capacity", type=int, required=True, help="Total number of parking spots")

    args = parser.parse_args()

    # === Load CSV ===
    df = pd.read_csv(args.input_file)

    # Identify sim_* columns
    sim_cols = [c for c in df.columns if c.startswith("sim_")]

    if len(sim_cols) == 0:
        raise ValueError("No simulation columns (sim_*) found in the CSV")

    print(f"Detected {len(sim_cols)} simulation columns")

    # === Compute probability for each bin ===
    df["prob_free_spots"] = df.apply(
        lambda row: compute_probability_free_spots(
            row,
            sim_cols=sim_cols,
            capacity=args.capacity,
            k=args.free_spots
        ),
        axis=1
    )

    # === Create hour_bin ===
    df["hour_bin"] = df["bin_id"].apply(lambda x: generate_hour_label(x, args.bin_size))

    # === Keep only required columns ===
    out_df = df[["bin_id", "hour_bin", "prob_free_spots"]]

    # === Save CSV ===
    out_df.to_csv(args.output_file, index=False)

    print(f"Saved results to {args.output_file}")


if __name__ == "__main__":
    main()
