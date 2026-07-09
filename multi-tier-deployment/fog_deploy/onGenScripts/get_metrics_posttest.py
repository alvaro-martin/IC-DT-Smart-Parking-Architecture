#!/usr/bin/env python3
"""
get_metrics_posttest.py

Post-test Prometheus collector:
  - looks for response_times_M_*.csv files in --out-dir (default ./results)
  - for each file: compute start = first_timestamp - 10s, end = last_timestamp + 10s
  - fetch metrics with query_range(step=1s) for that window (splits the window
    into chunks if needed so each timeseries has <= max_points samples)
  - write metrics_{M_...}.csv into out-dir

Usage example:
  python3 get_metrics_posttest.py --out-dir ./results --prom-url http://localhost:9090 --step 1s
"""
import argparse
import requests
import csv
import os
import glob
import re
import math
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed

# Default containers (same as your original list)
DEFAULT_CONTAINERS = [
    "nginx-reverse-proxy",
    "fiware-orion",
    "fiware-iot-agent",
    "fiware-ld-context",
    "db-mongo",
    "cadvisor",
    "node-exporter",
    "prometheus-monitor"
]


def parse_args():
    p = argparse.ArgumentParser(description="Post-test Prometheus metrics collector (query_range).")
    # keep your previous flags for compatibility but make them optional
    p.add_argument("--M", type=int, required=False, help="Number of devices (M) — not required for post-test mode.")
    p.add_argument("--N", type=int, required=False, help="N — not required for post-test mode.")
    p.add_argument("--seeds", type=int, required=False, help="seeds — not required for post-test mode.")
    p.add_argument("--TR", type=int, required=False, help="TR — not required for post-test mode.")
    p.add_argument("--alpha", type=float, required=False, help="alpha — not required for post-test mode.")
    p.add_argument("--beta", type=float, required=False, help="beta — not required for post-test mode.")
    p.add_argument("--out-dir", type=str, default="./results", help="Directory containing response_times_*.csv and where metrics will be saved.")
    p.add_argument("--prom-url", type=str, default="http://localhost:9090", help="Prometheus base URL.")
    p.add_argument("--interval", type=str, default="15s", help="PromQL interval for metric templates (kept for compatibility).")
    p.add_argument("--containers", type=str, default=None, help="Comma-separated container names to monitor (overrides the default list).")
    p.add_argument("--max-workers", type=int, default=16, help="Max parallel queries per file (default 16).")
    p.add_argument("--step", type=str, default="1s", help="Query resolution step for query_range (e.g. 1s, 5s). Default '1s'.")
    p.add_argument("--max-points", type=int, default=11000, help="Prometheus max points per timeseries (default 11000).")
    return p.parse_args()


def extract_key_from_filename(fname):
    """
    Extract the key part M_x_N_x_seed_x_TR_x_alpha_x_beta_x from filename
    Returns None if not present.
    """
    m = re.search(r"(M_\d+_N_\d+_seed_\d+_TR_\d+_alpha_[\d.]+_beta_[\d.]+)", fname)
    return m.group(1) if m else None


def detect_node_instance_and_job(prom_url, session, timeout=10.0):
    resp = session.get(f"{prom_url}/api/v1/series", params={"match[]": "node_load1"}, timeout=timeout)
    resp.raise_for_status()
    data = resp.json()["data"]
    if not data:
        raise RuntimeError("No node_load1 metrics found in Prometheus.")
    first = data[0]
    return first["instance"], first["job"]


def detect_cadvisor_instance(prom_url, session, timeout=10.0):
    resp = session.get(f"{prom_url}/api/v1/series", params={"match[]": "container_fs_writes_merged_total"}, timeout=timeout)
    resp.raise_for_status()
    data = resp.json()["data"]
    if not data:
        raise RuntimeError("No container_fs_writes_merged_total metrics found in Prometheus.")
    cadvisor_instance = data[0]["instance"]
    print(f"Detected cAdvisor instance: {cadvisor_instance}")
    return cadvisor_instance


