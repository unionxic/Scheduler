#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [ ! -x "${SCHBENCH_BIN}" ]; then
    echo "[정보] schbench 빌드 중..."
    SCHBENCH_DIR="${PROJECT_ROOT}/benchmarks/schbench"
    
    [ ! -d "${SCHBENCH_DIR}" ] && {
        mkdir -p "${PROJECT_ROOT}/benchmarks"
        cd "${PROJECT_ROOT}/benchmarks"
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/mason/schbench.git
    }
    
    cd "${SCHBENCH_DIR}" && make
    [ ! -x "${SCHBENCH_BIN}" ] && { echo "[오류] schbench 빌드 실패"; exit 1; }
    echo "[정보] schbench 빌드 완료"
fi

RESULT_DIR="${PROJECT_ROOT}/results/schbench"
mkdir -p "${RESULT_DIR}"

echo "[실행] schbench 다중 스레드 테스트 (커널: $(uname -r))"
echo ""

# 통합 결과 파일 초기화
SUMMARY_FILE="${RESULT_DIR}/schbench_results.txt"
cat > "${SUMMARY_FILE}" <<EOF
========================================
schbench 레이턴시 벤치마크 결과 (EEVDF)
========================================
스케줄러: EEVDF
커널: $(uname -r)
측정 시각: $(date '+%Y-%m-%d %H:%M:%S')
실행 시간: 30초/테스트

EOF

for THREADS in 4 6 8; do
    echo "========================================"
    echo "[${THREADS}개 스레드] 테스트 중..."
    
    RAW_FILE="${RESULT_DIR}/raw_${THREADS}threads.txt"
    "${SCHBENCH_BIN}" -m ${THREADS} -t 5 -s 128 > "${RAW_FILE}" 2>&1
    
    RESULT=$(parse_schbench_result "${RAW_FILE}")
    AVG_RPS=$(echo "$RESULT" | cut -d'|' -f1)
    WAKEUP_99=$(echo "$RESULT" | cut -d'|' -f2)
    REQUEST_99=$(echo "$RESULT" | cut -d'|' -f3)
    
    # 통합 결과에 추가
    cat >> "${SUMMARY_FILE}" <<EOF
[${THREADS}개 스레드]
  - 평균 RPS: ${AVG_RPS}
  - Wakeup 99th: ${WAKEUP_99} usec
  - Request 99th: ${REQUEST_99} usec

EOF
    
    echo "[${THREADS}개 스레드] 완료"
    echo "  - 평균 RPS: ${AVG_RPS}"
    echo ""
done

echo "========================================" >> "${SUMMARY_FILE}"
echo "상세 로그: raw_4threads.txt, raw_6threads.txt, raw_8threads.txt" >> "${SUMMARY_FILE}"

echo "========================================"
echo "[완료] 전체 schbench 테스트 완료"
echo "결과 파일: ${SUMMARY_FILE}"
echo "========================================"

