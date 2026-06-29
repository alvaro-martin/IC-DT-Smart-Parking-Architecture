#!/usr/bin/env bash
#Script to validate that the container of the IoT infrastructure are reunning healthy before running the commmands ahead, since that can cause errors later

set -euo pipefail

MAX_RETRIES=20
SLEEP_SECONDS=5

check_service() {
  local name="$1"
  local url="$2"
  local keyword="$3"  # expected keyword in the response
  local attempt=1

  echo "🔎 Checking $name at $url ..."

  while (( attempt <= MAX_RETRIES )); do
    response=$(curl -fsS "$url" || true)
    status=$?

    if [[ $status -eq 0 && "$response" == *"$keyword"* ]]; then
      echo "✅ $name is healthy (found '$keyword', after $attempt attempt(s))."
      return 0
    else
      echo "⚠️  $name not ready yet (attempt $attempt/$MAX_RETRIES). Retrying in $SLEEP_SECONDS seconds..."
      sleep "$SLEEP_SECONDS"
      ((attempt++))
    fi
  done

  echo "❌ $name did not become healthy after $MAX_RETRIES attempts. Exiting."
  exit 1
}

# Run checks with keywords
check_service "Orion Context Broker (OCB)" "http://localhost:1026/version" "orion"
check_service "Apache Web Server" "http://localhost:3004/" "html"
check_service "IoT Agent" "http://localhost:4041/iot/about" "libVersion"
check_service "QuantumLeap" "http://localhost:8668/health" "pass"
check_service "Grafana" "http://localhost:3002/api/health" "database"
check_service "Grafana Monitor" "http://localhost:3001/api/health" "database"

echo "🎉 All services are running and healthy!"

