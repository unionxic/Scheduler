#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

check_schbench || exit 1
check_hackbench || exit 1

RESULT_DIR="${PROJECT_ROOT}/results/workload_scenarios"
mkdir -p "${RESULT_DIR}"

echo "[실행] 워크로드 시나리오 테스트 (커널: $(uname -r))"
echo ""

# 통합 결과 파일 초기화
SUMMARY_FILE="${RESULT_DIR}/workload_results.txt"
cat > "${SUMMARY_FILE}" <<EOF
=========================================
워크로드 시나리오 벤치마크 (EEVDF)
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)

EOF

# 1. CPU-Bound 워크로드
echo "========================================"
echo "[1/4] CPU-Bound 워크로드 테스트"
echo "  - 16 스레드, 10 태스크"
RAW_FILE="${RESULT_DIR}/cpu_bound_raw.txt"
"${SCHBENCH_BIN}" -m 16 -t 10 -r 30 > "${RAW_FILE}" 2>&1
AVG_RPS=$(grep "average rps" "${RAW_FILE}" | awk '{print $3}')
WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RAW_FILE}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')

cat >> "${SUMMARY_FILE}" <<EOF
[1] CPU-Bound (16 스레드, 10 태스크)
─────────────────────────────────────
  평균 RPS: ${AVG_RPS}
  Wakeup 99th: ${WAKEUP_99} usec

EOF
echo "[1/4] 완료 - RPS: ${AVG_RPS}"
echo ""

# 2. I/O-Bound 워크로드
echo "========================================"
echo "[2/4] I/O-Bound 워크로드 테스트"
echo "  - 2 스레드, 20 태스크"
RAW_FILE="${RESULT_DIR}/io_bound_raw.txt"
"${SCHBENCH_BIN}" -m 2 -t 20 -r 30 > "${RAW_FILE}" 2>&1
AVG_RPS=$(grep "average rps" "${RAW_FILE}" | awk '{print $3}')
WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RAW_FILE}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')

cat >> "${SUMMARY_FILE}" <<EOF
[2] I/O-Bound (2 스레드, 20 태스크)
─────────────────────────────────────
  평균 RPS: ${AVG_RPS}
  Wakeup 99th: ${WAKEUP_99} usec

EOF
echo "[2/4] 완료 - RPS: ${AVG_RPS}"
echo ""

# 3. 혼합 워크로드
echo "========================================"
echo "[3/4] 혼합 워크로드 테스트"
echo "  - 8 스레드, 8 태스크"
RAW_FILE="${RESULT_DIR}/mixed_raw.txt"
"${SCHBENCH_BIN}" -m 8 -t 8 -r 30 > "${RAW_FILE}" 2>&1
AVG_RPS=$(grep "average rps" "${RAW_FILE}" | awk '{print $3}')
WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RAW_FILE}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')

cat >> "${SUMMARY_FILE}" <<EOF
[3] 혼합 워크로드 (8 스레드, 8 태스크)
─────────────────────────────────────
  평균 RPS: ${AVG_RPS}
  Wakeup 99th: ${WAKEUP_99} usec

EOF
echo "[3/4] 완료 - RPS: ${AVG_RPS}"
echo ""

# 4. 고부하 컨텍스트 스위칭
echo "========================================"
echo "[4/4] 고부하 컨텍스트 스위칭 테스트"
echo "  - 16 그룹 (640 태스크)"
RAW_FILE="${RESULT_DIR}/high_load_raw.txt"
perf stat -e context-switches,cpu-migrations \
    /usr/bin/time -v "${HACKBENCH_BIN}" -l 50 -g 16 -s 100 -P \
    > "${RAW_FILE}" 2>&1 || true

EXEC_TIME=$(grep "Time:" "${RAW_FILE}" 2>/dev/null | awk '{print $2}' || echo "N/A")
CTX_SW=$(grep "context-switches" "${RAW_FILE}" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")

cat >> "${SUMMARY_FILE}" <<EOF
[4] 고부하 컨텍스트 스위칭 (16 그룹, 640 태스크)
─────────────────────────────────────
  실행 시간: ${EXEC_TIME}초
  Context switches: ${CTX_SW}

EOF
echo "[4/4] 완료 - 실행 시간: ${EXEC_TIME}초"
echo ""

echo "========================================" >> "${SUMMARY_FILE}"
echo "상세 로그: cpu_bound_raw.txt, io_bound_raw.txt, mixed_raw.txt, high_load_raw.txt" >> "${SUMMARY_FILE}"

echo "========================================"
echo "[완료] 전체 워크로드 시나리오 테스트 완료"
echo "결과 파일: ${SUMMARY_FILE}"
echo "========================================"