def query_prometheus_range(session, prom_url, promql, start_ts, end_ts, step="1s", timeout=60.0):
    """
    Query Prometheus /api/v1/query_range and return a mapping: {int(second_ts): value}
    Values are floats; missing values -> not present in map.
    start_ts and end_ts are float seconds since epoch.
    """
    params = {
        "query": promql,
        "start": str(start_ts),
        "end": str(end_ts),
        "step": step
    }
    try:
        resp = session.get(f"{prom_url}/api/v1/query_range", params=params, timeout=timeout)
        resp.raise_for_status()
        data = resp.json()["data"]
        results = data.get("result", [])
        if not results:
            return {}  # no series
        # pick the first timeseries (most of your queries should return single series)
        vals = results[0].get("values", [])
        mapping = {}
        for ts_str, v_str in vals:
            # ts_str is a float second string (e.g. "162..."), convert to int seconds
            try:
                ts = int(float(ts_str))
                # try convert value to float; if "NaN" or others, keep None
                try:
                    v = float(v_str)
                except Exception:
                    v = None
                mapping[ts] = v
            except Exception:
                continue
        return mapping
    except Exception as e:
        # on any error return empty mapping (caller will fill with N/A)
        # but log briefly
        print(f"Warning: query_range failed for promql='{promql[:120]}...' error: {e}")
        return {}


