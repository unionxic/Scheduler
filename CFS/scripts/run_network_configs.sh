#!/bin/bash
#
# 설정별 네트워크 벤치마크 비교
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configs"
RESULT_DIR="$PROJECT_DIR/results/network"

# 네트워크 설정
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
TEST_DURATION="${TEST_DURATION:-10}"
COOLDOWN=3

mkdir -p "$RESULT_DIR"

# sudo 비밀번호
SUDO_PASS="1234"

# debugfs 경로
SCHED_DEBUG="/sys/kernel/debug/sched"

# 원본 파라미터 저장/복원
declare -g ORIG_PARAMS=""
save_params() {
    ORIG_PARAMS=$(echo "$SUDO_PASS" | sudo -S cat "$SCHED_DEBUG/latency_ns" 2>/dev/null)
    ORIG_PARAMS+=" $(echo "$SUDO_PASS" | sudo -S cat "$SCHED_DEBUG/min_granularity_ns" 2>/dev/null)"
    ORIG_PARAMS+=" $(echo "$SUDO_PASS" | sudo -S cat "$SCHED_DEBUG/wakeup_granularity_ns" 2>/dev/null)"
    ORIG_PARAMS+=" $(echo "$SUDO_PASS" | sudo -S cat "$SCHED_DEBUG/migration_cost_ns" 2>/dev/null)"
}

restore_params() {
    local params=($ORIG_PARAMS)
    echo "$SUDO_PASS" | sudo -S bash -c "echo ${params[0]} > $SCHED_DEBUG/latency_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo ${params[1]} > $SCHED_DEBUG/min_granularity_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo ${params[2]} > $SCHED_DEBUG/wakeup_granularity_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo ${params[3]} > $SCHED_DEBUG/migration_cost_ns" 2>/dev/null
    echo "[복원] 완료"
}

apply_config() {
    source "$1"
    echo "$SUDO_PASS" | sudo -S bash -c "echo $SCHED_LATENCY_NS > $SCHED_DEBUG/latency_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo $SCHED_MIN_GRANULARITY_NS > $SCHED_DEBUG/min_granularity_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo $SCHED_WAKEUP_GRANULARITY_NS > $SCHED_DEBUG/wakeup_granularity_ns" 2>/dev/null
    echo "$SUDO_PASS" | sudo -S bash -c "echo $SCHED_MIGRATION_COST_NS > $SCHED_DEBUG/migration_cost_ns" 2>/dev/null
}

# iperf3 테스트
run_iperf() {
    local json=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -t "$TEST_DURATION" -J 2>/dev/null) || {
        echo "0 0"
        return 1
    }
    local send=$(echo "$json" | grep '"bits_per_second"' | head -1 | grep -oE '[0-9]+\.[0-9]+')
    local retr=$(echo "$json" | grep '"retransmits"' | tail -1 | grep -oE '[0-9]+' | tail -1)
    local mbps=$(echo "scale=2; ${send:-0} / 1000000" | bc 2>/dev/null || echo "0")
    echo "$mbps ${retr:-0}"
}

# 메인
echo "========================================="
echo "설정별 네트워크 벤치마크"
echo "========================================="
echo "대상: $TARGET_IP:$TARGET_PORT"
echo "커널: $(uname -r)"
echo ""

save_params
trap restore_params EXIT

# 설정 파일 카운트
configs=("$CONFIG_DIR"/*.conf)
total=${#configs[@]}
current=0

# 결과 저장
declare -A RESULTS
RESULT_FILE="$RESULT_DIR/network_comparison.txt"

{
    echo "========================================="
    echo "설정별 네트워크 벤치마크"
    echo "========================================="
    echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "커널: $(uname -r)"
    echo "대상: $TARGET_IP:$TARGET_PORT"
    echo ""
} > "$RESULT_FILE"

# 각 설정 테스트
for conf in "${configs[@]}"; do
    [ -f "$conf" ] || continue
    name=$(basename "$conf" .conf)
    current=$((current + 1))

    echo "[$current/$total] $name"
    apply_config "$conf"
    sleep 1

    result=$(run_iperf)
    mbps=$(echo "$result" | awk '{print $1}')
    retr=$(echo "$result" | awk '{print $2}')
    RESULTS["$name"]="$mbps $retr"

    echo "  → ${mbps} Mbps (재전송: ${retr})"
    echo "[$name] ${mbps} Mbps, 재전송: ${retr}회" >> "$RESULT_FILE"

    sleep "$COOLDOWN"
done

# 요약
{
    echo ""
    echo "========================================="
    echo "요약 (처리량 순)"
    echo "========================================="
    for name in "${!RESULTS[@]}"; do
        mbps=$(echo "${RESULTS[$name]}" | awk '{print $1}')
        retr=$(echo "${RESULTS[$name]}" | awk '{print $2}')
        echo "$name: ${mbps} Mbps (재전송: ${retr})"
    done | sort -t: -k2 -rn
} >> "$RESULT_FILE"

echo ""
echo "[완료] $RESULT_FILE"
