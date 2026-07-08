#!/bin/bash
set -e

# Default to 4 workers if WORKERS is not set
WORKERS=${WORKERS:-4}

exec gunicorn app:app \
	-k uvicorn.workers.UvicornWorker \
	--workers "$WORKERS" \
	--timeout 300 \
	--bind 0.0.0.0:8000 \
	--log-level info
