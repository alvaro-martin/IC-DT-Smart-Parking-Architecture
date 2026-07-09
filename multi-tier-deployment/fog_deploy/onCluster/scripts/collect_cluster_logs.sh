#!/usr/bin/env bash
# =============================================================================
# Script Name: collect_cluster_logs.sh
# Description: Collects logs from the FastAPI ML container in the cluster and
#              saves them to a specified file (default: ./results/cluster_logs.log-cluster).
# Usage: ./collect_cluster_logs.sh [--output-file <output>]
# =============================================================================

set -euo pipefail

# --------------------------- #
#          FUNCTIONS          #
# --------------------------- #

usage() {
  cat <<EOF
Usage: $0 [--output-file <output>]

Options:
  --output-file <output>    File path where logs will be saved.
                            Default: ./results/cluster_logs.log-cluster
  -h, --help                Show this help message and exit.

Examples:
  ./collect_cluster_logs.sh
  ./collect_cluster_logs.sh --output-file ./results/test_run.log
EOF
  exit 1
}

# --------------------------- #
#        ARG PARSING          #
# --------------------------- #

output_file="./results/cluster_logs.log-cluster"

while [[ $# -gt 0 ]]; do
  case "$1" in
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
#           MAIN              #
# --------------------------- #

echo
echo "============================================"
echo "📦  Collecting and Processing Cluster Logs"
echo "============================================"
echo

# Ensure output directory exists
mkdir -p "$(dirname "$output_file")"

# Find container by name
echo "▶ Searching for target container..."
container_name=$(docker ps -a --format '{{.Names}}' | grep 'fastapi-ml_container' || true)

if [[ -n "$container_name" ]]; then
  echo "▶ Found container: $container_name"
  echo "▶ Collecting logs into $output_file ..."

  if docker logs "$container_name" > "$output_file" 2>&1; then
    sync
    sleep 1
    echo "✅ Logs successfully saved at $output_file"
  else
    echo "⚠️  Failed to retrieve logs from $container_name" >&2
  fi

else
  echo "⚠️  No container matching 'fastapi-ml_container' found. Skipping logs."
  exit 0
fi

echo
echo "🎯 Log collection complete."
echo "============================================"
exit 0