def build_metrics(instance, job, cadvisor_instance, interval, containers):
    INTERVAL = interval

    metrics = {
        "network_rx_eth0_Bps": f"rate(node_network_receive_bytes_total{{instance='{instance}',job='{job}',device='eth0'}}[{INTERVAL}])*8",
        "network_tx_eth0_Bps": f"rate(node_network_transmit_bytes_total{{instance='{instance}',job='{job}',device='eth0'}}[{INTERVAL}])*8",
        "network_rx_eth0_percent": f"(rate(node_network_receive_bytes_total{{instance='{instance}',job='{job}',device='eth0'}}[{INTERVAL}]) / ignoring(speed) node_network_speed_bytes{{instance='{instance}',job='{job}', speed!=\"-1\"}}) * 100",
        "network_tx_eth0_percent": f"(rate(node_network_transmit_bytes_total{{instance='{instance}',job='{job}',device='eth0'}}[{INTERVAL}]) / ignoring(speed) node_network_speed_bytes{{instance='{instance}',job='{job}', speed!=\"-1\"}}) * 100",
        "disk_vda_reads_iops": f"irate(node_disk_reads_completed_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_reads_iops": f"irate(node_disk_reads_completed_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_writes_iops": f"irate(node_disk_writes_completed_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_writes_iops": f"irate(node_disk_writes_completed_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_read_bytes_kBps": f"irate(node_disk_read_bytes_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}]) / 1024",
        "disk_vdb_read_bytes_kBps": f"irate(node_disk_read_bytes_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}]) / 1024",
        "disk_vda_write_bytes_kBps": f"irate(node_disk_written_bytes_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}]) / 1024",
        "disk_vdb_write_bytes_kBps": f"irate(node_disk_written_bytes_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}]) / 1024",
        "disk_vda_io_utilization_percent": f"irate(node_disk_io_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}]) * 100",
        "disk_vdb_io_utilization_percent": f"irate(node_disk_io_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}]) * 100",
        "disk_io_pressure_psi_percent": f"irate(node_pressure_io_waiting_seconds_total{{instance='{instance}',job='{job}'}}[{INTERVAL}]) * 100",
        "disk_vda_wait_time_read_ms": f"(irate(node_disk_read_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}]) / irate(node_disk_reads_completed_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])) * 1000",
        "disk_vdb_wait_time_read_ms": f"(irate(node_disk_read_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}]) / irate(node_disk_reads_completed_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])) * 1000",
        "disk_vda_wait_time_write_ms": f"(irate(node_disk_write_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}]) / irate(node_disk_writes_completed_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])) * 1000",
        "disk_vdb_wait_time_write_ms": f"(irate(node_disk_write_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}]) / irate(node_disk_writes_completed_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])) * 1000",
        "disk_vda_queue_size": f"irate(node_disk_io_time_weighted_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_queue_size": f"irate(node_disk_io_time_weighted_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_reads_merged_iops": f"irate(node_disk_reads_merged_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_reads_merged_iops": f"irate(node_disk_reads_merged_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_writes_merged_iops": f"irate(node_disk_writes_merged_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_writes_merged_iops": f"irate(node_disk_writes_merged_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_time_general_io_percent": f"irate(node_disk_io_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_time_general_io_percent": f"irate(node_disk_io_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_time_TRIM_percent": f"irate(node_disk_discard_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_time_TRIM_percent": f"irate(node_disk_discard_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "disk_vda_time_flush_percent": f"irate(node_disk_flush_requests_time_seconds_total{{instance='{instance}',job='{job}',device=~'vda'}}[{INTERVAL}])",
        "disk_vdb_time_flush_percent": f"irate(node_disk_flush_requests_time_seconds_total{{instance='{instance}',job='{job}',device=~'vdb'}}[{INTERVAL}])",
        "cpu_sys_load_percent": f"scalar(node_load1{{instance='{instance}',job='{job}'}}) * 100 / count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu))",
        "cpu_pressure_psi_percent": f"irate(node_pressure_cpu_waiting_seconds_total{{instance='{instance}',job='{job}'}}[{INTERVAL}])*100",
        "cpu_time_busy_system_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode='system'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_busy_user_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode='user'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_busy_iowait_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode='iowait'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_busy_irqs_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode=~'.*irq'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_busy_other_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode!='idle',mode!='user',mode!='system',mode!='iowait',mode!='irq',mode!='softirq'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_idle_percent": f"sum(irate(node_cpu_seconds_total{{instance='{instance}',job='{job}', mode='idle'}}[{INTERVAL}])) / scalar(count(count(node_cpu_seconds_total{{instance='{instance}',job='{job}'}}) by (cpu)))*100",
        "cpu_time_busy_percent": f"100 * (1 - avg(rate(node_cpu_seconds_total{{mode='idle', instance='{instance}'}}[{INTERVAL}])))",
        "memory_ram_used_percent": f"(1 - (node_memory_MemAvailable_bytes{{instance='{instance}', job='{job}'}} / node_memory_MemTotal_bytes{{instance='{instance}', job='{job}'}})) * 100",
        "memory_swap_used_percent": f"((node_memory_SwapTotal_bytes{{instance='{instance}',job='{job}'}} - node_memory_SwapFree_bytes{{instance='{instance}',job='{job}'}}) / (node_memory_SwapTotal_bytes{{instance='{instance}',job='{job}'}})) * 100",
        "memory_ram_used_GiB": f"(node_memory_MemTotal_bytes{{instance='{instance}',job='{job}'}} - node_memory_MemFree_bytes{{instance='{instance}',job='{job}'}} - (node_memory_Cached_bytes{{instance='{instance}',job='{job}'}} + node_memory_Buffers_bytes{{instance='{instance}',job='{job}'}} + node_memory_SReclaimable_bytes{{instance='{instance}',job='{job}'}})) / (1024*1024*1024)",
        "memory_cache_buffer_used_GiB": f"(node_memory_Cached_bytes{{instance='{instance}',job='{job}'}} + node_memory_Buffers_bytes{{instance='{instance}',job='{job}'}} + node_memory_SReclaimable_bytes{{instance='{instance}',job='{job}'}}) / (1024*1024*1024)",
        "memory_free_GiB": f"node_memory_MemFree_bytes{{instance='{instance}',job='{job}'}} / (1024*1024*1024)",
        "memory_swap_used_GiB": f"(node_memory_SwapTotal_bytes{{instance='{instance}',job='{job}'}} - node_memory_SwapFree_bytes{{instance='{instance}',job='{job}'}}) / (1024*1024*1024)",
        "memory_pressure_psi_percent": f"irate(node_pressure_memory_waiting_seconds_total{{instance='{instance}',job='{job}'}}[{INTERVAL}])*100",
    }

    cadvisor_templates = {
        "container_cpu_system_ms":
            "max by (name) (rate(container_cpu_system_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))*1000",
        "container_cpu_user_ms":
            "max by (name) (rate(container_cpu_user_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))*1000",
        "container_cpu_usage_ms":
            "max by (name) (rate(container_cpu_usage_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))*1000",
        "container_memory_failures_total":
            "max by (name) (rate(container_memory_failures_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_memory_max_usage_bytes":
            "max by (name) (container_memory_max_usage_bytes{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_memory_usage_bytes":
            "max by (name) (container_memory_usage_bytes{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_memory_cache_bytes":
            "max by (name) (container_memory_cache{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_memory_swap_bytes":
            "max by (name) (container_memory_swap{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_network_receive_bytes_total_bytes":
            "max by (name) (rate(container_network_receive_bytes_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_transmit_bytes_total_bytes":
            "max by (name) (rate(container_network_transmit_bytes_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_receive_errors_total":
            "max by (name) (rate(container_network_receive_errors_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_transmit_errors_total":
            "max by (name) (rate(container_network_transmit_errors_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_receive_packets_total":
            "max by (name) (rate(container_network_receive_packets_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_transmit_packets_total":
            "max by (name) (rate(container_network_transmit_packets_dropped_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_receive_packets_dropped_total":
            "max by (name) (rate(container_network_receive_packets_dropped_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_network_transmit_packets_dropped_total":
            "max by (name) (rate(container_network_transmit_packets_dropped_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_blkio_device_usage_total_bytes":
            "max by (name) (rate(container_blkio_device_usage_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_inodes_free":
            "max by (name) (container_fs_inodes_free{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_fs_inodes_total":
            "max by (name) (container_fs_inodes_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_fs_io_current":
            "max by (name) (container_fs_io_current{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}})",
        "container_fs_usage_bytes":
            "max by (name) (rate(container_fs_usage_bytes{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_io_s":
            "max by (name) (rate(container_fs_io_time_weighted_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_read_seconds_s":
            "max by (name) (rate(container_fs_read_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_write_seconds_s":
            "max by (name) (-rate(container_fs_write_seconds_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_reads_total":
            "max by (name) (rate(container_fs_reads_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_writes_total":
            "max by (name) (rate(container_fs_writes_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_reads_merged_total":
            "max by (name) (rate(container_fs_reads_merged_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
        "container_fs_writes_merged_total":
            "max by (name) (rate(container_fs_writes_merged_total{{instance='{cadvisor_instance}', name='{container}', container_label_com_docker_compose_project=~'.*'}}[{interval}]))",
    }


    for c in containers:
        for base_name, template in cadvisor_templates.items():
            column_name = f"{base_name}_{c}"
            promql = template.format(cadvisor_instance=cadvisor_instance, container=c, interval=INTERVAL)
            metrics[column_name] = promql

    return metrics


