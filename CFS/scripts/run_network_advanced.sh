#!/bin/bash
#
# 고급 네트워크 벤치마크 (CFS vs EEVDF 비교용)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULT_DIR="$PROJECT_DIR/results/network"

# 네트워크 설정
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
PING_COUNT="${PING_COUNT:-20}"
TEST_DURATION="${TEST_DURATION:-10}"

mkdir -p "$RESULT_DIR"

# sudo 비밀번호 (hping3용)
SUDO_PASS="1234"

RESULT_FILE="$RESULT_DIR/network_advanced_results.txt"

# 퍼센타일 계산 함수
calc_percentile() {
    local file=$1
    local pct=$2
    local count=$(wc -l < "$file")
    local idx=$(echo "scale=0; ($count * $pct + 99) / 100" | bc)
    sed -n "${idx}p" "$file"
}

echo "========================================="
echo "고급 네트워크 벤치마크"
echo "========================================="
echo "대상: $TARGET_IP:$TARGET_PORT"
echo "커널: $(uname -r)"
echo ""

{
    echo "========================================="
    echo "고급 네트워크 벤치마크"
    echo "========================================="
    echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "커널: $(uname -r)"
    echo "대상: $TARGET_IP:$TARGET_PORT"
    echo ""
} > "$RESULT_FILE"

# =========================================
# 1. TCP 연결 시간 분포 (nc 기반)
# =========================================
echo "[1/5] TCP 연결 시간 측정 (${PING_COUNT}회)..."

rtt_tmp=$(mktemp)

for i in $(seq 1 $PING_COUNT); do
    start=$(date +%s%N)
    timeout 2 bash -c "echo | nc -w1 $TARGET_IP $TARGET_PORT" &>/dev/null || true
    end=$(date +%s%N)
    ms=$(echo "scale=2; ($end - $start) / 1000000" | bc 2>/dev/null || echo "0")
    echo "$ms" >> "$rtt_tmp"
done
sort -n "$rtt_tmp" -o "$rtt_tmp"

if [ -s "$rtt_tmp" ]; then
    p50=$(calc_percentile "$rtt_tmp" 50)
    p90=$(calc_percentile "$rtt_tmp" 90)
    p99=$(calc_percentile "$rtt_tmp" 99)
    p999=$(calc_percentile "$rtt_tmp" 100)
    avg=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "$rtt_tmp")

    echo "  평균: ${avg}ms, p50: ${p50}ms, p90: ${p90}ms, p99: ${p99}ms"

    {
        echo "[1] TCP 연결 시간 분포"
        echo "─────────────────────────────────────"
        echo "  평균:  ${avg} ms"
        echo "  p50:   ${p50} ms"
        echo "  p90:   ${p90} ms"
        echo "  p99:   ${p99} ms"
        echo ""
    } >> "$RESULT_FILE"
else
    echo "  [실패] RTT 테스트 실패"
fi
rm -f "$rtt_tmp"

# =========================================
# 2. 양방향 동시 전송
# =========================================
echo "[2/4] 양방향 동시 전송 측정..."

bidir_output=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" --bidir -t "$TEST_DURATION" 2>&1) || bidir_output=""

if echo "$bidir_output" | grep -q "sender"; then
    # 텍스트 출력에서 파싱
    send_mbps=$(echo "$bidir_output" | grep "TX-C.*sender" | awk '{print $7}')
    recv_mbps=$(echo "$bidir_output" | grep "RX-C.*sender" | awk '{print $7}')

    echo "  송신: ${send_mbps:-0} Mbps, 수신: ${recv_mbps:-0} Mbps"

    {
        echo "[3] 양방향 동시 전송"
        echo "─────────────────────────────────────"
        echo "  송신: ${send_mbps:-0} Mbps"
        echo "  수신: ${recv_mbps:-0} Mbps"
        echo ""
    } >> "$RESULT_FILE"
else
    echo "  [실패] 양방향 테스트 실패"
fi

# =========================================
# 3. 소형 패킷 성능 (64byte)
# =========================================
echo "[3/4] 소형 패킷 성능 측정 (64byte)..."

small_output=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -l 64 -t "$TEST_DURATION" 2>&1) || small_output=""

if echo "$small_output" | grep -q "sender"; then
    small_mbps=$(echo "$small_output" | grep "sender" | awk '{print $7}')
    retrans=$(echo "$small_output" | grep "sender" | awk '{print $9}')

    echo "  처리량: ${small_mbps:-0} Mbps, 재전송: ${retrans:-0}회"

    {
        echo "[4] 소형 패킷 성능 (64byte)"
        echo "─────────────────────────────────────"
        echo "  처리량: ${small_mbps:-0} Mbps"
        echo "  재전송: ${retrans:-0}회"
        echo ""
    } >> "$RESULT_FILE"
else
    echo "  [실패] 소형 패킷 테스트 실패"
fi

# =========================================
# 4. CPU 부하 + 네트워크 복합
# =========================================
echo "[4/4] CPU 부하 + 네트워크 복합 측정..."

# stress-ng 있는지 확인
if command -v stress-ng &>/dev/null; then
    # CPU 부하 백그라운드 실행
    stress-ng --cpu 4 --timeout ${TEST_DURATION}s &>/dev/null &
    stress_pid=$!
    sleep 1

    load_result=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -t "$((TEST_DURATION - 2))" -J 2>/dev/null) || load_result=""

    # stress-ng 종료 대기
    wait $stress_pid 2>/dev/null || true

    if [ -n "$load_result" ]; then
        load_bps=$(echo "$load_result" | grep '"bits_per_second"' | tail -1 | grep -oE '[0-9]+\.[0-9]+')
        load_mbps=$(echo "scale=2; ${load_bps:-0} / 1000000" | bc 2>/dev/null || echo "0")
        load_retrans=$(echo "$load_result" | grep '"retransmits"' | tail -1 | grep -oE '[0-9]+' | tail -1)

        echo "  처리량: ${load_mbps} Mbps, 재전송: ${load_retrans:-0}회 (CPU 4코어 부하 중)"

        {
            echo "[5] CPU 부하 + 네트워크 복합"
            echo "─────────────────────────────────────"
            echo "  CPU 부하: 4코어 stress-ng"
            echo "  처리량:   ${load_mbps} Mbps"
            echo "  재전송:   ${load_retrans:-0}회"
            echo ""
        } >> "$RESULT_FILE"
    else
        echo "  [실패] 복합 테스트 실패"
    fi
else
    echo "  [건너뜀] stress-ng 미설치 (sudo apt install stress-ng)"
    {
        echo "[5] CPU 부하 + 네트워크 복합"
        echo "─────────────────────────────────────"
        echo "  [건너뜀] stress-ng 미설치"
        echo ""
    } >> "$RESULT_FILE"
fi

echo ""
echo "========================================="
echo "[완료] $RESULT_FILE"
echo "========================================="
