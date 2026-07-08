#!/usr/bin/env bash
# edge_deploy_runner.sh
# Usage: ./edge_deploy_runner.sh [config_file]

set -euo pipefail
IFS=$'\n\t'

CONFIG_FILE="${1:-edge_deploy.conf}"

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
required_vars=(M N seed alpha beta VM_tailscale_domain_name VM_tailscale_IPv4 Jetson_tailscale_domain_name Jetson_tailscale_IPv4 VM_username VM_password Jetson_username Jetson_password VM_dir Jetson_dir LM_dir onVM_dir onJetson_dir onGen_dir onInfra_dir)
for v in "${required_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: Required variable '$v' is not set in $CONFIG_FILE"
    exit 1
  fi
done

# Build directory name and logfile path
DIRNAME="edge_deploy_test_M_${M}_N_${N}_seed_${seed}_alpha_${alpha}_beta_${beta}"
mkdir -p "${LM_dir}/${onGen_dir}/$DIRNAME"

LOGFILE="${LM_dir}/${onGen_dir}/${DIRNAME}/${DIRNAME}.log"

# Redirect all stdout+stderr to logfile *and* keep showing it on terminal
exec > >(tee -a "$LOGFILE") 2>&1

echo " "
echo "Starting Gen-side logging into $LOGFILE"

# -----------------JETSON SIDE-------------
echo " "
echo "▶ Connecting to Jetson Nano 
${Jetson_tailscale_domain_name} (${Jetson_tailscale_IPv4}) as ${Jetson_username}..." 
sshpass -p "$Jetson_password" ssh -o StrictHostKeyChecking=no ${Jetson_username}@${Jetson_tailscale_IPv4} bash -s <<JETSON_EOF

set -euo pipefail
IFS=\$'\n\t'

# inject local variables into remote environment
DIRNAME="$DIRNAME"
Jetson_dir="$Jetson_dir" #/home/almartin/Desktop
onJetson_dir="$onJetson_dir" #/ic-unicamp/edge_deploy/onJetson
M="$M"
N="$N"
seed="$seed"
alpha="$alpha"
beta="$beta"

echo "▶ Cleaning old container and logs..."
docker-compose -f "$Jetson_dir/$onJetson_dir/compose.yml" down --remove-orphans
docker system prune -f --volumes

echo "▶ Starting container on Jetson..."
docker-compose -f "\$Jetson_dir/\$onJetson_dir/compose.yml" up -d

echo " "
echo "Waiting 30s for services to stabilize..."
sleep 30

mkdir -p "\$Jetson_dir/\$onJetson_dir/\$DIRNAME"

echo " "
echo "Starting collecting Jetson tegrastats logs..."
nohup "\$Jetson_dir/\$onJetson_dir/scripts/log_tegrastats.sh" \
  --output-file "\$Jetson_dir/\$onJetson_dir/\$DIRNAME/raw_logs_jetson_tegrastats_M\${M}_N\${N}_seeds\${seed}_alpha\${alpha}_beta\${beta}.log-jetson-tegrastats" \
  > "\$Jetson_dir/\$onJetson_dir/\$DIRNAME/tegrastats_stdout.log" 2>&1 &
echo "🚀 tegrastats logging started in background (PID \$!)"


JETSON_EOF
# -----------------JETSON SIDE------------


# ---------------- VM SIDE ---------------- 
echo " "
echo "▶ Connecting to VM 
${VM_tailscale_domain_name} (${VM_tailscale_IPv4}) as ${VM_username}..." 
sshpass -p "$VM_password" ssh -o StrictHostKeyChecking=no ${VM_username}@${VM_tailscale_IPv4} bash -s <<VM_EOF

set -euo pipefail
IFS=\$'\n\t'

# inject local variables into remote environment
DIRNAME="$DIRNAME"
VM_dir="$VM_dir"
onVM_dir="$onVM_dir"
onInfra_dir="$onInfra_dir"
M="$M"

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

VM_EOF

# ---------------- END VM SIDE ----------------

