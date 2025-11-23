#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
RESULT_DIR="${PROJECT_ROOT}/results/config_comparison"

if [ ! -d "${RESULT_DIR}" ]; then
    echo "[오류] 결과 디렉토리가 없습니다: ${RESULT_DIR}"
    exit 1
fi

OUTPUT="${RESULT_DIR}/COMPARISON_REPORT.txt"

cat > "${OUTPUT}" <<'EOF'
CFS 스케줄러 - 설정 비교 종합 보고서
================================================================
EOF

echo "측정 일시: $(date '+%Y-%m-%d')" >> "${OUTPUT}"
echo "커널: $(uname -r)" >> "${OUTPUT}"
echo "테스트 설정: 5개" >> "${OUTPUT}"

cat >> "${OUTPUT}" <<'EOF'
================================================================

성능 비교 요약
================================================================

【schbench - RPS (높을수록 좋음)】
EOF

declare -A rps_values
for conf in baseline low_latency high_throughput balanced minimal_migration; do
    RPS=$(grep "RPS:" "${RESULT_DIR}/schbench_${conf}.txt" 2>/dev/null | head -1 | awk '{print $2}' || echo "0")
    rps_values[$conf]=$RPS
done

BASELINE_RPS=${rps_values[baseline]}

echo "${rps_values[@]}" | tr ' ' '\n' | sort -rn | head -5 | nl | while read rank value; do
    for conf in "${!rps_values[@]}"; do
        if (( $(echo "${rps_values[$conf]} == $value" | bc -l) )); then
            if [ "$conf" = "baseline" ]; then
                CHANGE="(기준)"
            else
                PERCENT=$(echo "scale=1; ($value / $BASELINE_RPS - 1) * 100" | bc -l)
                if (( $(echo "$PERCENT >= 0" | bc -l) )); then
                    CHANGE="(+${PERCENT}%)"
                else
                    CHANGE="(${PERCENT}%)"
                fi
            fi
            printf "%d위: %-20s → %.2f RPS %s\n" $rank $conf $value "$CHANGE" >> "${OUTPUT}"
            break
        fi
    done
done

cat >> "${OUTPUT}" <<'EOF'

【hackbench - 실행 시간 (낮을수록 좋음)】
EOF

declare -A time_values
for conf in baseline low_latency high_throughput balanced minimal_migration; do
    TIME=$(grep "실행 시간:" "${RESULT_DIR}/hackbench_${conf}.txt" 2>/dev/null | head -1 | awk '{print $3}' | sed 's/초//' || echo "999")
    time_values[$conf]=$TIME
done

BASELINE_TIME=${time_values[baseline]}

echo "${time_values[@]}" | tr ' ' '\n' | sort -n | head -5 | nl | while read rank value; do
    for conf in "${!time_values[@]}"; do
        if (( $(echo "${time_values[$conf]} == $value" | bc -l) )); then
            if [ "$conf" = "baseline" ]; then
                CHANGE="(기준)"
            else
                PERCENT=$(echo "scale=1; ($value / $BASELINE_TIME - 1) * 100" | bc -l)
                if (( $(echo "$PERCENT >= 0" | bc -l) )); then
                    CHANGE="(+${PERCENT}%)"
                else
                    CHANGE="(${PERCENT}%)"
                fi
            fi
            printf "%d위: %-20s → %.3f초 %s\n" $rank $conf $value "$CHANGE" >> "${OUTPUT}"
            break
        fi
    done
done

cat >> "${OUTPUT}" <<'EOF'

================================================================
설정별 파라미터
================================================================
EOF

for conf in baseline low_latency high_throughput balanced minimal_migration; do
    source "${PROJECT_ROOT}/configs/${conf}.conf"
    LAT_MS=$(echo "scale=2; $SCHED_LATENCY_NS / 1000000" | bc -l)
    MIG_MS=$(echo "scale=2; $SCHED_MIGRATION_COST_NS / 1000000" | bc -l)
    
    echo "${conf}: latency: ${LAT_MS}ms | migration_cost: ${MIG_MS}ms" >> "${OUTPUT}"
done

cat >> "${OUTPUT}" <<'EOF'

================================================================
권장 사항
================================================================
웹 서버/DB      → "baseline" (균형잡힌 기본 성능)
CPU 집약 작업   → "baseline" 또는 "high_throughput"
실시간 응답     → "low_latency" (응답성 우선)
NUMA 시스템     → "minimal_migration" (캐시 효율)

================================================================
결과 파일 위치
================================================================
results/config_comparison/
├── COMPARISON_REPORT.txt (이 파일)
├── schbench_*.txt (각 설정별 상세 결과)
└── hackbench_*.txt (각 설정별 상세 결과)
================================================================
EOF

echo ""
echo "✓ 종합 보고서 생성 완료: ${OUTPUT}"
echo ""
cat "${OUTPUT}"

