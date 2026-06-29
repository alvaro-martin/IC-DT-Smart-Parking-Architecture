#!/usr/bin/env python3
import argparse
import pandas as pd

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
                        help="CSV to save prediction interval results")
    parser.add_argument("--bin-size", required=True, type=int,
                        choices=[5, 10, 15],
                        help="Bin size in minutes")
    parser.add_argument("--prediction-interval", required=True, type=float,
                        help="Interval percentage (e.g. 90, 95, 99)")

    args = parser.parse_args()

    # Load input CSV
    df = pd.read_csv(args.input_file)

    # Extract simulation columns
    sim_cols = [c for c in df.columns if c.startswith("sim_")]
    if not sim_cols:
        raise ValueError("No simulation columns sim_* found in the file.")

    # Compute percentiles
    alpha = (100 - args.prediction_interval) / 2
    low_p = alpha               # e.g. 5 when interval = 90
    high_p = 100 - alpha        # e.g. 95 when interval = 90

    df["p_low"] = df[sim_cols].quantile(low_p / 100.0, axis=1).astype(int)
    df["p_high"] = df[sim_cols].quantile(high_p / 100.0, axis=1).astype(int)

    # Hour bin column
    df["hour_bin"] = df["bin_id"].apply(lambda b: format_hour_bin(b, args.bin_size))

    # ======================================================
    # #### ADD mean_occupied_spots to output (minimal change)
    # ======================================================
    result = df[["bin_id", "hour_bin", "p_low", "mean_occupied_spots", "p_high"]]
    # ======================================================

    # Save final CSV
    result.to_csv(args.output_file, index=False)

    print(f"Saved: {args.output_file}")
    print(result.head())

if __name__ == "__main__":
    main()