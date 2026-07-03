#!/usr/bin/env bash
# mist_deploy_runner.sh
# Usage: ./mist_deploy_runner.sh [config_file]

set -euo pipefail
IFS=$'\n\t'

CONFIG_FILE="${1:-mist_deploy.conf}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file '$CONFIG_FILE' not found. Create it or pass a different path."
  exit 1
fi

# Allow only simple assignment lines and comments to be sourced
TMP_CONFIG="$(mktemp)"
# grab lines that look like KEY=VALUE (ignore other lines)
grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$CONFIG_FILE" > "$TMP_CONFIG" || true
# shellcheck disable=SC1090
source "$TMP_CONFIG"
rm -f "$TMP_CONFIG"

# Validate required variables
required_vars=(M N seed alpha beta VM_tailscale_domain_name VM_tailscale_IPv4 VM_username VM_password VM_dir LM_dir onVM_dir onGen_dir onInfra_dir)
for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: Required variable '$v' is not set in $CONFIG_FILE"
    exit 1
  fi
done

# Build directory name and logfile path
DIRNAME="mist_deploy_test_M_${M}_N_${N}_seed_${seed}_alpha_${alpha}_beta_${beta}"
mkdir -p "${LM_dir}/${onGen_dir}/$DIRNAME"

LOGFILE="${LM_dir}/${onGen_dir}/${DIRNAME}/${DIRNAME}.log"

# Redirect all stdout+stderr to logfile *and* keep showing it on terminal
exec > >(tee -a "$LOGFILE") 2>&1

echo "Starting laptop-side logging into $LOGFILE"

# From this point, ALL commands and outputs are logged
# ----------------------------------------------------

# ---------------- VM SIDE ---------------- 
echo "▶ Connecting to VM 
${VM_tailscale_domain_name} (${VM_tailscale_IPv4}) as ${VM_username}..." 
sshpass -p "$VM_password" ssh -o StrictHostKeyChecking=no ${VM_username}@${VM_tailscale_IPv4} <<VM_EOF

set -euo pipefail
IFS=\$'\n\t'

# inject local variables into remote environment
DIRNAME="$DIRNAME"
M="$M"
N="$N"
seed="$seed"
alpha="$alpha"
beta="$beta"
VM_dir="$VM_dir"
onVM_dir="$onVM_dir"
onInfra_dir="$onInfra_dir"

VM_LOGFILE="\$VM_dir/\$onVM_dir/\$DIRNAME/VM_\$DIRNAME.log"

mkdir -p "\$(dirname "\$VM_LOGFILE")"

echo "▶ VM-side log: \$VM_LOGFILE"

echo " "
echo "▶ Starting container on VM..."
docker compose -f "\$VM_dir/\$onInfra_dir/compose.yaml" up -d

echo " "
echo "Waiting 30s for services to stabilize..."
sleep 30

echo " "
echo "Waiting for healthy signals of containers..."
"\$VM_dir/\$onVM_dir/0_healthy_waiting.sh"

echo " "
echo "Creating IoT Agent indices in MongoDB..."
"\$VM_dir/\$onVM_dir/1_create_IoT_Agent_indices_MongoDB.sh"

echo " "
echo "Creating Service Group for devices..."
"\$VM_dir/\$onVM_dir/2_create_service_group.sh"

echo " "
echo "Provisioning IoT devices through the IoT Agent JSON..."
"\$VM_dir/\$onVM_dir/3_provision_devices.sh" "\$M"

echo " "
echo "Verifying the provisioned IoT devices..."
"\$VM_dir/\$onVM_dir/4_verify_provisioned_devices.sh" "\$M"

# Run logs collector in background, non-blocking
nohup "\$VM_dir/\$onVM_dir/docker_logs_collector.py" \
  --M "\$M" --N "\$N" --seeds "\$seed" --alpha "\$alpha" --beta "\$beta" \
  --out-dir "\$VM_dir/\$onVM_dir/\$DIRNAME" \
  > "\$VM_LOGFILE.collector" 2>&1 &

VM_EOF

# ---------------- END VM SIDE ----------------

# Back on laptop
echo "Activating Python virtual environment..."
source "${LM_dir}/${onGen_dir}/venv/bin/activate"

echo "Running load generator..."
"${LM_dir}/${onGen_dir}/load_generator.py" --M "$M" --N "$N" --seeds "$seed" --alpha "$alpha" --beta "$beta" --out-dir "${LM_dir}/${onGen_dir}/${DIRNAME}" --url "${VM_tailscale_domain_name}:7896/iot/json" --key 12345 --max-workers 100 --timeout 60

echo "Collecting posttest metrics..."
"${LM_dir}/${onGen_dir}/get_metrics_posttest.py" --out-dir "${LM_dir}/${onGen_dir}/${DIRNAME}" --prom-url "${VM_tailscale_domain_name}:9090"

echo "▶ Processing IoT Agent logs on VM..."
sshpass -p "${VM_password}" ssh -o StrictHostKeyChecking=no ${VM_username}@${VM_tailscale_IPv4} <<VM_EOF
set -euo pipefail
IFS=\$'\n\t'

DIRNAME="$DIRNAME"
VM_dir="$VM_dir"
onVM_dir="$onVM_dir"

"\$VM_dir/\$onVM_dir/7_process_iot_agent_logs.sh" \
  --out-dir "\$VM_dir/\$onVM_dir/\$DIRNAME"

VM_EOF

echo "▶ Copying VM logs back to laptop..."
sshpass -p "${VM_password}" scp -o StrictHostKeyChecking=no ${VM_username}@${VM_tailscale_IPv4}:"${VM_dir}/${onVM_dir}/${DIRNAME}/*" "${LM_dir}/${onGen_dir}/${DIRNAME}/"


echo "'script' finished. Log saved at: $LOGFILE"
