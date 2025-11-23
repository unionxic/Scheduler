#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE="${1:-}"

# 사용법 확인
if [ -z "$CONFIG_FILE" ]; then
    echo "사용법: $0 <설정파일>"
    echo ""
    echo "사용 가능한 설정:"
    ls -1 "${PROJECT_ROOT}/configs/"*.conf 2>/dev/null | xargs -n1 basename
    exit 1
fi

check_sudo "$CONFIG_FILE" || exit 1

# 설정 파일 존재 확인
if [ ! -f "$CONFIG_FILE" ]; then
    echo "[오류] 설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    exit 1
fi

# EEVDF debugfs 경로
SCHED_DEBUG="/sys/kernel/debug/sched"

echo "========================================"
echo "EEVDF 스케줄러 - 설정 기반 벤치마크"
echo "========================================"
echo ""

# [1] 설정 파일 로드
echo "[1/7] 설정 파일 로드 중..."
source "${CONFIG_FILE}"

echo "적용할 설정: ${DESCRIPTION}"
echo "  base_slice_ns: ${BASE_SLICE_NS}"
echo "  migration_cost_ns: ${MIGRATION_COST_NS}"
echo "  nr_migrate: ${NR_MIGRATE}"
echo ""

# [2] 원본 백업
echo "[2/7] 원본 파라미터 백업 중..."
ORIGINAL_BASE_SLICE=$(cat ${SCHED_DEBUG}/base_slice_ns)
ORIGINAL_MIGRATION=$(cat ${SCHED_DEBUG}/migration_cost_ns)
ORIGINAL_NR_MIGRATE=$(cat ${SCHED_DEBUG}/nr_migrate)

echo "원본 값:"
echo "  base_slice_ns: ${ORIGINAL_BASE_SLICE}"
echo "  migration_cost_ns: ${ORIGINAL_MIGRATION}"
echo "  nr_migrate: ${ORIGINAL_NR_MIGRATE}"
echo ""

# [3] 복원 함수
restore_params() {
    echo ""
    echo "[7/7] 원본 파라미터 복원 중..."
    echo ${ORIGINAL_BASE_SLICE} > ${SCHED_DEBUG}/base_slice_ns
    echo ${ORIGINAL_MIGRATION} > ${SCHED_DEBUG}/migration_cost_ns
    echo ${ORIGINAL_NR_MIGRATE} > ${SCHED_DEBUG}/nr_migrate
    echo "복원 완료!"
}

# [4] EXIT 시 자동 복원
trap restore_params EXIT

# [5] 커널 파라미터 적용
echo "[3/7] 커널 파라미터 적용 중..."
echo ${BASE_SLICE_NS} > ${SCHED_DEBUG}/base_slice_ns
echo ${MIGRATION_COST_NS} > ${SCHED_DEBUG}/migration_cost_ns
echo ${NR_MIGRATE} > ${SCHED_DEBUG}/nr_migrate
echo "적용 완료!"
echo ""

# 적용된 값 확인
echo "[4/7] 적용된 파라미터 확인..."
echo "  base_slice_ns: $(cat ${SCHED_DEBUG}/base_slice_ns)"
echo "  migration_cost_ns: $(cat ${SCHED_DEBUG}/migration_cost_ns)"
echo "  nr_migrate: $(cat ${SCHED_DEBUG}/nr_migrate)"
echo ""

sleep 2  # 시스템 안정화

# [6] 벤치마크 실행
echo "[5/7] 벤치마크 실행 중..."
echo ""

# 결과 디렉토리 생성
RESULT_DIR="${PROJECT_ROOT}/results/config_based/${CONFIG_NAME}"
mkdir -p "${RESULT_DIR}"

# schbench 실행
SCHBENCH_BIN="${PROJECT_ROOT}/benchmarks/schbench/schbench"
if [ -x "${SCHBENCH_BIN}" ]; then
    echo "  - schbench 테스트 중..."
    "${SCHBENCH_BIN}" -m 4 -t 5 -r 30 > "${RESULT_DIR}/schbench.txt" 2>&1
    RPS=$(grep "average rps" "${RESULT_DIR}/schbench.txt" | awk '{print $3}')
    echo "    완료 - RPS: ${RPS}"
fi

# hackbench 실행
HACKBENCH_BIN="${PROJECT_ROOT}/benchmarks/rt-tests/hackbench"
if [ -x "${HACKBENCH_BIN}" ]; then
    echo "  - hackbench 테스트 중..."
    perf stat -e context-switches,cpu-migrations \
        "${HACKBENCH_BIN}" -l 50 -g 4 -s 100 -P \
        > "${RESULT_DIR}/hackbench.txt" 2>&1 || true
    TIME=$(grep "Time:" "${RESULT_DIR}/hackbench.txt" 2>/dev/null | awk '{print $2}' || echo "N/A")
    echo "    완료 - 시간: ${TIME}초"
fi

echo ""
echo "[6/7] 결과 저장 중..."

# 설정 정보 저장
cat > "${RESULT_DIR}/config_info.txt" <<EOF
========================================
설정 기반 벤치마크 결과 (EEVDF)
========================================
설정 이름: ${CONFIG_NAME}
설명: ${DESCRIPTION}
커널: $(uname -r)
측정 시각: $(date '+%Y-%m-%d %H:%M:%S')

적용된 파라미터:
  base_slice_ns: ${BASE_SLICE_NS}
  migration_cost_ns: ${MIGRATION_COST_NS}
  nr_migrate: ${NR_MIGRATE}

결과:
$([ -f "${RESULT_DIR}/schbench.txt" ] && echo "  schbench: RPS ${RPS}" || echo "  schbench: N/A")
$([ -f "${RESULT_DIR}/hackbench.txt" ] && echo "  hackbench: ${TIME}초" || echo "  hackbench: N/A")
EOF

echo "결과 저장 완료: ${RESULT_DIR}/"
echo ""

# [7] 스크립트 종료 시 trap이 자동으로 restore_params() 실행
