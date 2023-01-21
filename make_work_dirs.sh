#!/usr/bin/env bash

for i in "$@"; do
  newdir="work/${i}"
  for j in tests source; do
    mkdir -p "${newdir}/${j}"
  done
  extrafiles=(testscript.vpy final_args.sh)
  cp -t "${newdir}" --no-preserve=mode "${extrafiles[@]}"
done
