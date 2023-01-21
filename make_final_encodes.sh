#!/usr/bin/env bash

source common_.sh

if [[ -z $WORKDIR ]]; then
  echo >&2 "Define WORKDIR first"
  exit 1
fi

generate() {
  local res=$1
  shift
  ./testencodes.sh --just-generate -o "${WORKDIR}/encode_${res}" --resize "$res" "$@"
}

generate_1080p() {
  generate 1080p "${args_1080p[@]}"
}

generate_720p() {
  generate 720p "${args_720p[@]}"
}

generate_576p() {
  generate 576p "${args_576p[@]}"
}

generate_480p() {
  generate 480p "${args_480p[@]}"
}

source "${WORKDIR}/final_args.sh"

if [[ $# -gt 0 ]]; then
  resolutions=$@
else
  resolutions=(1080p 720p 576p 480p)
fi

for i in "${resolutions[@]}"; do
  "generate_${i}"
done

start_runner ${#resolutions[@]} "${WORKDIR}/encode_"*_args.sh
