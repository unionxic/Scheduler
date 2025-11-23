#!/bin/bash
#
# 설정별 고급 네트워크 벤치마크 (CFS vs EEVDF 비교용)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/configs"
RESULT_DIR="$PROJECT_DIR/results/network"

# sudo 비밀번호
SUDO_PASS="1234"

# debugfs 경로
SCHED_DEBUG="/sys/kernel/debug/sched"

# 네트워크 설정
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
PING_COUNT="${PING_COUNT:-100}"
TEST_DURATION="${TEST_DURATION:-10}"
COOLDOWN=5

mkdir -p "$RESULT_DIR"

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

# 퍼센타일 계산
calc_percentile() {
    local file=$1
    local pct=$2
    local count=$(wc -l < "$file")
    local idx=$(echo "scale=0; ($count * $pct + 99) / 100" | bc)
    sed -n "${idx}p" "$file"
}

# 단일 설정 테스트
run_tests() {
    local config_name=$1

    # 1. TCP 연결 시간
    local rtt_tmp=$(mktemp)
    for i in $(seq 1 $PING_COUNT); do
        local start=$(date +%s%N)
        timeout 2 bash -c "echo | nc -w1 $TARGET_IP $TARGET_PORT" &>/dev/null || true
        local end=$(date +%s%N)
        echo "scale=2; ($end - $start) / 1000000" | bc >> "$rtt_tmp" 2>/dev/null
    done
    sort -n "$rtt_tmp" -o "$rtt_tmp"

    local p50="" p99=""
    if [ -s "$rtt_tmp" ]; then
        p50=$(calc_percentile "$rtt_tmp" 50)
        p99=$(calc_percentile "$rtt_tmp" 99)
    fi
    rm -f "$rtt_tmp"

    # 2. 양방향
    local bidir_output=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" --bidir -t "$TEST_DURATION" 2>&1) || bidir_output=""
    local bidir_send_mbps=$(echo "$bidir_output" | grep "TX-C.*sender" | awk '{print $7}')

    # 3. 소형 패킷
    local small_output=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -l 64 -t "$TEST_DURATION" 2>&1) || small_output=""
    local small_mbps=$(echo "$small_output" | grep "sender" | awk '{print $7}')

    # 4. CPU 부하
    local load_mbps="N/A"
    if command -v stress-ng &>/dev/null; then
        stress-ng --cpu 4 --timeout ${TEST_DURATION}s &>/dev/null &
        local stress_pid=$!
        sleep 1
        local load_output=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -t "$((TEST_DURATION - 2))" 2>&1) || load_output=""
        wait $stress_pid 2>/dev/null || true
        load_mbps=$(echo "$load_output" | grep "sender" | awk '{print $7}')
    fi

    echo "${config_name}|${p50:-N/A}|${p99:-N/A}|${bidir_send_mbps:-0}|${small_mbps:-0}|${load_mbps:-0}"
}

# 메인
echo "========================================="
echo "설정별 고급 네트워크 벤치마크"
echo "========================================="
echo "대상: $TARGET_IP:$TARGET_PORT"
echo "커널: $(uname -r)"
echo ""

save_params
trap restore_params EXIT

RESULT_FILE="$RESULT_DIR/network_advanced_comparison.txt"

{
    echo "========================================="
    echo "설정별 고급 네트워크 벤치마크"
    echo "========================================="
    echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "커널: $(uname -r)"
    echo "대상: $TARGET_IP:$TARGET_PORT"
    echo ""
    echo "설정|RTT p50|RTT p99|양방향|소형패킷|CPU부하"
    echo "---|---|---|---|---|---"
} > "$RESULT_FILE"

configs=("$CONFIG_DIR"/*.conf)
total=${#configs[@]}
current=0

declare -A RESULTS

for conf in "${configs[@]}"; do
    [ -f "$conf" ] || continue
    name=$(basename "$conf" .conf)
    current=$((current + 1))

    echo "[$current/$total] $name 테스트 중..."
    apply_config "$conf"
    sleep 2

    result=$(run_tests "$name")
    RESULTS["$name"]="$result"
    echo "$result" >> "$RESULT_FILE"

    echo "  완료"
    sleep "$COOLDOWN"
done

echo ""
echo "========================================="
echo "결과 요약"
echo "========================================="

{
    echo ""
    echo "========================================="
    echo "요약"
    echo "========================================="
} >> "$RESULT_FILE"

for name in "${!RESULTS[@]}"; do
    IFS='|' read -r _ p50 p99 bidir small load <<< "${RESULTS[$name]}"
    echo "$name: RTT p99=${p99}ms, 양방향=${bidir}Mbps, CPU부하=${load}Mbps"
    echo "$name: RTT p99=${p99}ms, 양방향=${bidir}Mbps, CPU부하=${load}Mbps" >> "$RESULT_FILE"
done

echo ""
echo "[완료] $RESULT_FILE"
