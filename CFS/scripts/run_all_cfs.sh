#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

echo "========================================="
echo "CFS 스케줄러 종합 벤치마크 실험"
echo "========================================="
echo ""

BASIC_ONLY=false
if [ "${1:-}" = "--basic" ]; then
    BASIC_ONLY=true
    echo "[모드] 기본 벤치마크만 실행"
else
    echo "[모드] 전체 벤치마크 실행 (--basic 옵션으로 기본만 실행 가능)"
fi
echo ""

echo "[1/3] schbench 레이턴시 테스트"
"${SCRIPT_DIR}/run_schbench_cfs.sh"
echo ""

echo "[2/3] hackbench 처리량 테스트"
"${SCRIPT_DIR}/run_hackbench_cfs.sh"
echo ""

if [ "${BASIC_ONLY}" = false ]; then
    echo "[3/3] 워크로드 시나리오 테스트"
    "${SCRIPT_DIR}/run_workload_scenarios.sh"
    echo ""
fi

echo "========================================="
echo "전체 실험 완료"
echo "========================================="
echo ""
echo "결과 파일:"
echo "  - results/schbench/schbench_results.txt"
echo "  - results/hackbench/hackbench_results.txt"
if [ "${BASIC_ONLY}" = false ]; then
    echo "  - results/workload_scenarios/workload_results.txt"
fi
echo ""
echo "💡 팁: 커널 파라미터 조정 실험은 다음 명령어로 실행:"
echo "   ./scripts/run_with_config.sh configs/low_latency.conf"
echo "   ./scripts/run_all_configs.sh  # 모든 설정 자동 비교"
echo ""