# ---------------- LOAD GENERATOR SIDE---------------
echo " "
echo "Creating Python virtual environment..."
python3 -m venv "${LM_dir}/${onGen_dir}/venv"

# Back on laptop
echo " "
echo "Activating Python virtual environment..."
source "${LM_dir}/${onGen_dir}/venv/bin/activate"

echo " "
echo "Installing python packages..."
pip install -r ${LM_dir}/${onGen_dir}/requirements.txt

echo " "
echo "Running load generator..."
"${LM_dir}/${onGen_dir}/load_generator.py" \
  --M "$M" --N "$N" --seeds "$seed" --alpha "$alpha" --beta "$beta" \
  --image ./test.jpg \
  --out-dir "${LM_dir}/${onGen_dir}/${DIRNAME}" \
  --url "${Jetson_tailscale_domain_name}:8000/predict" \
  --max-workers 100 --timeout 300

echo " "
echo "Waiting 30 seconds before collecting and processing logs..."
sleep 30

# COLLECTING NODE EXPORTER AND CADVISOR METRICS FROM PROMETHEUS
echo " "
echo "▶ Collecting Node Exporter and cAdvisor metrics from Prometheus..."
"${LM_dir}/${onGen_dir}/get_metrics_posttest.py" --out-dir "${LM_dir}/${onGen_dir}/${DIRNAME}" --prom-url "${VM_tailscale_domain_name}:9090"

	
# ---------------- COLLECT & PROCESS LOGS IN VM INFRA----------------
echo " "
echo "▶ Collecting and processing logs on VM..."

sshpass -p "${VM_password}" ssh -o StrictHostKeyChecking=no ${VM_username}@${VM_tailscale_IPv4} bash -s <<EOF

set -euo pipefail
IFS=\$'\n\t'

DIRNAME="${DIRNAME}"
M="${M}"
N="${N}"
seed="${seed}"
alpha="${alpha}"
beta="${beta}"
VM_dir="${VM_dir}"
onVM_dir="${onVM_dir}"
onInfra_dir="${onInfra_dir}"

echo " "
echo "▶ Stopping containers on VM..."
docker compose -f "\$VM_dir/\$onInfra_dir/compose.yaml" stop
echo " "
echo "Waiting for containers to stop..."
sleep 15

# Create output directory if not exists
mkdir -p "\$VM_dir/\$onVM_dir/\$DIRNAME"

echo " "
echo "COLLECTING AND PROCESSING LOGS FROM IOT AGENT JSON CONTAINER"
echo "▶ Searching for IoT Agent JSON target container..."
container_name=\$(docker ps -a --format '{{.Names}}' | grep 'fiware-iot-agent' || true)
if [ -n "\$container_name" ]; then
  echo "▶ Collecting logs from container: \$container_name"
  docker logs  "\$container_name" > "\$VM_dir/\$onVM_dir/\$DIRNAME/raw_logs_\${container_name}_M\${M}_N\${N}_seeds\${seed}_alpha\${alpha}_beta\${beta}.log-agent" 2>&1 || echo "⚠️ Could not get logs from \$container_name"
# Ensure logs are fully written before closing
sync
sleep 2
echo "✅ Logs saved at \$VM_dir/\$onVM_dir/\$DIRNAME/"
else
  echo "⚠️ No container matching 'fiware-iot-agent' found. Skipping logs."
fi
echo " "
echo "▶ Processing IoT Agent JSON logs..."
"\$VM_dir/\$onVM_dir/7_process_iot_agent_logs.sh" \
  --out-dir "\$VM_dir/\$onVM_dir/\$DIRNAME" || echo "⚠️ Log processing failed, continuing anyway."
EOF

# ---------------- COPY LOGS BACK FROM VM INFRA ----------------
echo " "
echo "▶ Copying processed logs back to laptop..."
sshpass -p "${VM_password}" scp -o StrictHostKeyChecking=no \
  ${VM_username}@${VM_tailscale_IPv4}:"${VM_dir}/${onVM_dir}/${DIRNAME}/*" \
  "${LM_dir}/${onGen_dir}/${DIRNAME}/"
