#!/usr/bin/env bash
# Script:    download_clips_parallel.sh
# Purpose:   Download the PIE video clips (about 74 GB, 53 clips in set01 to set06)
#            with several parallel connections instead of the single sequential
#            connection used by the upstream download_clips.sh.
# Usage:     bash scripts/download_clips_parallel.sh [jobs]
#            jobs is the number of simultaneous downloads (default 6).
# Behaviour: Reads the server directory listings to build the clip URL list,
#            saves it as PIE_PATH/clip_urls.txt, and downloads every clip into
#            PIE_PATH/PIE_clips/<set_id>/<video_id>.mp4, the layout expected by
#            data/pie_data.py. Works from any current directory because it changes
#            into PIE_PATH itself (set by scripts/set_env.sh).
# Resuming:  Safe to stop and rerun. Completed files are skipped and partial files
#            are continued (wget -c).
# Note:      Use a modest number of jobs. If total bandwidth is the limit, more
#            jobs will not make the download faster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/set_env.sh" > /dev/null

JOBS="${1:-6}"
BASE_URL="https://data.nvision2.eecs.yorku.ca/PIE_dataset/PIE_clips"
SET_IDS="set01 set02 set03 set04 set05 set06"
EXPECTED_CLIPS=53

mkdir -p "${PIE_PATH}"
cd "${PIE_PATH}"

URL_LIST="${PIE_PATH}/clip_urls.txt"
: > "${URL_LIST}"

for set_id in ${SET_IDS}; do
    curl -fsS "${BASE_URL}/${set_id}/" \
        | grep -o 'video_[0-9]*\.mp4' \
        | sort -u \
        | sed "s|^|${BASE_URL}/${set_id}/|" >> "${URL_LIST}"
done

CLIP_COUNT="$(wc -l < "${URL_LIST}")"
echo "Found ${CLIP_COUNT} clips. Downloading to ${PIE_PATH}/PIE_clips with ${JOBS} parallel jobs."

if [ "${CLIP_COUNT}" -ne "${EXPECTED_CLIPS}" ]; then
    echo "Warning: expected ${EXPECTED_CLIPS} clips but found ${CLIP_COUNT}." >&2
fi

if ! xargs -n 1 -P "${JOBS}" wget -c -nv -x -nH --cut-dirs=1 < "${URL_LIST}"; then
    echo "Some downloads failed. Rerun this script to resume." >&2
    exit 1
fi

DOWNLOADED="$(find "${PIE_PATH}/PIE_clips" -name '*.mp4' | wc -l)"
echo "Done. ${DOWNLOADED} of ${CLIP_COUNT} clips are present."