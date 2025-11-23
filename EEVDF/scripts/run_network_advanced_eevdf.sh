#!/usr/bin/env bash
# EEVDF 네트워크 고급 벤치마크

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# 환경 변수
TARGET_IP="${TARGET_IP:-223.130.152.25}"
TARGET_PORT="${TARGET_PORT:-5281}"
PING_COUNT="${PING_COUNT:-20}"
TEST_DURATION="${TEST_DURATION:-10}"

# 결과 디렉토리
RESULT_DIR="${PROJECT_ROOT}/results/network"
mkdir -p "${RESULT_DIR}"

echo "========================================"
echo "EEVDF 네트워크 고급 벤치마크"
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

# [1] TCP 연결 시간 측정 (ping 대체)
echo "[1/4] TCP 연결 시간 측정 중..."
rtt_tmp=$(mktemp)

for i in $(seq 1 $PING_COUNT); do
    start=$(date +%s%N)
    timeout 2 bash -c "echo | nc -w1 $TARGET_IP $TARGET_PORT" &>/dev/null || true
    end=$(date +%s%N)
    ms=$(echo "scale=2; ($end - $start) / 1000000" | bc)
    echo "$ms" >> "$rtt_tmp"
done

# 백분위 계산
sorted_rtt=$(sort -n "$rtt_tmp")
total=$(wc -l < "$rtt_tmp")
p50_idx=$(echo "$total * 0.5 / 1" | bc)
p90_idx=$(echo "$total * 0.9 / 1" | bc)
p99_idx=$(echo "$total * 0.99 / 1" | bc)

RTT_P50=$(sed -n "${p50_idx}p" <<< "$sorted_rtt")
RTT_P90=$(sed -n "${p90_idx}p" <<< "$sorted_rtt")
RTT_P99=$(sed -n "${p99_idx}p" <<< "$sorted_rtt")

echo "  p50: ${RTT_P50}ms, p90: ${RTT_P90}ms, p99: ${RTT_P99}ms"
rm -f "$rtt_tmp"

# [2] 양방향 동시 전송
echo "[2/4] 양방향 동시 전송 테스트 중..."
bidir_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT --bidir -t $TEST_DURATION 2>&1) || true
BIDIR_SEND=$(echo "$bidir_output" | grep "TX-C.*sender" | awk '{print $7}' | head -1)
BIDIR_RECV=$(echo "$bidir_output" | grep "RX-C.*sender" | awk '{print $7}' | head -1)
BIDIR_SEND=${BIDIR_SEND:-"N/A"}
BIDIR_RECV=${BIDIR_RECV:-"N/A"}
echo "  송신: ${BIDIR_SEND} Mbps, 수신: ${BIDIR_RECV} Mbps"

sleep 2

# [3] 소형 패킷 (64B)
echo "[3/4] 소형 패킷 (64B) 테스트 중..."
small_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT -l 64 -t $TEST_DURATION 2>&1) || true
SMALL_PKT=$(echo "$small_output" | grep "sender" | tail -1 | awk '{print $7}')
SMALL_PKT=${SMALL_PKT:-"N/A"}
echo "  처리량: ${SMALL_PKT} Mbps"

sleep 2

# [4] CPU 부하 + 네트워크
echo "[4/4] CPU 부하 + 네트워크 테스트 중..."
stress-ng --cpu 4 --timeout ${TEST_DURATION}s &>/dev/null &
stress_pid=$!
sleep 1

cpu_output=$(iperf3 -c $TARGET_IP -p $TARGET_PORT -t $((TEST_DURATION - 1)) 2>&1) || true
CPU_NET=$(echo "$cpu_output" | grep "sender" | tail -1 | awk '{print $7}')
CPU_NET=${CPU_NET:-"N/A"}

wait $stress_pid 2>/dev/null || true
echo "  처리량: ${CPU_NET} Mbps"

# 결과 저장
RESULT_FILE="${RESULT_DIR}/network_advanced_results.txt"
cat > "$RESULT_FILE" <<EOF
========================================
EEVDF 네트워크 고급 벤치마크 결과
========================================
측정 시각: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)
대상: ${TARGET_IP}:${TARGET_PORT}

[1] TCP 연결 시간
  p50: ${RTT_P50} ms
  p90: ${RTT_P90} ms
  p99: ${RTT_P99} ms

[2] 양방향 동시 전송
  송신: ${BIDIR_SEND} Mbps
  수신: ${BIDIR_RECV} Mbps

[3] 소형 패킷 (64B)
  처리량: ${SMALL_PKT} Mbps

[4] CPU 부하 + 네트워크
  처리량: ${CPU_NET} Mbps
========================================
EOF

echo ""
echo "[완료] 결과 저장: ${RESULT_FILE}"
