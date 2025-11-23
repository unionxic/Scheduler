#!/usr/bin/env bash
# EEVDF 네트워크 고급 벤치마크 - 설정별 비교

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
source "${SCRIPT_DIR}/common.sh"

# sudo 권한 확인
check_sudo "$@" || exit 1

# 환경 변수
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
PING_COUNT="${PING_COUNT:-20}"
TEST_DURATION="${TEST_DURATION:-10}"
COOLDOWN=5

# EEVDF debugfs 경로
SCHED_DEBUG="/sys/kernel/debug/sched"

# 결과 디렉토리
RESULT_DIR="${PROJECT_ROOT}/results/network"
mkdir -p "${RESULT_DIR}"

echo "========================================"
echo "EEVDF 네트워크 벤치마크 - 설정별 비교"
echo "========================================"
echo "대상: ${TARGET_IP}:${TARGET_PORT}"
echo "커널: $(uname -r)"
echo ""

# 필수 패키지 확인
check_deps() {
    local missing=()
    command -v iperf3 &>/dev/null || missing+=("iperf3")
    command -v stress-ng &>/dev/null || missing+=("stress-ng")
    command -v nc &>/dev/null || missing+=("netcat")
    command -v bc &>/dev/null || missing+=("bc")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "[오류] 필수 패키지 누락: ${missing[*]}"
        echo "설치: sudo apt install -y ${missing[*]}"
        exit 1
    fi
}

check_deps

# 원본 파라미터 백업
ORIGINAL_BASE_SLICE=$(cat ${SCHED_DEBUG}/base_slice_ns)
ORIGINAL_MIGRATION=$(cat ${SCHED_DEBUG}/migration_cost_ns)
ORIGINAL_NR_MIGRATE=$(cat ${SCHED_DEBUG}/nr_migrate)

echo "원본 파라미터:"
echo "  base_slice_ns: ${ORIGINAL_BASE_SLICE}"
echo "  migration_cost_ns: ${ORIGINAL_MIGRATION}"
echo "  nr_migrate: ${ORIGINAL_NR_MIGRATE}"
echo ""

# 복원 함수
restore_params() {
    echo ""
    echo "[복원] 원본 파라미터 복원 중..."
    echo ${ORIGINAL_BASE_SLICE} > ${SCHED_DEBUG}/base_slice_ns
    echo ${ORIGINAL_MIGRATION} > ${SCHED_DEBUG}/migration_cost_ns
    echo ${ORIGINAL_NR_MIGRATE} > ${SCHED_DEBUG}/nr_migrate
    echo "복원 완료!"
}

trap restore_params EXIT

# 네트워크 테스트 함수
run_network_test() {
    local config_name=$1

    # [1] TCP 연결 시간
    local rtt_tmp=$(mktemp)
    for i in $(seq 1 $PING_COUNT); do
        start=$(date +%s%N)
        timeout 2 bash -c "echo | nc -w1 $TARGET_IP $TARGET_PORT" &>/dev/null || true
        end=$(date +%s%N)
        ms=$(echo "scale=2; ($end - $start) / 1000000" | bc)
        echo "$ms" >> "$rtt_tmp"
    done

    local sorted_rtt=$(sort -n "$rtt_tmp")
    local total=$(wc -l < "$rtt_tmp")
    local p50_idx=$(echo "$total * 0.5 / 1" | bc)
    local p99_idx=$(echo "$total * 0.99 / 1" | bc)

    RTT_P50=$(sed -n "${p50_idx}p" <<< "$sorted_rtt")
    RTT_P99=$(sed -n "${p99_idx}p" <<< "$sorted_rtt")
    rm -f "$rtt_tmp"

    # [2] 양방향 동시 전송
    local bidir_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT --bidir -t $TEST_DURATION 2>&1) || true
    BIDIR=$(echo "$bidir_output" | grep "TX-C.*sender" | awk '{print $7}' | head -1)
    BIDIR=${BIDIR:-"N/A"}

    sleep 1

    # [3] 소형 패킷 (64B)
    local small_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT -l 64 -t $TEST_DURATION 2>&1) || true
    SMALL_PKT=$(echo "$small_output" | grep "sender" | tail -1 | awk '{print $7}')
    SMALL_PKT=${SMALL_PKT:-"N/A"}

    sleep 1

    # [4] CPU 부하 + 네트워크
    stress-ng --cpu 4 --timeout ${TEST_DURATION}s &>/dev/null &
    local stress_pid=$!
    sleep 1
    local cpu_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT -t $((TEST_DURATION - 1)) 2>&1) || true
    CPU_NET=$(echo "$cpu_output" | grep "sender" | tail -1 | awk '{print $7}')
    CPU_NET=${CPU_NET:-"N/A"}
    wait $stress_pid 2>/dev/null || true

    echo "${config_name}|${RTT_P50}|${RTT_P99}|${BIDIR}|${SMALL_PKT}|${CPU_NET}"
}

# 설정 파일 목록
CONFIG_DIR="${PROJECT_ROOT}/configs"
CONFIGS=$(ls -1 "${CONFIG_DIR}"/*.conf 2>/dev/null)
CONFIG_COUNT=$(echo "$CONFIGS" | wc -l)

echo "발견된 설정: ${CONFIG_COUNT}개"
echo ""

# 결과 파일 초기화
RESULT_FILE="${RESULT_DIR}/network_advanced_comparison.txt"
cat > "$RESULT_FILE" <<EOF
========================================
EEVDF 네트워크 벤치마크 - 설정별 비교
========================================
측정 시각: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)
대상: ${TARGET_IP}:${TARGET_PORT}

설정|RTT p50|RTT p99|양방향|소형패킷|CPU부하
---|---|---|---|---|---
EOF

# 각 설정별 테스트
idx=0
for config_file in $CONFIGS; do
    idx=$((idx + 1))
    config_name=$(basename "$config_file" .conf)

    echo "========================================"
    echo "[${idx}/${CONFIG_COUNT}] ${config_name}"
    echo "========================================"

    # 설정 로드 및 적용
    source "$config_file"
    echo "적용: base_slice=${BASE_SLICE_NS}, migration_cost=${MIGRATION_COST_NS}, nr_migrate=${NR_MIGRATE}"

    echo ${BASE_SLICE_NS} > ${SCHED_DEBUG}/base_slice_ns
    echo ${MIGRATION_COST_NS} > ${SCHED_DEBUG}/migration_cost_ns
    echo ${NR_MIGRATE} > ${SCHED_DEBUG}/nr_migrate

    sleep 2

    # 테스트 실행
    result=$(run_network_test "$config_name")
    echo "$result" >> "$RESULT_FILE"
    echo "결과: $result"
    echo ""

    if [ $idx -lt $CONFIG_COUNT ]; then
        echo "다음 테스트 준비 중... (${COOLDOWN}초 대기)"
        sleep $COOLDOWN
    fi
done

echo "========================================"
echo "[완료] 전체 설정 비교 완료!"
echo "========================================"
echo "결과: ${RESULT_FILE}"
cat "$RESULT_FILE"
