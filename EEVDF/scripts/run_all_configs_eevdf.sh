#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIGS_DIR="${PROJECT_ROOT}/configs"

check_sudo || exit 1

echo "========================================="
echo "EEVDF 스케줄러 - 전체 설정 자동 비교"
echo "========================================="
echo ""

# 사용 가능한 설정 파일 확인
CONFIG_FILES=($(ls -1 "${CONFIGS_DIR}"/*.conf 2>/dev/null | sort))

if [ ${#CONFIG_FILES[@]} -eq 0 ]; then
    echo "[오류] 설정 파일을 찾을 수 없습니다: ${CONFIGS_DIR}/"
    exit 1
fi

echo "발견된 설정: ${#CONFIG_FILES[@]}개"
for config in "${CONFIG_FILES[@]}"; do
    echo "  - $(basename "$config")"
done
echo ""

START_TIME=$(date +%s)

# 각 설정으로 벤치마크 실행
TOTAL=${#CONFIG_FILES[@]}
CURRENT=0

for config in "${CONFIG_FILES[@]}"; do
    CURRENT=$((CURRENT + 1))
    echo ""
    echo "========================================="
    echo "[${CURRENT}/${TOTAL}] $(basename "$config")"
    echo "========================================="
    
    # 단일 설정 실행 (자동 복원 포함)
    "${PROJECT_ROOT}/scripts/run_with_config_eevdf.sh" "$config"
    
    # 다음 테스트 전 시스템 안정화
    if [ $CURRENT -lt $TOTAL ]; then
        echo ""
        echo "다음 테스트 준비 중... (10초 대기)"
        sleep 10
    fi
done

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo "========================================="
echo "전체 설정 비교 완료!"
echo "========================================="
echo "총 소요 시간: ${MINUTES}분 ${SECONDS}초"
echo ""

# 비교 보고서 생성
REPORT_FILE="${PROJECT_ROOT}/results/config_based/comparison_report.txt"
mkdir -p "$(dirname "$REPORT_FILE")"

cat > "${REPORT_FILE}" <<EOF
================================================================
EEVDF 스케줄러 - 설정 비교 보고서
================================================================
일시: $(date '+%Y-%m-%d %H:%M:%S')
커널: $(uname -r)
총 소요 시간: ${MINUTES}분 ${SECONDS}초
테스트된 설정: ${TOTAL}개

================================================================
설정별 결과 요약
================================================================

EOF

# 각 설정 결과 추가
for config in "${CONFIG_FILES[@]}"; do
    CONFIG_NAME=$(basename "$config" .conf)
    INFO_FILE="${PROJECT_ROOT}/results/config_based/${CONFIG_NAME}/config_info.txt"
    
    if [ -f "$INFO_FILE" ]; then
        cat "$INFO_FILE" >> "${REPORT_FILE}"
        echo "" >> "${REPORT_FILE}"
    fi
done

cat >> "${REPORT_FILE}" <<EOF
================================================================
결과 파일 위치
================================================================
- 비교 보고서: results/config_based/comparison_report.txt
- 개별 결과: results/config_based/<설정이름>/
  - config_info.txt (설정 정보 + 요약)
  - schbench.txt (상세 로그)
  - hackbench.txt (상세 로그)
================================================================
EOF

echo "비교 보고서 생성: ${REPORT_FILE}"
echo ""
echo "결과 확인:"
echo "  cat ${REPORT_FILE}"
echo ""

