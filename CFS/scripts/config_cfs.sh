#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${HOME}/scheduler_experiments_cfs"
RESULT_ROOT="${PROJECT_ROOT}/results"

SCHBENCH_BIN="${SCHBENCH_BIN:-${PROJECT_ROOT}/benchmarks/schbench/schbench}"

if [ -z "${HACKBENCH_BIN:-}" ]; then
    if command -v hackbench &> /dev/null; then
        HACKBENCH_BIN="$(command -v hackbench)"
    elif [ -x "${PROJECT_ROOT}/benchmarks/rt-tests/hackbench" ]; then
        HACKBENCH_BIN="${PROJECT_ROOT}/benchmarks/rt-tests/hackbench"
    else
        HACKBENCH_BIN="/usr/bin/hackbench"
    fi
fi

kernel_version() { uname -r; }
