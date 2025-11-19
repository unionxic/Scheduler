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

ORIGINAL_LATENCY=$(cat /proc/sys/kernel/sched_latency_ns)
ORIGINAL_MIN_GRAN=$(cat /proc/sys/kernel/sched_min_granularity_ns)
ORIGINAL_WAKEUP_GRAN=$(cat /proc/sys/kernel/sched_wakeup_granularity_ns)
ORIGINAL_MIGRATION=$(cat /proc/sys/kernel/sched_migration_cost_ns)

restore_params() {
    echo ""
    echo "[정보] 원본 파라미터 복원 중..."
    sudo sysctl -w kernel.sched_latency_ns=${ORIGINAL_LATENCY} > /dev/null 2>&1 || true
    sudo sysctl -w kernel.sched_min_granularity_ns=${ORIGINAL_MIN_GRAN} > /dev/null 2>&1 || true
    sudo sysctl -w kernel.sched_wakeup_granularity_ns=${ORIGINAL_WAKEUP_GRAN} > /dev/null 2>&1 || true
    sudo sysctl -w kernel.sched_migration_cost_ns=${ORIGINAL_MIGRATION} > /dev/null 2>&1 || true
    echo "[정보] 원본 파라미터 복원 완료"
}

trap restore_params EXIT

echo "[정보] 커널 파라미터 적용 중..."
sudo sysctl -w kernel.sched_latency_ns=${SCHED_LATENCY_NS} > /dev/null
sudo sysctl -w kernel.sched_min_granularity_ns=${SCHED_MIN_GRANULARITY_NS} > /dev/null
sudo sysctl -w kernel.sched_wakeup_granularity_ns=${SCHED_WAKEUP_GRANULARITY_NS} > /dev/null
sudo sysctl -w kernel.sched_migration_cost_ns=${SCHED_MIGRATION_COST_NS} > /dev/null
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

