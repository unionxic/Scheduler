#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

# --basic 옵션 확인
BASIC_ONLY=false
if [ "${1:-}" == "--basic" ]; then
    BASIC_ONLY=true
fi

START_TIME=$(date +%s)

if [ "$BASIC_ONLY" = true ]; then
    echo "========================================="
    echo "EEVDF 스케줄러 벤치마크 (기본)"
    echo "========================================="
    echo ""
    
    echo "[1/2] schbench 레이턴시 테스트"
    "${SCRIPT_DIR}/run_schbench_eevdf.sh"
    
    echo ""
    echo "[2/2] hackbench 처리량 테스트"
    "${SCRIPT_DIR}/run_hackbench_eevdf.sh"
else
    echo "========================================="
    echo "EEVDF 스케줄러 벤치마크 (전체)"
    echo "========================================="
    echo ""
    
    echo "[1/4] schbench 레이턴시 테스트"
    "${SCRIPT_DIR}/run_schbench_eevdf.sh"
    
    echo ""
    echo "[2/4] hackbench 처리량 테스트"
    "${SCRIPT_DIR}/run_hackbench_eevdf.sh"
    
    echo ""
    echo "[3/4] 워크로드 시나리오 테스트"
    "${SCRIPT_DIR}/run_workload_scenarios_eevdf.sh"
    
    echo ""
    echo "[4/4] 커널 파라미터 조정 실험"
    if [ "$EUID" -ne 0 ]; then
        echo "[건너뜀] sudo 권한 필요 - 수동 실행: sudo ./scripts/run_kernel_tuning_eevdf.sh"
    else
        "${SCRIPT_DIR}/run_kernel_tuning_eevdf.sh"
    fi
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo "========================================="
echo "전체 실험 완료"
echo "========================================="

# 종합 보고서 생성
REPORT_FILE="${PROJECT_ROOT}/results/BENCHMARK_REPORT.txt"

if [ "$BASIC_ONLY" = true ]; then
    cat > "${REPORT_FILE}" <<EOF
================================================================
EEVDF 스케줄러 벤치마크 종합 보고서 (기본)
================================================================
스케줄러: EEVDF
커널 버전: $(uname -r)
측정 일시: $(date '+%Y-%m-%d %H:%M:%S')
총 소요 시간: ${ELAPSED}초

================================================================
1. schbench 레이턴시 테스트 결과
================================================================

$(cat "${PROJECT_ROOT}/results/schbench/schbench_results.txt")

================================================================
2. hackbench 처리량 테스트 결과
================================================================

$(cat "${PROJECT_ROOT}/results/hackbench/hackbench_results.txt")

================================================================
결과 파일 위치
================================================================
- 종합 보고서: results/BENCHMARK_REPORT.txt
- schbench 결과: results/schbench/schbench_results.txt
- hackbench 결과: results/hackbench/hackbench_results.txt
- 상세 로그: results/schbench/raw_*.txt, results/hackbench/raw_*.txt
================================================================
EOF
else
    cat > "${REPORT_FILE}" <<EOF
================================================================
EEVDF 스케줄러 벤치마크 종합 보고서 (전체)
================================================================
스케줄러: EEVDF
커널 버전: $(uname -r)
측정 일시: $(date '+%Y-%m-%d %H:%M:%S')
총 소요 시간: ${ELAPSED}초

================================================================
1. schbench 레이턴시 테스트 결과
================================================================

$(cat "${PROJECT_ROOT}/results/schbench/schbench_results.txt")

================================================================
2. hackbench 처리량 테스트 결과
================================================================

$(cat "${PROJECT_ROOT}/results/hackbench/hackbench_results.txt")

================================================================
3. 워크로드 시나리오 테스트 결과
================================================================

$(cat "${PROJECT_ROOT}/results/workload_scenarios/workload_results.txt" 2>/dev/null || echo "워크로드 테스트 결과 없음")

================================================================
4. 커널 파라미터 조정 실험 결과
================================================================

$(cat "${PROJECT_ROOT}/results/kernel_tuning/tuning_results.txt" 2>/dev/null || echo "커널 튜닝 결과 없음 (sudo 권한 필요)")

================================================================
결과 파일 위치
================================================================
- 종합 보고서: results/BENCHMARK_REPORT.txt
- schbench 결과: results/schbench/schbench_results.txt
- hackbench 결과: results/hackbench/hackbench_results.txt
- 워크로드 시나리오: results/workload_scenarios/workload_results.txt
- 커널 튜닝: results/kernel_tuning/tuning_results.txt
- 상세 로그: results/*/raw_*.txt
================================================================
EOF
fi

echo ""
echo "종합 보고서 생성 완료: ${REPORT_FILE}"
echo ""

