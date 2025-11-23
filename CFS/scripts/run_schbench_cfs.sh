#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHBENCH_BIN="${PROJECT_ROOT}/benchmarks/schbench/schbench"

if [ ! -x "${SCHBENCH_BIN}" ]; then
    echo "[정보] schbench 빌드 중..."
    SCHBENCH_DIR="${PROJECT_ROOT}/benchmarks/schbench"
    
    [ ! -d "${SCHBENCH_DIR}" ] && {
        mkdir -p "${PROJECT_ROOT}/benchmarks"
        cd "${PROJECT_ROOT}/benchmarks"
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/mason/schbench.git
    }
    
    cd "${SCHBENCH_DIR}" && make
    [ ! -x "${SCHBENCH_BIN}" ] && { echo "[오류] schbench 빌드 실패"; exit 1; }
    echo "[정보] schbench 빌드 완료"
fi

RESULT_DIR="${PROJECT_ROOT}/results/schbench"
mkdir -p "${RESULT_DIR}"

echo "[실행] schbench 다중 스레드 테스트 (커널: $(uname -r))"
echo ""

# 통합 보고서 헤더
cat > "${RESULT_DIR}/schbench_results.txt" <<EOF
=========================================
schbench 레이턴시 벤치마크
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)

EOF

for THREADS in 4 6 8; do
    echo "========================================"
    echo "[${THREADS}개 스레드] 테스트 중..."
    
    "${SCHBENCH_BIN}" -m ${THREADS} -t 5 -s 128 > "${RESULT_DIR}/raw_${THREADS}threads.txt" 2>&1
    
    AVG_RPS=$(grep "average rps" "${RESULT_DIR}/raw_${THREADS}threads.txt" | awk '{print $3}')
    
    WAKEUP_SECTION=$(grep "Wakeup Latencies.*runtime 30" "${RESULT_DIR}/raw_${THREADS}threads.txt" -A5 | tail -5)
    WAKEUP_50=$(echo "${WAKEUP_SECTION}" | grep "50.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    WAKEUP_90=$(echo "${WAKEUP_SECTION}" | grep "90.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    WAKEUP_99=$(echo "${WAKEUP_SECTION}" | grep "99.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    WAKEUP_999=$(echo "${WAKEUP_SECTION}" | grep "99.9th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    
    REQUEST_SECTION=$(grep "Request Latencies.*runtime 30" "${RESULT_DIR}/raw_${THREADS}threads.txt" -A5 | tail -5)
    REQUEST_50=$(echo "${REQUEST_SECTION}" | grep "50.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    REQUEST_90=$(echo "${REQUEST_SECTION}" | grep "90.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    REQUEST_99=$(echo "${REQUEST_SECTION}" | grep "99.0th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    REQUEST_999=$(echo "${REQUEST_SECTION}" | grep "99.9th" | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
    
    cat >> "${RESULT_DIR}/schbench_results.txt" <<EOF
[${THREADS} 스레드]
─────────────────────────────────────
  RPS: ${AVG_RPS}
  
  Wakeup Latency (usec)    Request Latency (usec)
    p50:  ${WAKEUP_50}                p50:  ${REQUEST_50}
    p90:  ${WAKEUP_90}                p90:  ${REQUEST_90}
    p99:  ${WAKEUP_99}                p99:  ${REQUEST_99}
    p99.9: ${WAKEUP_999}              p99.9: ${REQUEST_999}

EOF
    
    echo "[${THREADS}개 스레드] 완료 - RPS: ${AVG_RPS}"
    echo ""
done

echo "상세 로그: raw_4threads.txt, raw_6threads.txt, raw_8threads.txt" >> "${RESULT_DIR}/schbench_results.txt"

echo "========================================"
echo "[완료] 전체 schbench 테스트 완료"
echo "결과 파일: ${RESULT_DIR}/schbench_results.txt"
echo "========================================"
