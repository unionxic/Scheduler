#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

check_hackbench || exit 1

RESULT_DIR="${PROJECT_ROOT}/results/hackbench"
mkdir -p "${RESULT_DIR}"

echo "[실행] hackbench 다중 그룹 테스트 (커널: $(uname -r))"
echo ""

# 통합 결과 파일 초기화
SUMMARY_FILE="${RESULT_DIR}/hackbench_results.txt"
cat > "${SUMMARY_FILE}" <<EOF
========================================
hackbench 처리량 벤치마크 결과 (EEVDF)
========================================
스케줄러: EEVDF
커널: $(uname -r)
측정 시각: $(date '+%Y-%m-%d %H:%M:%S')
루프 수: ${HACKBENCH_LOOPS}
데이터 크기: ${HACKBENCH_DATASIZE} bytes

EOF

for NUM_GROUPS in 4 6 8; do
    echo "========================================"
    echo "[${NUM_GROUPS}개 그룹] 테스트 중..."
    
    RAW_FILE="${RESULT_DIR}/raw_${NUM_GROUPS}groups.txt"
    perf stat -e task-clock,context-switches,cpu-migrations,page-faults \
        /usr/bin/time -v "${HACKBENCH_BIN}" -l ${HACKBENCH_LOOPS} -g ${NUM_GROUPS} -s ${HACKBENCH_DATASIZE} -P \
        > "${RAW_FILE}" 2>&1 || true
    
    RESULT=$(parse_hackbench_result "${RAW_FILE}")
    EXEC_TIME=$(echo "$RESULT" | cut -d'|' -f1)
    CTX_SW=$(echo "$RESULT" | cut -d'|' -f2)
    CPU_MIG=$(echo "$RESULT" | cut -d'|' -f3)
    PAGE_FAULTS=$(echo "$RESULT" | cut -d'|' -f4)
    
    # 통합 결과에 추가
    cat >> "${SUMMARY_FILE}" <<EOF
[${NUM_GROUPS}개 그룹]
  - 실행 시간: ${EXEC_TIME}초
  - Context switches: ${CTX_SW}
  - CPU migrations: ${CPU_MIG}
  - Page faults: ${PAGE_FAULTS}

EOF
    
    echo "[${NUM_GROUPS}개 그룹] 완료"
    echo "  - 실행 시간: ${EXEC_TIME}초"
    echo "  - Context switches: ${CTX_SW}"
    echo ""
done

echo "========================================" >> "${SUMMARY_FILE}"
echo "상세 로그: raw_4groups.txt, raw_6groups.txt, raw_8groups.txt" >> "${SUMMARY_FILE}"

echo "========================================"
echo "[완료] 전체 hackbench 테스트 완료"
echo "결과 파일: ${SUMMARY_FILE}"
echo "========================================"

