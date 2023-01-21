#!/usr/bin/env bash

set -e

source "$1"

run_vspipe() {
  vspipe "${vspipeargs[@]}" -c y4m "$testscript" - |
    x264 --demuxer y4m - "$@" "${x264args[@]}" --output "${output}.mkv"
}

{
  if [[ -n $bitrate ]]; then
    echo "> Pass 1"
    run_vspipe --bitrate $bitrate --pass 1 --stats "${output}.stats"
    echo -e "\n> Pass 2"
    run_vspipe --bitrate $bitrate --pass 2 --stats "${output}.stats"
  else
    run_vspipe --crf $crf
  fi
} 2>&1 | tee ${output}_tmp.log

strings "${output}_tmp.log" | grep -v " frames: \|Output " >"${output}.log"
rm "${output}_tmp.log"
