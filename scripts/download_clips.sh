#!/usr/bin/env bash
# Script:    download_clips.sh
# Purpose:   Download the PIE video clips from the public Google Drive folder
#            (one zip per set, 68.9 GB in total) and unpack them into
#            PIE_clips/set01 ... PIE_clips/set06 under the CURRENT directory.
# Usage:     cd /data/PIE_dataset
#            bash ~/slm-hvi-pie/scripts/download_clips.sh            (all six sets)
#            bash ~/slm-hvi-pie/scripts/download_clips.sh set03      (only set03, the PIEPredict test set)
# Output:    ./PIE_zips/setXX.zip  (deleted after unpacking unless KEEP_ZIPS=1)
#            ./PIE_clips/setXX/video_XXXX.mp4
# Requires:  unzip, and the gdown package for python3 (pip install -U gdown).
#            Run it outside the Python 3.6 piepredict environment (conda deactivate),
#            because current gdown releases need a newer Python.
# Settings:  KEEP_ZIPS=1    keep the zip files after unpacking.
#            ZIP_DIR=<dir>  where zips are stored (default ./PIE_zips).
# Safety:    Refuses to run inside a git repository, so clips never land in the code repo.
# Resuming:  Safe to rerun. A zip that is already complete is not downloaded again,
#            and files that are already unpacked are not overwritten.
# Space:     Needs about twice the zip size free while a set is unpacking
#            (set03 is 25.8 GB, so about 52 GB).
# Limits:    Google Drive may refuse a download with a "too many users have viewed
#            or downloaded this file recently" quota message. Wait and rerun, or use
#            scripts/download_clips_parallel.sh to fetch from the York server.

set -euo pipefail

FOLDER_URL="https://drive.google.com/drive/folders/180MXX1z3aicZMwYu2pCM0TamzUKT0L16"
ZIP_DIR="${ZIP_DIR:-PIE_zips}"
CLIPS_DIR="PIE_clips"
KEEP_ZIPS="${KEEP_ZIPS:-0}"

declare -A ZIP_GB=([set01]=4 [set02]=3 [set03]=26 [set04]=22 [set05]=2 [set06]=13)

if [ "$#" -gt 0 ]; then
    SET_IDS=("$@")
else
    SET_IDS=(set01 set02 set03 set04 set05 set06)
fi

for tool in gdown unzip python3; do
    if ! command -v "${tool}" > /dev/null 2>&1; then
        echo "Missing required tool: ${tool}" >&2
        exit 1
    fi
done

if ! python3 -c "import gdown" 2> /dev/null; then
    echo "python3 cannot import gdown. Run 'conda deactivate' if a Python 3.6 environment is active, then: pip install -U gdown" >&2
    exit 1
fi

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "The current directory is inside a git repository: $(pwd)" >&2
    echo "Change to your dataset directory first, for example: cd /data/PIE_dataset" >&2
    exit 1
fi

echo "Destination: $(pwd)/${CLIPS_DIR}"
mkdir -p "${ZIP_DIR}" "${CLIPS_DIR}"

declare -A FILE_IDS
while read -r file_id file_name; do
    FILE_IDS["${file_name}"]="${file_id}"
done < <(python3 - "${FOLDER_URL}" << 'PY'
import os
import sys

import gdown

entries = gdown.download_folder(url=sys.argv[1], skip_download=True, quiet=True, remaining_ok=True)
for entry in entries:
    print(entry.id, os.path.basename(entry.path))
PY
)

if [ "${#FILE_IDS[@]}" -eq 0 ]; then
    echo "Could not read the Drive folder listing. Update gdown (pip install -U gdown) and retry." >&2
    exit 1
fi

for set_id in "${SET_IDS[@]}"; do
    zip_name="${set_id}.zip"
    zip_path="${ZIP_DIR}/${zip_name}"
    file_id="${FILE_IDS[${zip_name}]:-}"

    if [ -z "${file_id}" ]; then
        echo "${zip_name} was not found in the Drive folder." >&2
        exit 1
    fi

    if ! unzip -Z1 "${zip_path}" > /dev/null 2>&1; then
        needed_gb=$((2 * ${ZIP_GB[${set_id}]:-30} + 1))
        available_gb=$(($(df --output=avail -B1G . | tail -n 1) + 0))
        if [ "${available_gb}" -lt "${needed_gb}" ]; then
            echo "Not enough free space for ${set_id}: need about ${needed_gb} GB, have ${available_gb} GB." >&2
            exit 1
        fi
        echo "Downloading ${zip_name}"
        gdown --continue "https://drive.google.com/uc?id=${file_id}" -O "${zip_path}"
    else
        echo "${zip_name} is already downloaded."
    fi

    first_entry="$(unzip -Z1 "${zip_path}" | sed -n '1p')"
    echo "Unpacking ${zip_name}"
    case "${first_entry}" in
        PIE_clips/*)
            unzip -n -q "${zip_path}"
            ;;
        "${set_id}"/*)
            unzip -n -q "${zip_path}" -d "${CLIPS_DIR}"
            ;;
        *)
            mkdir -p "${CLIPS_DIR}/${set_id}"
            unzip -n -q "${zip_path}" -d "${CLIPS_DIR}/${set_id}"
            ;;
    esac

    clip_count="$(find "${CLIPS_DIR}/${set_id}" -name '*.mp4' | wc -l)"
    if [ "${clip_count}" -eq 0 ]; then
        echo "No mp4 files found in ${CLIPS_DIR}/${set_id} after unpacking. Inspect the layout with: unzip -l ${zip_path} | head" >&2
        exit 1
    fi
    echo "${set_id}: ${clip_count} clips"

    if [ "${KEEP_ZIPS}" != "1" ]; then
        rm -f "${zip_path}"
    fi
done

total_clips="$(find "${CLIPS_DIR}" -name '*.mp4' | wc -l)"
echo "Done. ${total_clips} clips in $(pwd)/${CLIPS_DIR}"