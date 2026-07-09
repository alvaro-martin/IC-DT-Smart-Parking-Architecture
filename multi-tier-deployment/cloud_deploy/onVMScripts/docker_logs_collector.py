#!/usr/bin/env python3
"""
docker_logs_collector.py
Collect logs from a Docker container into a file.

Usage:
    python3 docker_logs_collector.py --container fiware-iot-agent --out-dir ./results
Stop with Ctrl+C.
"""

import argparse
import os
import subprocess
import signal
from datetime import datetime

# -------------------
# CLI
# -------------------
def parse_args():
    p = argparse.ArgumentParser(description="Collect Docker logs into a file.")
    p.add_argument("--M", type=int, required=True, help="Number of devices (M).")
    p.add_argument("--N", type=int, required=True, help="Number of seconds / bins (N).")
    p.add_argument("--seeds", type=int, required=True, help="Number of cycles (seed count). Uses seeds 1..seeds inclusive.")
    p.add_argument("--alpha", type=float, default=1.0, help="Beta distribution alpha.")
    p.add_argument("--beta", type=float, default=1.0, help="Beta distribution beta.")
    p.add_argument("--container", type=str, default="fiware-iot-agent", help="Container name for docker logs.")
    p.add_argument("--out-dir", type=str, default="./results", help="Directory to write output files.")
    return p.parse_args()

# -------------------
# Main
# -------------------
def main():
    args = parse_args()

    M = args.M
    N = args.N
    seed_count = args.seeds
    alpha = args.alpha
    beta_param = args.beta
    container = args.container
    out_dir = os.path.abspath(args.out_dir)
    os.makedirs(out_dir, exist_ok=True)

    # Build filenames
    suffix = (
        f"_M_{M}_N_{N}_seed_{seed_count}"
        f"_alpha_{int(alpha) if alpha.is_integer() else alpha}"
        f"_beta_{int(beta_param) if beta_param.is_integer() else beta_param}"
    )
    log_file = os.path.join(out_dir, f"raw_docker_logs_{container}{suffix}.log")

    # Capture program start timestamp
    start_ts = datetime.utcnow().isoformat() + "Z"

    # Start docker logs collection
    print(f"▶ Starting Docker logs since {start_ts} into: {log_file}")
    print(f"▶ Writing to: {log_file}")
    print("⏹ Stop with Ctrl+C")
    log_fh = open(log_file, "w")
    log_cmd = ["docker", "logs", "-f", "--since", start_ts, container]
    with open(log_file, "w") as log_fh:
        proc = subprocess.Popen(log_cmd, stdout=log_fh, stderr=subprocess.STDOUT)

        try:
            proc.wait()
        except KeyboardInterrupt:
            print("\n⚠ Interrupted, stopping log collection…")
            proc.send_signal(signal.SIGINT)
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
        finally:
            print(f"🛑 Logs saved → {log_file}")



if __name__ == "__main__":
    main()

