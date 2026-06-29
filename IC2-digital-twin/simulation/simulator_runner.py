import subprocess
import tempfile
import pandas as pd
from pathlib import Path

def plot_results(df_sim, real_file=None):
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np

    # ---------------------------
    # Prepare simulated data
    # ---------------------------
    sim_bins = df_sim["bin_id"]
    sim_values = df_sim["mean_occupied_spots"]

    # Create hour labels every 12 bins (60 minutes / 5-min bins = 12)
    hour_ticks = np.arange(0, len(sim_bins), 12)
    hour_labels = [f"{str(int(h)).zfill(2)}:00" for h in range(24)]

    plt.figure(figsize=(14, 6))

    # ---------------------------
    # Plot simulated data
    # ---------------------------
    plt.plot(
        sim_bins,
        sim_values,
        marker='.',
        linestyle='-',
        label="Simulated mean occupied spots"
    )

    # ---------------------------
    # Plot real data (if provided)
    # ---------------------------
    if real_file is not None:
        df_real = pd.read_csv(real_file)

        if "bin_id" not in df_real or "mean_occupied_spots" not in df_real:
            raise ValueError("Real file must contain columns: bin_id, mean_occupied_spots")

        plt.plot(
            df_real["bin_id"],
            df_real["mean_occupied_spots"],
            marker='.',
            linestyle='--',
            label="Real mean occupied spots"
        )

    # ---------------------------
    # Formatting
    # ---------------------------
    plt.xticks(hour_ticks, hour_labels, rotation=45)
    plt.xlabel("Hour of Day")
    plt.ylabel("Mean Occupied Spots")
    plt.title("Simulated vs Real Parking Occupancy (5-minute bins)")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()

    return plt

def plot_intervals(df_sim, prediction_interval):
    import matplotlib.pyplot as plt
    import pandas as pd
    import numpy as np

    """
    Generates a combined plot of:
      - Confidence intervals
      - Prediction intervals
    using the intermediate scripts.
    """

    # -----------------------------------------
    # 1) Save simulation df temporarily
    # -----------------------------------------
    temp_in = tempfile.NamedTemporaryFile(delete=False, suffix=".csv")
    df_sim.to_csv(temp_in.name, index=False)

    # Outputs
    temp_conf = tempfile.NamedTemporaryFile(delete=False, suffix=".csv")
    temp_pred = tempfile.NamedTemporaryFile(delete=False, suffix=".csv")

    # -----------------------------------------
    # 2) Run scripts
    # -----------------------------------------
    # confidence intervals
    cmd_conf = [
        "python3", "./scripts/confidence_intervals_per_bin.py",
        "--input-file", temp_in.name,
        "--output-file", temp_conf.name,
        "--bin-size", "5"
    ]

    # prediction intervals
    cmd_pred = [
        "python3", "./scripts/prediction_interval_per_bin.py",
        "--input-file", temp_in.name,
        "--output-file", temp_pred.name,
        "--bin-size", "5",
        "--prediction-interval", str(prediction_interval)
    ]

    subprocess.run(cmd_conf, check=True)
    subprocess.run(cmd_pred, check=True)

    # -----------------------------------------
    # 3) Load outputs
    # -----------------------------------------
    df_conf = pd.read_csv(temp_conf.name)
    df_pred = pd.read_csv(temp_pred.name)

    # -----------------------------------------
    # 4) Prepare plot
    # -----------------------------------------
    fig, ax = plt.subplots(figsize=(14, 6))

    x = df_conf["bin_id"]

    # Confidence interval band
    ax.fill_between(
        x,
        df_conf["lower_confidence_limit"],
        df_conf["upper_confidence_limit"],
        alpha=0.3,
        label="95% Confidence Interval"
    )

    # Prediction interval band
    ax.fill_between(
        x,
        df_pred["p_low"],
        df_pred["p_high"],
        alpha=0.2,
        label=f"{prediction_interval}% Prediction Interval"
    )

    # Mean (from confidence data)
    ax.plot(x, df_conf["mean"], marker='.', linewidth=1, label="Simulated mean")

    # Formatting (hours every 12 bins)
    hour_ticks = np.arange(0, len(x), 12)
    hour_labels = [f"{str(h).zfill(2)}:00" for h in range(24)]

    ax.set_xticks(hour_ticks)
    ax.set_xticklabels(hour_labels, rotation=45)

    ax.set_title("Confidence & Prediction Intervals of Simulated Occupancy")
    ax.set_xlabel("Hour of Day")
    ax.set_ylabel("Occupied Spots")
    ax.grid(True, alpha=0.3)
    ax.legend()

    plt.tight_layout()

    return fig

def plot_probability_full(df_sim, capacity):
    import matplotlib.pyplot as plt
    import subprocess
    import tempfile
    import pandas as pd

    # Save simulation input temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as temp_in:
        df_sim.to_csv(temp_in.name, index=False)

    with tempfile.NamedTemporaryFile(delete=False, suffix=".csv") as temp_prob:
        output_prob = temp_prob.name

    # Run probability-of-full external script
    cmd = [
        "python3", "./scripts/full_spots_probability.py",
        "--input-file", temp_in.name,
        "--output-file", output_prob,
        "--capacity", str(capacity),
        "--bin-size", "5"
    ]

    subprocess.run(cmd, check=True)

    # Load results
    df_prob = pd.read_csv(output_prob)

    df_prob["hour_only"] = df_prob["hour_bin"].str.slice(0, 2) + ":00"

    # Keep only the first row of each hour
    df_hour_ticks = df_prob.groupby("hour_only").first().reset_index()

    # ---- Plot ----
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.plot(df_prob["hour_bin"], df_prob["prob_full_percent"],
            marker='.', linewidth=1.5)

    ax.set_title("Probability of Parking Being FULL (%)")
    ax.set_xlabel("Hour")
    ax.set_ylabel("Probability (%)")
    ax.grid(True)

    # Set only hourly ticks
    ax.set_xticks(df_hour_ticks["hour_bin"])
    ax.set_xticklabels(df_hour_ticks["hour_only"], rotation=45)

    fig.tight_layout()
    return fig, df_prob


def run_simulation(
    input_arrival_file: str,
    input_dwell_file: str,
    bin_size: int,
    num_simulations: int,
    spots: int,
    warm_up_days: int,
    output_file: str,
    percent_arrivals: float,
    percent_dwell: float,
    modify_from=None,
    modify_to=None
):

    cmd = [
        "python3",
        "./scripts/montecarlo_simulation_with_rates_time_range.py",
        "--input-arrival-file", input_arrival_file,
        "--input-dwell-file", input_dwell_file,
        "--bin-size", str(bin_size),
        "--num-simulations", str(num_simulations),
        "--spots", str(spots),
        "--warm-up-days", str(warm_up_days),
        "--output-file", output_file,
        "--percent-arrivals", str(percent_arrivals),
        "--percent-dwell-time", str(percent_dwell)
    ]

    # Only add modify range if provided
    if modify_from:
        cmd += ["--modify-from", modify_from]
    if modify_to:
        cmd += ["--modify-to", modify_to]

    try:
        # Capture output to show script errors inside Streamlit
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False  # Don't raise exception automatically
        )

        if result.returncode != 0:
            raise RuntimeError(
                f"Simulation script failed.\n\n"
                f"Return code: {result.returncode}\n\n"
                f"STDOUT:\n{result.stdout}\n\n"
                f"STDERR:\n{result.stderr}"
            )

        return pd.read_csv(output_file)

    except Exception as e:
        raise RuntimeError(f"Error running simulation:\n\n{str(e)}")
