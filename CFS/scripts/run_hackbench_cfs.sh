#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config_cfs.sh"

PROJECT_ROOT="${HOME}/scheduler_experiments_cfs"
HACKBENCH_BIN="${PROJECT_ROOT}/benchmarks/rt-tests/hackbench"

[ ! -x "${HACKBENCH_BIN}" ] && { echo "[오류] hackbench를 찾을 수 없습니다"; exit 1; }

RESULT_DIR="${PROJECT_ROOT}/results/hackbench"
mkdir -p "${RESULT_DIR}"

echo "[실행] hackbench 다중 그룹 테스트 (커널: $(uname -r))"
echo ""

HACKBENCH_LOOPS=50
HACKBENCH_DATASIZE=100

cat > "${RESULT_DIR}/hackbench_results.txt" <<EOF
=========================================
hackbench 오버헤드 벤치마크
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)
설정: ${HACKBENCH_LOOPS} loops, ${HACKBENCH_DATASIZE} bytes

EOF

for NUM_GROUPS in 4 6 8; do
    echo "========================================"
    echo "[${NUM_GROUPS}개 그룹] 테스트 중..."
    
    perf stat -e task-clock,context-switches,cpu-migrations,page-faults \
        "${HACKBENCH_BIN}" -l ${HACKBENCH_LOOPS} -g ${NUM_GROUPS} -s ${HACKBENCH_DATASIZE} -P \
        > "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>&1 || true
    
    EXEC_TIME=$(grep "Time:" "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>/dev/null | awk '{print $2}' || echo "N/A")
    CTX_SW=$(grep "context-switches" "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    CPU_MIG=$(grep "cpu-migrations" "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    PAGE_FAULTS=$(grep "page-faults" "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    TASK_CLOCK=$(grep "task-clock" "${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    
    cat >> "${RESULT_DIR}/hackbench_results.txt" <<EOF
[${NUM_GROUPS} 그룹 - 총 $((NUM_GROUPS * 40)) 태스크]
─────────────────────────────────────
  실행 시간: ${EXEC_TIME}초
  Task clock: ${TASK_CLOCK} msec
  
  Context switches: ${CTX_SW}
  CPU migrations: ${CPU_MIG}
  Page faults: ${PAGE_FAULTS}

EOF
    
    echo "[${NUM_GROUPS}개 그룹] 완료 - 시간: ${EXEC_TIME}초"
    echo ""
done

echo "상세 로그: raw_4groups.txt, raw_6groups.txt, raw_8groups.txt" >> "${RESULT_DIR}/hackbench_results.txt"

echo "========================================"
echo "[완료] 전체 hackbench 테스트 완료"
echo "결과 파일: ${RESULT_DIR}/hackbench_results.txt"
echo "========================================"
