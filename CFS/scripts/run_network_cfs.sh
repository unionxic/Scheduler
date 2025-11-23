#!/bin/bash
#
# 네트워크 벤치마크 (CFS 스케줄러)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULT_DIR="$PROJECT_DIR/results/network"

# 네트워크 설정
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
TEST_DURATION="${TEST_DURATION:-10}"

mkdir -p "$RESULT_DIR"

# iperf3 테스트 (결과: "송신Mbps 수신Mbps 재전송")
run_iperf() {
    local json=$(iperf3 -c "$TARGET_IP" -p "$TARGET_PORT" -t "$TEST_DURATION" -J 2>/dev/null) || {
        echo "0 0 0"
        return 1
    }

    local send=$(echo "$json" | grep '"bits_per_second"' | head -1 | grep -oE '[0-9]+\.[0-9]+')
    local recv=$(echo "$json" | grep '"bits_per_second"' | tail -1 | grep -oE '[0-9]+\.[0-9]+')
    local retr=$(echo "$json" | grep '"retransmits"' | tail -1 | grep -oE '[0-9]+' | tail -1)

    local send_mbps=$(echo "scale=2; ${send:-0} / 1000000" | bc 2>/dev/null || echo "0")
    local recv_mbps=$(echo "scale=2; ${recv:-0} / 1000000" | bc 2>/dev/null || echo "0")

    echo "$send_mbps $recv_mbps ${retr:-0}"
}

# 메인
echo "========================================="
echo "네트워크 벤치마크 (CFS)"
echo "========================================="
echo "대상: $TARGET_IP:$TARGET_PORT"
echo "커널: $(uname -r)"
echo ""

echo "[TCP 처리량] 측정 중 (${TEST_DURATION}초)..."
result=$(run_iperf)
send=$(echo "$result" | awk '{print $1}')
recv=$(echo "$result" | awk '{print $2}')
retr=$(echo "$result" | awk '{print $3}')

echo ""
echo "결과:"
echo "  송신: ${send} Mbps"
echo "  수신: ${recv} Mbps"
echo "  재전송: ${retr}회"

# 파일 저장
RESULT_FILE="$RESULT_DIR/network_results.txt"
cat > "$RESULT_FILE" << EOF
=========================================
네트워크 벤치마크 결과
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)
대상: $TARGET_IP:$TARGET_PORT

[TCP 처리량]
─────────────────────────────────────
  송신: ${send} Mbps
  수신: ${recv} Mbps
  재전송: ${retr}회
EOF

echo ""
echo "[완료] $RESULT_FILE"
