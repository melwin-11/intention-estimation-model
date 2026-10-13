set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/set_env.sh"

PYTHON_BIN="${PYTHON_BIN:-python}"

if [ "$#" -ne 1 ]; then
    echo "Usage: bash scripts/run_baseline.sh <mode>   (0 = train, 1 = train and test, 2 = test only)" >&2
    exit 1
fi

MODE="$1"
case "${MODE}" in
    0|1|2) ;;
    *)
        echo "Invalid mode '${MODE}'. Use 0, 1 or 2." >&2
        exit 1
        ;;
esac

for required_dir in "${PIE_PATH}" "${PIE_PATH}/annotations" "${PIE_PATH}/annotations_vehicle" "${PIE_PATH}/images"; do
    if [ ! -d "${required_dir}" ]; then
        echo "Missing directory: ${required_dir}" >&2
        echo "Download the data and extract frames first (see README setup steps)." >&2
        exit 1
    fi
done

if ! "${PYTHON_BIN}" -c "import pie_data" 2>/dev/null; then
    echo "Cannot import pie_data with ${PYTHON_BIN}. Check PYTHONPATH and the active environment." >&2
    exit 1
fi

LOG_DIR="${REPO_ROOT}/experiments/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/baseline_mode${MODE}_$(date +%Y%m%d_%H%M%S).log"

cd "${REPO_ROOT}/baselines/piepredict"

echo "Running train_test.py with mode ${MODE}"
echo "Log file: ${LOG_FILE}"

PYTHONUNBUFFERED=1 "${PYTHON_BIN}" train_test.py "${MODE}" 2>&1 | tee "${LOG_FILE}"