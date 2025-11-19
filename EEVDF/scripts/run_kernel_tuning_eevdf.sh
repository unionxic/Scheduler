#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

check_sudo || exit 1
check_schbench || exit 1
check_hackbench || exit 1

RESULT_DIR="${PROJECT_ROOT}/results/kernel_tuning"
mkdir -p "${RESULT_DIR}"

echo "[실행] 커널 파라미터 조정 실험 (커널: $(uname -r))"
echo "[주의] 원본 설정을 백업하고 자동으로 복원합니다"
echo ""

# 원본 설정 백업
ORIGINAL_LATENCY=$(cat /proc/sys/kernel/sched_latency_ns)
ORIGINAL_MIGRATION=$(cat /proc/sys/kernel/sched_migration_cost_ns)

echo "원본 설정:"
echo "  sched_latency_ns: ${ORIGINAL_LATENCY}"
echo "  sched_migration_cost_ns: ${ORIGINAL_MIGRATION}"
echo ""

# 통합 결과 파일 초기화
SUMMARY_FILE="${RESULT_DIR}/tuning_results.txt"
cat > "${SUMMARY_FILE}" <<EOF
=========================================
커널 파라미터 조정 실험 (EEVDF)
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)

원본 설정:
  sched_latency_ns: ${ORIGINAL_LATENCY}
  sched_migration_cost_ns: ${ORIGINAL_MIGRATION}

EOF

# 테스트 함수
run_test() {
    local config_name=$1
    local schbench_file=$2
    local hackbench_file=$3
    
    echo "테스트 중: ${config_name}"
    
    # schbench 실행
    "${SCHBENCH_BIN}" -m 4 -t 5 -r 30 > "${schbench_file}" 2>&1
    local rps=$(grep "average rps" "${schbench_file}" | awk '{print $3}')
    local wakeup=$(grep "Wakeup Latencies.*runtime 30" "${schbench_file}" -A4 | grep "99.0th" | tail -1 | awk '{print $3}')
    
    # hackbench 실행
    perf stat -e context-switches \
        "${HACKBENCH_BIN}" -l 50 -g 4 -s 100 -P \
        > "${hackbench_file}" 2>&1 || true
    local time=$(grep "Time:" "${hackbench_file}" 2>/dev/null | awk '{print $2}' || echo "N/A")
    local ctx=$(grep "context-switches" "${hackbench_file}" 2>/dev/null | head -1 | awk '{print $1}' | tr -d ',' || echo "N/A")
    
    # 결과 기록
    cat >> "${SUMMARY_FILE}" <<EOF
[${config_name}]
─────────────────────────────────────
  schbench:
    RPS: ${rps}
    Wakeup 99th: ${wakeup} usec
  
  hackbench:
    실행 시간: ${time}초
    Context switches: ${ctx}

EOF
    
    echo "  완료 - RPS: ${rps}, 시간: ${time}초"
    sleep 2
}

# 1. Baseline (기본 설정)
echo "========================================"
echo "[1/4] Baseline (기본 설정)"
run_test "Baseline" \
    "${RESULT_DIR}/baseline_schbench.txt" \
    "${RESULT_DIR}/baseline_hackbench.txt"
echo ""

# 2. Low Latency (낮은 레이턴시)
echo "========================================"
echo "[2/4] Low Latency (sched_latency_ns=3ms)"
sysctl -w kernel.sched_latency_ns=3000000 > /dev/null
run_test "Low Latency (3ms)" \
    "${RESULT_DIR}/low_latency_schbench.txt" \
    "${RESULT_DIR}/low_latency_hackbench.txt"
sysctl -w kernel.sched_latency_ns=${ORIGINAL_LATENCY} > /dev/null
echo ""

# 3. High Throughput (높은 처리량)
echo "========================================"
echo "[3/4] High Throughput (sched_latency_ns=24ms)"
sysctl -w kernel.sched_latency_ns=24000000 > /dev/null
run_test "High Throughput (24ms)" \
    "${RESULT_DIR}/high_throughput_schbench.txt" \
    "${RESULT_DIR}/high_throughput_hackbench.txt"
sysctl -w kernel.sched_latency_ns=${ORIGINAL_LATENCY} > /dev/null
echo ""

# 4. Minimal Migration (마이그레이션 최소화)
echo "========================================"
echo "[4/4] Minimal Migration (sched_migration_cost_ns=5ms)"
sysctl -w kernel.sched_migration_cost_ns=5000000 > /dev/null
run_test "Minimal Migration (5ms)" \
    "${RESULT_DIR}/minimal_migration_schbench.txt" \
    "${RESULT_DIR}/minimal_migration_hackbench.txt"
sysctl -w kernel.sched_migration_cost_ns=${ORIGINAL_MIGRATION} > /dev/null
echo ""

echo "========================================" >> "${SUMMARY_FILE}"
echo "" >> "${SUMMARY_FILE}"
echo "원본 설정으로 복원 완료" >> "${SUMMARY_FILE}"

echo "========================================"
echo "[완료] 전체 커널 튜닝 실험 완료"
echo "원본 설정으로 복원됨"
echo "결과 파일: ${SUMMARY_FILE}"
echo "========================================"

