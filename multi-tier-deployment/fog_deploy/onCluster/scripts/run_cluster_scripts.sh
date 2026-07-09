#!/usr/bin/env bash
# =============================================================================
# Script Name: run_cluster_scripts.sh
# Description: Runs a complete experiment sequence:
#              1. Logs GPU metrics
#              2. Collects cluster logs
#              3. Processes cluster logs
#
# Usage:
#   ./run_cluster_scripts.sh --duration <time> --directory <dir> \
#     --M <value> --N <value> --seed <value> --alpha <value> --beta <value>
#
# Example:
#   ./run_experiment.sh --duration 600 --directory test1 \
#     --M 136 --N 60 --seed 100 --alpha 1 --beta 1
# =============================================================================

set -euo pipefail

# --------------------------- #
#          FUNCTIONS          #
# --------------------------- #
usage() {
  echo "Usage: $0 --duration <time> --directory <dir> --M <value> --N <value> --seed <value> --alpha <value> --beta <value>"
  exit 1
}

# --------------------------- #
#       PARSE ARGUMENTS       #
# --------------------------- #
if [[ $# -lt 14 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --duration) DURATION="$2"; shift 2 ;;
    --directory) DIRECTORY="$2"; shift 2 ;;
    --M) M="$2"; shift 2 ;;
    --N) N="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --alpha) ALPHA="$2"; shift 2 ;;
    --beta) BETA="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; usage ;;
  esac
done

# --------------------------- #
#         MAIN LOGIC          #
# --------------------------- #

RESULTS_DIR="./results/${DIRECTORY}"
mkdir -p "$RESULTS_DIR"

GPU_LOG_FILE="${RESULTS_DIR}/gpu_logs_M_${M}_N_${N}_seed_${SEED}_alpha_${ALPHA}_beta_${BETA}.csv"
CLUSTER_LOG_FILE="${RESULTS_DIR}/cluster_logs_M_${M}_N_${N}_seed_${SEED}_alpha_${ALPHA}_beta_${BETA}.log-cluster"
PROCESSED_LOG_FILE="${RESULTS_DIR}/processed_cluster_logs_M_${M}_N_${N}_seed_${SEED}_alpha_${ALPHA}_beta_${BETA}.csv"

echo " "
echo "🚀 Starting experiment with parameters:"
echo "   Duration : ${DURATION}"
echo "   Directory: ${DIRECTORY}"
echo "   M=${M}, N=${N}, Seed=${SEED}, Alpha=${ALPHA}, Beta=${BETA}"
echo " "
echo "Results will be saved in: ${RESULTS_DIR}"
echo " "

# --------------------------- #
#       RUN SUB-SCRIPTS       #
# --------------------------- #

echo "▶ Running GPU logger..."
./gpu_logger.sh "$GPU_LOG_FILE" --duration "$DURATION"

echo "▶ Collecting cluster logs..."
./collect_cluster_logs.sh --output-file "$CLUSTER_LOG_FILE"

echo "▶ Processing cluster logs..."
./process_cluster_logs.sh \
  --input-file "$CLUSTER_LOG_FILE" \
  --output-file "$PROCESSED_LOG_FILE"

echo " "
echo "✅ Experiment completed successfully."
echo "   Files generated:"
echo "     - $GPU_LOG_FILE"
echo "     - $CLUSTER_LOG_FILE"
echo "     - $PROCESSED_LOG_FILE"
