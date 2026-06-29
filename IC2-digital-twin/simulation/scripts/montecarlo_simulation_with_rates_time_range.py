#!/usr/bin/env python3
import argparse
import pandas as pd
import numpy as np
import ast
from datetime import datetime, timedelta

# ============================================================
# Helpers
# ============================================================

def parse_array(cell):
    """Parses strings like "[1,2,3]" into Python lists."""
    if isinstance(cell, str) and cell.startswith("["):
        arr = ast.literal_eval(cell)
        return arr if isinstance(arr, list) else []
    return []


def time_to_min(tstr):
    """Convert HH:MM string into minutes from midnight."""
    h, m = map(int, tstr.split(":"))
    return h * 60 + m


def scale_dwell(dwell_list, percent):
    """Scale dwell times by a percentage (floats allowed)."""
    if len(dwell_list) == 0:
        return dwell_list
    scaled = [max(0.0, d * (1 + percent)) for d in dwell_list]
    return scaled


# ============================================================
# Simulation (with warm-up days)
# ============================================================

def simulate_day_with_warmup(arrivals_per_bin, dwell_per_bin, minutes_per_bin, capacity, warmup_days, percent_arrivals, modify_mask):

    num_bins = len(arrivals_per_bin)
    total_bins = num_bins * (warmup_days + 1)  # warmup + 1 real day

    t = 0
    occupied_until = np.full(capacity, -1.0)
    occupancy = []

    for i in range(total_bins):

        # ---------------------
        # 1. Sample arrivals
        # ---------------------
        bin_index = i % num_bins
        if len(arrivals_per_bin[bin_index]) > 0:
            base_mean = float(np.mean(arrivals_per_bin[bin_index]))
            if modify_mask[bin_index]:
                p = max(0.0, 1.0 + percent_arrivals)
            else:
                p = 1.0
            lam = base_mean * p
            arrivals = np.random.poisson(lam)
        else:
            arrivals = 0

        current_time = t

        # ---------------------
        # 2. Free up completed dwell times
        # ---------------------
        occupied_until[occupied_until <= current_time] = -1

        # ---------------------
        # 3. Assign arriving cars
        # ---------------------
        free_spots = np.where(occupied_until == -1)[0]

        if arrivals > 0 and len(free_spots) > 0:
            n_to_park = min(arrivals, len(free_spots))
            chosen_spots = np.random.choice(free_spots, size=n_to_park, replace=False)

            # Sample dwell time for this bin
            if len(dwell_per_bin[bin_index]) > 0:
                dwell_samples = np.random.choice(dwell_per_bin[bin_index], size=n_to_park)
            else:
                dwell_samples = np.zeros(n_to_park)

            occupied_until[chosen_spots] = current_time + dwell_samples

        # ---------------------
        # 4. Record occupancy *only after warm-up*
        # ---------------------
        if i >= warmup_days * num_bins:
            n_occ = np.sum(occupied_until > current_time)
            occupancy.append(n_occ / capacity)

        t += minutes_per_bin

    return occupancy


# ============================================================
# CLI
# ============================================================

def main():
    parser = argparse.ArgumentParser()

    parser.add_argument("--input-arrival-file", required=True)
    parser.add_argument("--input-dwell-file", required=True)
    parser.add_argument("--bin-size", required=True, type=int)
    parser.add_argument("--num-simulations", required=True, type=int)
    parser.add_argument("--spots", required=True, type=int)
    parser.add_argument("--warm-up-days", required=True, type=int, choices=[1, 2, 3], help="Number of warm-up days (1–3).")
    parser.add_argument("--output-file", required=True)
    parser.add_argument("--modify-from", required=False, default=None, help="Start time HH:MM where modifications begin.")
    parser.add_argument("--modify-to", required=False, default=None, help="End time HH:MM where modifications stop.")
    parser.add_argument("--percent-arrivals", required=False, type=float, default=0.0)
    parser.add_argument("--percent-dwell-time", required=False, type=float, default=0.0)

    args = parser.parse_args()

    # ===============================
    # Load arrival data
    # ===============================
    adf = pd.read_csv(args.input_arrival_file)
    arrivals_per_bin = adf["arrivals"].apply(parse_array).tolist()

    # ===============================
    # Load dwell data
    # ===============================
    ddf = pd.read_csv(args.input_dwell_file)
    dwell_per_bin = ddf["dwell_time_min"].apply(parse_array).tolist()

    # Pad dwell list if needed
    if len(dwell_per_bin) < len(arrivals_per_bin):
        for _ in range(len(arrivals_per_bin) - len(dwell_per_bin)):
            dwell_per_bin.append([])

    # ======================================================
    # Determine bins inside modification window
    # Minimal, robust logic:
    # - If BOTH modify-from and modify-to are missing/empty -> apply to ALL bins.
    # - If BOTH present -> compute mask for that window.
    # - If ONLY one is provided -> raise an error to avoid ambiguity.
    # ======================================================
    mf = args.modify_from
    mt = args.modify_to

    if (mf in [None, ""]) and (mt in [None, ""]):
        # neither provided -> apply to all bins
        modify_mask = [True] * len(arrivals_per_bin)
    elif (mf not in [None, ""]) and (mt not in [None, ""]):
        # both provided -> compute window
        start_min = time_to_min(mf)
        end_min = time_to_min(mt)

        modify_mask = []
        for bin_id in adf["bin_id"]:
            bin_start_min = bin_id * args.bin_size
            modify_mask.append(start_min <= bin_start_min < end_min)
    else:
        # only one provided -> ambiguous: raise a helpful error
        parser.error("Either provide both --modify-from and --modify-to, or provide neither. (Ambiguous single parameter)")

    # ======================================================
    # Apply modifications
    # ======================================================
    for i in range(len(arrivals_per_bin)):
        if modify_mask[i]:
            dwell_per_bin[i] = scale_dwell(dwell_per_bin[i], args.percent_dwell_time)

    # ======================================================
    # Run simulations
    # ======================================================
    results = np.array([
        simulate_day_with_warmup(
            arrivals_per_bin,
            dwell_per_bin,
            args.bin_size,
            args.spots,
            args.warm_up_days,
            args.percent_arrivals,
            modify_mask
        )
        for _ in range(args.num_simulations)
    ])

    mean_occupancy = results.mean(axis=0)
    mean_occupied_spots = mean_occupancy * args.spots

    sim_cols = {f"sim_{i}": results[i] for i in range(args.num_simulations)}

    # ===============================
    # Save output
    # ===============================
    out = pd.DataFrame({
        "bin_id": adf["bin_id"],
        "mean_occupancy": mean_occupancy,
        "mean_occupied_spots": mean_occupied_spots
    })

    for k, v in sim_cols.items():
        out[k] = v * args.spots

    out.to_csv(args.output_file, index=False)

    print("Saved:", args.output_file)
    print(out.head())


if __name__ == "__main__":
    main()
