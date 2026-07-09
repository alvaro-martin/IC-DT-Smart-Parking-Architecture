#!/bin/bash

usage() {
    echo "Usage: $0 --container <name> --M <value> --N <value> --seeds <value> --alpha <value> --beta <value> [--out-dir <dir>]"
    echo
    echo "  --container  Required. Docker container name or ID to collect logs from."
    echo "  --M          Required. Value for M."
    echo "  --N          Required. Value for N."
    echo "  --seeds      Required. Value for seeds."
    echo "  --alpha      Required. Value for alpha."
    echo "  --beta       Required. Value for beta."
    echo "  --out-dir    Optional. Output directory (default: current directory)."
    exit 1
}

# defaults
OUT_DIR="./results"

# parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --container)
            CONTAINER="$2"
            shift 2
            ;;
        --M)
            M="$2"
            shift 2
            ;;
        --N)
            N="$2"
            shift 2
            ;;
        --seeds)
            SEEDS="$2"
            shift 2
            ;;
        --alpha)
            ALPHA="$2"
            shift 2
            ;;
        --beta)
            BETA="$2"
            shift 2
            ;;
        --out-dir)
            OUT_DIR="$2"
            shift 2
            ;;
        -*|--*)
            echo "Unknown option $1"
            usage
            ;;
        *)
            shift
            ;;
    esac
done

# check required params
if [[ -z "$CONTAINER" || -z "$M" || -z "$N" || -z "$SEEDS" || -z "$ALPHA" || -z "$BETA" ]]; then
    echo "Error: Missing required arguments."
    usage
fi

# ensure output dir exists
mkdir -p "$OUT_DIR"

# build filename
FILENAME="raw_logs_${CONTAINER}_M${M}_N${N}_seeds${SEEDS}_alpha${ALPHA}_beta${BETA}.log"

# full path
OUTFILE="$OUT_DIR/$FILENAME"

echo "Saving logs from container '$CONTAINER' to: $OUTFILE"

# actual docker logs command
docker logs "$CONTAINER" &> "$OUTFILE"