echo " "
echo "✅ Script finished."


# ---------------- COLLECT & PROCESS LOGS IN JETSON NANO----------------
echo " "
echo "▶ Collecting and processing logs on Jetson..."

sshpass -p "${Jetson_password}" ssh -o StrictHostKeyChecking=no ${Jetson_username}@${Jetson_tailscale_IPv4} bash -s <<EOF

set -euo pipefail
IFS=\$'\n\t'

DIRNAME="${DIRNAME}"
M="${M}"
N="${N}"
seed="${seed}"
alpha="${alpha}"
beta="${beta}"
Jetson_dir="${Jetson_dir}"
onJetson_dir="${onJetson_dir}"

echo " "
echo "▶ Stopping containers on VM..."
docker-compose -f "\$Jetson_dir/\$onJetson_dir/compose.yml" stop
echo " "
echo "Waiting for containers to stop..."
sleep 15

# Create output directory if not exists
mkdir -p "\$Jetson_dir/\$onJetson_dir/\$DIRNAME"

echo " "
echo "COLLECTING AND PROCESSING LOGS FROM JETSON CONTAINER"
echo "▶ Searching for Jetson target container..."
container_name=\$(docker ps -a --format '{{.Names}}' | grep 'jetson-ml_container' || true)
if [ -n "\$container_name" ]; then
  echo "▶ Collecting logs from container: \$container_name"
  docker logs  "\$container_name" > "\$Jetson_dir/\$onJetson_dir/\$DIRNAME/raw_logs_\${container_name}_M\${M}_N\${N}_seeds\${seed}_alpha\${alpha}_beta\${beta}.log-jetson" 2>&1 || echo "⚠️ Could not get logs from \$container_name"
# Ensure logs are fully written before closing
sync
sleep 2
echo "✅ Logs saved at \$Jetson_dir/\$onJetson_dir/\$DIRNAME/"
else
  echo "⚠️ No container matching 'jetson-ml_container' found. Skipping logs."
fi
echo " "
echo "▶ Processing Jetson logs..."
"\$Jetson_dir/\$onJetson_dir/scripts/process_jetson_logs.sh" \
  --input-file "\$Jetson_dir/\$onJetson_dir/\$DIRNAME/raw_logs_\${container_name}_M\${M}_N\${N}_seeds\${seed}_alpha\${alpha}_beta\${beta}.log-jetson"  \
  --output-file "\$Jetson_dir/\$onJetson_dir/\$DIRNAME/processed_raw_logs_\${container_name}_M\${M}_N\${N}_seeds\${seed}_alpha\${alpha}_beta\${beta}.csv" || echo "⚠️ Log processing failed, continuing anyway."

# I avoid processing the Jetson Tegrastats logs, since doing that in the device itself takes too long.
# I will copy the logs and process them in the

EOF

# ---------------- COPY LOGS BACK FROM JETSON NANO ----------------
echo " "
echo "▶ Copying processed logs from Jetson back to laptop..."
sshpass -p "${Jetson_password}" scp -o StrictHostKeyChecking=no \
  ${Jetson_username}@${Jetson_tailscale_IPv4}:"${Jetson_dir}/${onJetson_dir}/${DIRNAME}/*" \
  "${LM_dir}/${onGen_dir}/${DIRNAME}/"
echo " "
echo "✅ Script finished."

# PROCESSING JETSON TEGRASTATS LOGS IN VM.
echo " "
echo "Processing Jetson Tegrastats logs in VM..."
"${LM_dir}/${onJetson_dir}/scripts/parse_tegrastats_to_csv.sh" \
  --input-file "${LM_dir}/${onGen_dir}/${DIRNAME}/raw_logs_jetson_tegrastats_M${M}_N${N}_seeds${seed}_alpha${alpha}_beta${beta}.log-jetson-tegrastats" \
  --output-file "${LM_dir}/${onGen_dir}/${DIRNAME}/processed_raw_logs_jetson_tegrastats_M${M}_N${N}_seeds${seed}_alpha${alpha}_beta${beta}.csv"

