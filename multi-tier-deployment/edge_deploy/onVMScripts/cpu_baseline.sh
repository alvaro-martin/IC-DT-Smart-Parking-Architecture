#!/bin/bash
set -euo pipefail
OUTDIR=${1:-./baseline_results}
mkdir -p "$OUTDIR"
ts=$(date -u +"%Y%m%dT%H%M%SZ")
hostfile="$OUTDIR/host_${ts}.txt"

# 1) capture lscpu and cpuinfo
lscpu > "${hostfile}.lscpu"
grep -m1 'model name' /proc/cpuinfo > "${hostfile}.model"
cp /proc/cpuinfo "${hostfile}.cpuinfo"

# 2) small microbenchmarks
# sysbench integer (single-thread)
if ! command -v sysbench >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y sysbench
fi
sysbench cpu --threads=1 --time=10 run > "${hostfile}.sysbench_s1" 2>&1

# sysbench integer (all threads)
NPROC=$(nproc)
sysbench cpu --threads=${NPROC} --time=10 run > "${hostfile}.sysbench_mt" 2>&1

# openssl quick crypto test (short)
if command -v openssl >/dev/null 2>&1; then
  openssl speed -multi 1 aes-128-cbc > "${hostfile}.openssl" 2>&1 || true
fi

# 3) measure steal and cpu MHz for a short window
if ! command -v mpstat >/dev/null 2>&1; then
  sudo apt-get install -y sysstat
fi
mpstat -P ALL 1 3 > "${hostfile}.mpstat" 2>&1 &

# capture cpu MHz once (before running experiment)
grep "cpu MHz" /proc/cpuinfo | head -n 4 > "${hostfile}.cpumhz_before"

# small python FP microbenchmark
python3 - <<'PY' > "${hostfile}.pybench" 2>&1
import time, math
t0 = time.time()
for i in range(2000000):
    math.sqrt(i)
print("python_sqrt_2M:", time.time()-t0)
PY

# 4) pack a small metadata summary to stdout for ingest
echo "BASELINE_SUMMARY ${ts}"
echo "HOSTFILE=${hostfile}"
echo "MODEL=$(sed -n '1p' ${hostfile}.model | sed 's/model name:[[:space:]]*//')"
# extract sysbench events/sec single-thread
grep "events per second" "${hostfile}.sysbench_s1" | sed -n '1p'
# extract sysbench events/sec multi-thread
grep "events per second" "${hostfile}.sysbench_mt" | sed -n '1p'
# python bench
grep python_sqrt_2M: "${hostfile}.pybench"
# %steal
awk '/all/ && NF>6 {print "%steal="$NF; exit}' "${hostfile}.mpstat" || true

echo "FILES:"
ls -1 "${hostfile}".*
