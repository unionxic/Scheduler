#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
CONFIGS_DIR="${PROJECT_ROOT}/configs"
RESULT_DIR="${PROJECT_ROOT}/results/config_comparison"

mkdir -p "${RESULT_DIR}"

echo "========================================="
echo "전체 설정 파일 자동 벤치마크"
echo "========================================="
echo "일시: $(date '+%Y-%m-%d %H:%M:%S')"
echo "커널: $(uname -r)"
echo ""

if [ ! -d "${CONFIGS_DIR}" ] || [ -z "$(ls -A ${CONFIGS_DIR}/*.conf 2>/dev/null)" ]; then
    echo "[오류] configs 디렉토리에 설정 파일이 없습니다"
    exit 1
fi

CONFIG_FILES=(${CONFIGS_DIR}/*.conf)
TOTAL=${#CONFIG_FILES[@]}
CURRENT=0

cat > "${RESULT_DIR}/comparison_results.txt" <<EOF
=========================================
설정별 성능 비교 결과
=========================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)

EOF

for config in "${CONFIG_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    CONFIG_NAME=$(basename "${config}" .conf)
    
    echo "========================================="
    echo "[${CURRENT}/${TOTAL}] ${CONFIG_NAME}"
    echo "========================================="
    echo ""
    
    source "${config}"
    
    echo "설명: ${DESCRIPTION}"
    echo ""
    
    "${SCRIPT_DIR}/run_with_config.sh" "${config}"
    
    echo ""
    echo "[정보] 결과 복사 중..."
    
    cp "${PROJECT_ROOT}/results/schbench/schbench_results.txt" \
       "${RESULT_DIR}/schbench_${CONFIG_NAME}.txt" 2>/dev/null || true
    cp "${PROJECT_ROOT}/results/hackbench/hackbench_results.txt" \
       "${RESULT_DIR}/hackbench_${CONFIG_NAME}.txt" 2>/dev/null || true
    
    cat >> "${RESULT_DIR}/comparison_results.txt" <<EOF
[${CONFIG_NAME}]
─────────────────────────────────────
${DESCRIPTION}

파라미터:
  sched_latency_ns: ${SCHED_LATENCY_NS}
  sched_min_granularity_ns: ${SCHED_MIN_GRANULARITY_NS}
  sched_wakeup_granularity_ns: ${SCHED_WAKEUP_GRANULARITY_NS}
  sched_migration_cost_ns: ${SCHED_MIGRATION_COST_NS}

결과: schbench_${CONFIG_NAME}.txt, hackbench_${CONFIG_NAME}.txt

EOF
    
    if [ ${CURRENT} -lt ${TOTAL} ]; then
        echo "[정보] 다음 테스트 전 5초 대기 (시스템 안정화)..."
        sleep 5
        echo ""
    fi
done

echo "" >> "${RESULT_DIR}/comparison_results.txt"
echo "상세 결과: schbench_*.txt, hackbench_*.txt" >> "${RESULT_DIR}/comparison_results.txt"

echo ""
echo "========================================="
echo "전체 벤치마크 완료"
echo "========================================="
echo ""
echo "결과 파일: ${RESULT_DIR}/comparison_results.txt"
echo ""
echo "개별 결과:"
ls -1 "${RESULT_DIR}"/*.txt | sed 's/^/  /'
echo ""

