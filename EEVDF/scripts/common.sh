#!/usr/bin/env bash
# 공통 설정 및 유틸리티 함수

set -euo pipefail

# 프로젝트 경로
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
RESULT_ROOT="${PROJECT_ROOT}/results"

# 벤치마크 바이너리 경로
SCHBENCH_BIN="${PROJECT_ROOT}/benchmarks/schbench/schbench"
HACKBENCH_BIN="${PROJECT_ROOT}/benchmarks/rt-tests/hackbench"

# 벤치마크 파라미터
SCHBENCH_THREADS=(4 6 8)
HACKBENCH_GROUPS=(4 6 8)
HACKBENCH_LOOPS=50
HACKBENCH_DATASIZE=100

# 유틸리티 함수
check_sudo() {
    if [ "$EUID" -ne 0 ]; then 
        echo "[오류] 이 스크립트는 sudo 권한이 필요합니다"
        echo "사용법: sudo $0 $*"
        return 1
    fi
    return 0
}

check_schbench() {
    if [ ! -x "${SCHBENCH_BIN}" ]; then
        echo "[오류] schbench를 찾을 수 없습니다: ${SCHBENCH_BIN}"
        return 1
    fi
    return 0
}

check_hackbench() {
    if [ ! -x "${HACKBENCH_BIN}" ]; then
        echo "[오류] hackbench를 찾을 수 없습니다: ${HACKBENCH_BIN}"
        return 1
    fi
    return 0
}

parse_schbench_result() {
    local raw_file=$1
    local avg_rps=$(grep "average rps" "${raw_file}" | awk '{print $3}')
    local wakeup_99=$(grep "Wakeup Latencies.*runtime 30" "${raw_file}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')
    local request_99=$(grep "Request Latencies.*runtime 30" "${raw_file}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')
    
    echo "${avg_rps}|${wakeup_99}|${request_99}"
}

parse_hackbench_result() {
    local raw_file=$1
    local exec_time=$(grep "Time:" "${raw_file}" 2>/dev/null | awk '{print $2}' || echo "N/A")
    local ctx_sw=$(grep "context-switches" "${raw_file}" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    local cpu_mig=$(grep "cpu-migrations" "${raw_file}" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    local page_faults=$(grep "page-faults" "${raw_file}" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    
    echo "${exec_time}|${ctx_sw}|${cpu_mig}|${page_faults}"
}

