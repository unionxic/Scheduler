#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "사용법: $0 <config_file>"
    echo ""
    echo "예시:"
    echo "  $0 configs/low_latency.conf"
    echo "  $0 configs/high_throughput.conf"
    echo ""
    echo "사용 가능한 설정:"
    ls -1 configs/*.conf 2>/dev/null | sed 's/^/  /'
    exit 1
fi

CONFIG_FILE=$1

if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[오류] 설정 파일을 찾을 수 없습니다: ${CONFIG_FILE}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

echo "========================================="
echo "커널 파라미터 설정 적용"
echo "========================================="
echo "설정 파일: ${CONFIG_FILE}"
echo ""

source "${CONFIG_FILE}"

echo "적용할 파라미터:"
echo "  sched_latency_ns: ${SCHED_LATENCY_NS}"
echo "  sched_min_granularity_ns: ${SCHED_MIN_GRANULARITY_NS}"
echo "  sched_wakeup_granularity_ns: ${SCHED_WAKEUP_GRANULARITY_NS}"
echo "  sched_migration_cost_ns: ${SCHED_MIGRATION_COST_NS}"
echo ""
echo "설명: ${DESCRIPTION}"
echo ""

SUDO_PASS="1234"

ORIGINAL_LATENCY=$(echo "${SUDO_PASS}" | sudo -S cat /sys/kernel/debug/sched/latency_ns 2>/dev/null)
ORIGINAL_MIN_GRAN=$(echo "${SUDO_PASS}" | sudo -S cat /sys/kernel/debug/sched/min_granularity_ns 2>/dev/null)
ORIGINAL_WAKEUP_GRAN=$(echo "${SUDO_PASS}" | sudo -S cat /sys/kernel/debug/sched/wakeup_granularity_ns 2>/dev/null)
ORIGINAL_MIGRATION=$(echo "${SUDO_PASS}" | sudo -S cat /sys/kernel/debug/sched/migration_cost_ns 2>/dev/null)

restore_params() {
    echo ""
    echo "[정보] 원본 파라미터 복원 중..."
    echo "${SUDO_PASS}" | sudo -S bash -c "echo ${ORIGINAL_LATENCY} > /sys/kernel/debug/sched/latency_ns" 2>/dev/null || true
    echo "${SUDO_PASS}" | sudo -S bash -c "echo ${ORIGINAL_MIN_GRAN} > /sys/kernel/debug/sched/min_granularity_ns" 2>/dev/null || true
    echo "${SUDO_PASS}" | sudo -S bash -c "echo ${ORIGINAL_WAKEUP_GRAN} > /sys/kernel/debug/sched/wakeup_granularity_ns" 2>/dev/null || true
    echo "${SUDO_PASS}" | sudo -S bash -c "echo ${ORIGINAL_MIGRATION} > /sys/kernel/debug/sched/migration_cost_ns" 2>/dev/null || true
    echo "[정보] 원본 파라미터 복원 완료"
}

trap restore_params EXIT

echo "[정보] 커널 파라미터 적용 중..."
echo "${SUDO_PASS}" | sudo -S bash -c "echo ${SCHED_LATENCY_NS} > /sys/kernel/debug/sched/latency_ns"
echo "${SUDO_PASS}" | sudo -S bash -c "echo ${SCHED_MIN_GRANULARITY_NS} > /sys/kernel/debug/sched/min_granularity_ns"
echo "${SUDO_PASS}" | sudo -S bash -c "echo ${SCHED_WAKEUP_GRANULARITY_NS} > /sys/kernel/debug/sched/wakeup_granularity_ns"
echo "${SUDO_PASS}" | sudo -S bash -c "echo ${SCHED_MIGRATION_COST_NS} > /sys/kernel/debug/sched/migration_cost_ns"
echo "[정보] 커널 파라미터 적용 완료"
echo ""

CONFIG_NAME=$(basename "${CONFIG_FILE}" .conf)
export BENCH_CONFIG_NAME="${CONFIG_NAME}"

echo "========================================="
echo "벤치마크 실행 시작"
echo "========================================="
echo ""

"${SCRIPT_DIR}/run_all_cfs.sh" --basic

echo ""
echo "========================================="
echo "벤치마크 완료"
echo "========================================="