def parse_iso_z(ts_str):
    """
    Parse an ISO timestamp possibly ending with 'Z' into a timezone-aware UTC datetime.
    Example: '2025-08-25T19:51:56.320721Z'
    """
    if ts_str.endswith("Z"):
        ts_str = ts_str[:-1] + "+00:00"
    return datetime.fromisoformat(ts_str)


def collect_time_window_from_response_file(response_file):
    """
    Parse response CSV and return (start_dt, end_dt) as datetimes based on first/last Timestamp
    """
    timestamps = []
    with open(response_file, newline="") as f:
        rdr = csv.DictReader(f)
        if "Timestamp" not in rdr.fieldnames:
            raise RuntimeError(f"Response file {response_file} has no 'Timestamp' column")
        for row in rdr:
            ts = row.get("Timestamp")
            if not ts:
                continue
            try:
                dt = parse_iso_z(ts)
                timestamps.append(dt)
            except Exception:
                continue
    if not timestamps:
        raise RuntimeError(f"No timestamps found in {response_file}")
    first = min(timestamps)
    last = max(timestamps)
    return first - timedelta(seconds=10), last + timedelta(seconds=10)


def parse_step_to_seconds(step_str):
    """
    Parse step strings like '1s', '5s', '1m', '2h' into seconds (int).
    """
    m = re.match(r"^(\d+)([smhd])$", step_str)
    if not m:
        # fallback: try to parse as integer seconds
        try:
            return int(step_str)
        except Exception:
            raise ValueError(f"Invalid step format: {step_str}. Use Ns/Nm/Nh (e.g. 1s, 5s, 1m).")
    val = int(m.group(1))
    unit = m.group(2)
    if unit == "s":
        return val
    if unit == "m":
        return val * 60
    if unit == "h":
        return val * 3600
    if unit == "d":
        return val * 86400
    raise ValueError(f"Unsupported step unit in {step_str}")


def split_into_chunks(start_epoch, end_epoch, max_chunk_seconds):
    """
    Yield (chunk_start, chunk_end) pairs inclusive that cover [start_epoch, end_epoch]
    with each chunk length <= max_chunk_seconds.
    """
    cur = start_epoch
    while cur <= end_epoch:
        chunk_end = min(cur + max_chunk_seconds - 1, end_epoch)
        yield cur, chunk_end
        cur = chunk_end + 1


