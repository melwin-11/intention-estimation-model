if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "set_env.sh must be sourced: source scripts/set_env.sh" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

export PIE_PATH="${PIE_DATASET_ROOT:-/data/PIE_dataset}"
export PIE_RAW_PATH="${PIE_PATH}/PIE_clips/"

export PYTHONPATH="${REPO_ROOT}/data${PYTHONPATH:+:${PYTHONPATH}}"

echo "REPO_ROOT    = ${REPO_ROOT}"
echo "PIE_PATH     = ${PIE_PATH}"
echo "PIE_RAW_PATH = ${PIE_RAW_PATH}"
echo "PYTHONPATH   = ${PYTHONPATH}"