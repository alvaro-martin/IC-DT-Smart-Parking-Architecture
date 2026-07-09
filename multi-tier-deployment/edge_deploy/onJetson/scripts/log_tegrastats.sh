#!/bin/bash
# =============================================================================
# Script Name: tegrastats_logger.sh
# Description: Logs Jetson tegrastats for the edge_deploy project.
# Usage: ./tegrastats_logger.sh --output-file <output>
# =============================================================================

set -euo pipefail

# --------------------------- #
#          FUNCTIONS          #
# --------------------------- #

usage() {
    #### Simplified usage (removed input-file)
    echo "Usage: $0 --output-file <output>"
    echo
    echo "Parameters:"
    echo "  --output-file <output>   Path to save the tegrastats log"
    echo
    echo "Example:"
    echo "  $0 --output-file logs/tegrastats_run1.log"
    echo
    echo "Press Ctrl+C to stop logging."
    exit 1
}

# --------------------------- #
#       ARGUMENT PARSING      #
# --------------------------- #

#### Only keep output_file
output_file=""

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
#         VALIDATION          #
# --------------------------- #

#### Simplified validation
if [[ -z "$output_file" ]]; then
    echo "❌ Error: --output-file is required."
    usage
fi

# Check if tegrastats exists
if ! command -v tegrastats &> /dev/null; then
    echo "❌ Error: tegrastats command not found. Make sure it’s installed and in PATH."
    exit 1
fi

# --------------------------- #
#     DIRECTORY AND FILES     #
# --------------------------- #

#### Simplified folder logic
output_dir=$(dirname "$output_file")
mkdir -p "$output_dir"

# --------------------------- #
#        LOG EXECUTION        #
# --------------------------- #

#### Simplified printout
echo "🚀 Starting tegrastats logging..."
echo "📝 Output log: $output_file"
echo "Press Ctrl+C to stop logging."

tegrastats | tee "$output_file"

