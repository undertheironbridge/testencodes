#!/usr/bin/env bash

start_runner() {
  local jobs=$1
  shift
  if [[ $# -ge 1 ]]; then
    parallel --tmux --jobs $jobs "${parallel_args[@]}" ./runner.sh '{}' ::: "$@"
  else
    echo "Nothing to run"
  fi
}
