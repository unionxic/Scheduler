#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${HOME}/scheduler_experiments_cfs"
SCHBENCH_BIN="${PROJECT_ROOT}/benchmarks/schbench/schbench"
HACKBENCH_BIN="${PROJECT_ROOT}/benchmarks/rt-tests/hackbench"

[ ! -x "${SCHBENCH_BIN}" ] && { echo "[오류] schbench를 찾을 수 없습니다"; exit 1; }
[ ! -x "${HACKBENCH_BIN}" ] && { echo "[오류] hackbench를 찾을 수 없습니다"; exit 1; }

RESULT_DIR="${PROJECT_ROOT}/results/workload_scenarios"
mkdir -p "${RESULT_DIR}"

echo "========================================="
echo "워크로드 시나리오 벤치마크"
echo "========================================="
echo ""
echo "실험 일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo "커널 버전: $(uname -r)"
echo ""

cat > "${RESULT_DIR}/workload_results.txt" <<EOF
=========================================
워크로드 시나리오 벤치마크
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)

EOF

echo "[1/4] CPU-Bound 워크로드 (높은 스레드 수)"
echo "----------------------------------------"
"${SCHBENCH_BIN}" -m 16 -t 10 -s 256 > "${RESULT_DIR}/cpu_bound_raw.txt" 2>&1

CPU_RPS=$(grep "average rps" "${RESULT_DIR}/cpu_bound_raw.txt" | awk '{print $3}')
CPU_WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RESULT_DIR}/cpu_bound_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
CPU_REQUEST_99=$(grep "Request Latencies.*runtime 30" "${RESULT_DIR}/cpu_bound_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)

cat >> "${RESULT_DIR}/workload_results.txt" <<EOF
[1] CPU-Bound (16 스레드, 10 태스크)
─────────────────────────────────────
  RPS: ${CPU_RPS}
  Wakeup p99: ${CPU_WAKEUP_99} usec
  Request p99: ${CPU_REQUEST_99} usec

EOF

echo "[1/4] 완료 - RPS: ${CPU_RPS}"
echo ""

echo "[2/4] I/O-Bound 워크로드 (낮은 스레드 수, 높은 메시지)"
echo "----------------------------------------"
"${SCHBENCH_BIN}" -m 2 -t 20 -s 512 > "${RESULT_DIR}/io_bound_raw.txt" 2>&1

IO_RPS=$(grep "average rps" "${RESULT_DIR}/io_bound_raw.txt" | awk '{print $3}')
IO_WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RESULT_DIR}/io_bound_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
IO_REQUEST_99=$(grep "Request Latencies.*runtime 30" "${RESULT_DIR}/io_bound_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)

cat >> "${RESULT_DIR}/workload_results.txt" <<EOF
[2] I/O-Bound (2 스레드, 20 태스크)
─────────────────────────────────────
  RPS: ${IO_RPS}
  Wakeup p99: ${IO_WAKEUP_99} usec
  Request p99: ${IO_REQUEST_99} usec

EOF

echo "[2/4] 완료 - RPS: ${IO_RPS}"
echo ""

echo "[3/4] 혼합 워크로드 (중간 스레드 수)"
echo "----------------------------------------"
"${SCHBENCH_BIN}" -m 8 -t 8 -s 256 > "${RESULT_DIR}/mixed_raw.txt" 2>&1

MIXED_RPS=$(grep "average rps" "${RESULT_DIR}/mixed_raw.txt" | awk '{print $3}')
MIXED_WAKEUP_99=$(grep "Wakeup Latencies.*runtime 30" "${RESULT_DIR}/mixed_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)
MIXED_REQUEST_99=$(grep "Request Latencies.*runtime 30" "${RESULT_DIR}/mixed_raw.txt" -A5 | grep "99.0th" | tail -1 | sed 's/[*\t ]//g' | cut -d: -f2 | cut -d'(' -f1)

cat >> "${RESULT_DIR}/workload_results.txt" <<EOF
[3] 혼합 워크로드 (8 스레드, 8 태스크)
─────────────────────────────────────
  RPS: ${MIXED_RPS}
  Wakeup p99: ${MIXED_WAKEUP_99} usec
  Request p99: ${MIXED_REQUEST_99} usec

EOF

echo "[3/4] 완료 - RPS: ${MIXED_RPS}"
echo ""

echo "[4/4] 고부하 컨텍스트 스위칭 (hackbench 대규모)"
echo "----------------------------------------"
perf stat -e task-clock,context-switches,cpu-migrations,page-faults,cycles,instructions \
    /usr/bin/time -v "${HACKBENCH_BIN}" -l 100 -g 16 -s 200 -P \
    > "${RESULT_DIR}/high_load_raw.txt" 2>&1 || true

HIGH_TIME=$(grep "Time:" "${RESULT_DIR}/high_load_raw.txt" 2>/dev/null | awk '{print $2}' || echo "N/A")
HIGH_CTX=$(grep "context-switches" "${RESULT_DIR}/high_load_raw.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
HIGH_MIG=$(grep "cpu-migrations" "${RESULT_DIR}/high_load_raw.txt" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")

cat >> "${RESULT_DIR}/workload_results.txt" <<EOF
[4] 고부하 컨텍스트 스위칭 (16 그룹, 640 태스크)
─────────────────────────────────────
  실행 시간: ${HIGH_TIME}초
  Context switches: ${HIGH_CTX}
  CPU migrations: ${HIGH_MIG}

EOF

echo "[4/4] 완료 - 시간: ${HIGH_TIME}초"
echo ""

echo "상세 로그: cpu_bound_raw.txt, io_bound_raw.txt, mixed_raw.txt, high_load_raw.txt" >> "${RESULT_DIR}/workload_results.txt"

echo "========================================="
echo "[완료] 워크로드 시나리오 테스트 완료"
echo "결과 파일: ${RESULT_DIR}/workload_results.txt"
echo "========================================="

