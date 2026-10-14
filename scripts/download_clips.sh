#!/usr/bin/env bash
# Script:    download_clips_parallel.sh
# Purpose:   Download the PIE video clips (about 74 GB, 53 clips in set01 to set06)
#            with several parallel connections instead of the single sequential
#            connection used by the upstream download_clips.sh, and report progress.
# Usage:     bash scripts/download_clips_parallel.sh [jobs]
#            jobs is the number of simultaneous downloads (default 6).
#            Set REPORT_INTERVAL=<seconds> to change how often progress is printed
#            (default 10).
# Behaviour: Reads the server directory listings to build the clip URL list
#            (PIE_PATH/clip_urls.txt), asks the server for every clip size
#            (PIE_PATH/clip_sizes.txt), then downloads each clip into
#            PIE_PATH/PIE_clips/<set_id>/<video_id>.mp4, the layout expected by
#            data/pie_data.py. Works from any current directory because it changes
#            into PIE_PATH itself (set by scripts/set_env.sh).
# Progress:  Every REPORT_INTERVAL seconds a line shows bytes downloaded, percent of
#            the total, finished clips, current speed and estimated time remaining.
#            Raw wget messages and errors are written to PIE_PATH/download.log.
# Resuming:  Safe to stop and rerun. Completed files are skipped and partial files
#            are continued (wget -c).
# Note:      Use a modest number of jobs. If total bandwidth is the limit, more
#            jobs will not make the download faster.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/set_env.sh" > /dev/null

JOBS="${1:-6}"
REPORT_INTERVAL="${REPORT_INTERVAL:-10}"
BASE_URL="https://data.nvision2.eecs.yorku.ca/PIE_dataset/PIE_clips"
SET_IDS="set01 set02 set03 set04 set05 set06"
EXPECTED_CLIPS=53

mkdir -p "${PIE_PATH}"
cd "${PIE_PATH}"

URL_LIST="${PIE_PATH}/clip_urls.txt"
SIZE_LIST="${PIE_PATH}/clip_sizes.txt"
DOWNLOAD_LOG="${PIE_PATH}/download.log"

human_bytes() {
    numfmt --to=iec --suffix=B "$1"
}

human_duration() {
    local seconds="$1"
    printf '%dh %02dm %02ds' $((seconds / 3600)) $(((seconds % 3600) / 60)) $((seconds % 60))
}

build_url_list() {
    : > "${URL_LIST}"
    for set_id in ${SET_IDS}; do
        curl -fsS "${BASE_URL}/${set_id}/" \
            | grep -o 'video_[0-9]*\.mp4' \
            | sort -u \
            | sed "s|^|${BASE_URL}/${set_id}/|" >> "${URL_LIST}"
    done
}

build_size_list() {
    : > "${SIZE_LIST}"
    local url size
    while read -r url; do
        size="$(curl -fsIL "${url}" | tr -d '\r' | awk 'tolower($1)=="content-length:" {size=$2} END {print size+0}')"
        printf '%s %s\n' "PIE_clips/${url#${BASE_URL}/}" "${size}" >> "${SIZE_LIST}"
    done < "${URL_LIST}"
}

report_progress() {
    local previous_bytes=0
    local path expected actual current_bytes finished percent rate eta
    while sleep "${REPORT_INTERVAL}"; do
        current_bytes=0
        finished=0
        while read -r path expected; do
            if [ -f "${path}" ]; then
                actual="$(stat -c %s "${path}")"
                current_bytes=$((current_bytes + actual))
                if [ "${expected}" -gt 0 ] && [ "${actual}" -ge "${expected}" ]; then
                    finished=$((finished + 1))
                fi
            fi
        done < "${SIZE_LIST}"

        rate=$(((current_bytes - previous_bytes) / REPORT_INTERVAL))
        previous_bytes="${current_bytes}"

        if [ "${TOTAL_BYTES}" -gt 0 ]; then
            percent=$((100 * current_bytes / TOTAL_BYTES))
        else
            percent=0
        fi

        if [ "${rate}" -gt 0 ] && [ "${TOTAL_BYTES}" -gt "${current_bytes}" ]; then
            eta="$(human_duration $(((TOTAL_BYTES - current_bytes) / rate)))"
        else
            eta="unknown"
        fi

        printf '[%s] %s of %s (%d%%) | %d of %d clips finished | %s/s | ETA %s\n' \
            "$(date +%H:%M:%S)" "$(human_bytes "${current_bytes}")" "$(human_bytes "${TOTAL_BYTES}")" \
            "${percent}" "${finished}" "${CLIP_COUNT}" "$(human_bytes "${rate}")" "${eta}"
    done
}

build_url_list
CLIP_COUNT="$(wc -l < "${URL_LIST}")"

if [ "${CLIP_COUNT}" -ne "${EXPECTED_CLIPS}" ]; then
    echo "Warning: expected ${EXPECTED_CLIPS} clips but found ${CLIP_COUNT}." >&2
fi

echo "Reading clip sizes from the server."
build_size_list
TOTAL_BYTES="$(awk '{sum += $2} END {print sum+0}' "${SIZE_LIST}")"

echo "Found ${CLIP_COUNT} clips, $(human_bytes "${TOTAL_BYTES}") in total."
echo "Downloading to ${PIE_PATH}/PIE_clips with ${JOBS} parallel jobs. Log: ${DOWNLOAD_LOG}"

report_progress &
REPORTER_PID=$!
trap 'kill "${REPORTER_PID}" 2>/dev/null || true' EXIT

if ! xargs -n 1 -P "${JOBS}" wget -c -nv -x -nH --cut-dirs=1 -a "${DOWNLOAD_LOG}" < "${URL_LIST}"; then
    echo "Some downloads failed. Check ${DOWNLOAD_LOG}, then rerun this script to resume." >&2
    exit 1
fi

kill "${REPORTER_PID}" 2>/dev/null || true

DOWNLOADED="$(find "${PIE_PATH}/PIE_clips" -name '*.mp4' | wc -l)"
echo "Done. ${DOWNLOADED} of ${CLIP_COUNT} clips are present."