def main():
    args = parse_args()

    out_dir = os.path.abspath(args.out_dir)
    prom_url = args.prom_url.rstrip("/")
    interval = args.interval

    if args.containers:
        containers = [c.strip() for c in args.containers.split(",") if c.strip()]
    else:
        containers = DEFAULT_CONTAINERS

    # parse step seconds and compute chunk sizes
    step_seconds = parse_step_to_seconds(args.step)
    max_points = int(args.max_points)
    if max_points <= 0:
        raise RuntimeError("max-points must be > 0")
    # be conservative: allow up to (max_points - 1) intervals
    max_chunk_seconds = max(1, step_seconds * (max_points - 1))

    # find response files
    pattern = os.path.join(out_dir, "response_times_M_*.csv")
    response_files = sorted(glob.glob(pattern))
    if not response_files:
        print(f"No response_times files found in {out_dir} matching pattern 'response_times_M_*.csv'")
        return

    # create single session for keep-alive
    session = requests.Session()
    session.headers.update({"Accept": "application/json"})

    # detect instances once
    print(f"Detecting Prometheus instances from {prom_url} ...")
    instance, job = detect_node_instance_and_job(prom_url, session)
    cadvisor_instance = detect_cadvisor_instance(prom_url, session)
    print(f"Detected Node Exporter instance: {instance}, job: {job}")

    # build metrics once
    metrics = build_metrics(instance, job, cadvisor_instance, interval, containers)
    metric_items = list(metrics.items())

    for resp_file in response_files:
        print(f"\nProcessing response file: {resp_file}")
        try:
            start_dt, end_dt = collect_time_window_from_response_file(resp_file)
        except Exception as e:
            print(f"  Skipping {resp_file}: failed to parse timestamps: {e}")
            continue

        print(f"  Window: {start_dt.isoformat()} -> {end_dt.isoformat()} (inclusive)")

        # create list of integer second timestamps from start to end inclusive
        start_epoch = int(start_dt.timestamp())
        end_epoch = int(end_dt.timestamp())
        seconds = list(range(start_epoch, end_epoch + 1))

        # prepare output filename using key extracted from response filename
        key = extract_key_from_filename(os.path.basename(resp_file))
        if key:
            out_fname = os.path.join(out_dir, f"metrics_{key}.csv")
        else:
            # fallback to using response filename prefix
            base = os.path.splitext(os.path.basename(resp_file))[0]
            out_fname = os.path.join(out_dir, f"metrics_{base}.csv")

        print(f"  Will write metrics to: {out_fname}")
        # for each metric perform query_range in parallel but split the window into chunks
        metric_mappings = {}  # name -> {ts_int: value}
        max_workers = min(args.max_workers, max(1, len(metric_items)))
        print(f"  Querying {len(metric_items)} metrics (step={args.step}) with up to {max_workers} parallel workers ...")
        print(f"  Prometheus max_points={max_points}, step_seconds={step_seconds}, chunk_seconds={max_chunk_seconds}")

        # build list of tasks (metric, promql, chunk_start, chunk_end)
        tasks = []
        for name, promql in metric_items:
            # split the metric window into chunks
            for cs, ce in split_into_chunks(start_epoch, end_epoch, max_chunk_seconds):
                tasks.append((name, promql, float(cs), float(ce)))

        # submit tasks in threadpool and merge results per metric
        with ThreadPoolExecutor(max_workers=max_workers) as ex:
            future_to_task = {
                ex.submit(query_prometheus_range, session, prom_url, promql, chunk_start, chunk_end, args.step): (name, chunk_start, chunk_end)
                for (name, promql, chunk_start, chunk_end) in tasks
            }

            for fut in as_completed(future_to_task):
                name, cs, ce = future_to_task[fut]
                try:
                    mapping = fut.result()
                except Exception as e:
                    print(f"    Metric {name} chunk {int(cs)}-{int(ce)}: query failed: {e}")
                    mapping = {}
                # initialize dict if not present
                if name not in metric_mappings:
                    metric_mappings[name] = {}
                # merge mapping (later chunks may add further timestamps)
                metric_mappings[name].update(mapping)

        # Now write CSV rows for every second within window
        os.makedirs(out_dir, exist_ok=True)
        with open(out_fname, "w", newline="") as outf:
            writer = csv.writer(outf)
            header = ["timestamp"] + [name for name, _ in metric_items]
            writer.writerow(header)
            for sec in seconds:
                ts_iso = datetime.utcfromtimestamp(sec).isoformat() + "Z"
                row = [ts_iso]
                for name, _ in metric_items:
                    m = metric_mappings.get(name, {})
                    v = m.get(sec)
                    if v is None:
                        row.append("N/A")
                    else:
                        row.append(v)
                writer.writerow(row)

        print(f"  Wrote {out_fname} ({len(seconds)} rows)")

    print("\nAll response files processed.")


if __name__ == "__main__":
    main()

