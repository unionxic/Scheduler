# EEVDF 스케줄러 벤치마크 프로젝트

EEVDF (Earliest Eligible Virtual Deadline First) 스케줄러의 레이턴시 및 오버헤드를 측정하는 자동화된 벤치마크 시스템입니다.

## 빠른 시작

```bash
# 기본 벤치마크 실행 (schbench + hackbench)
./scripts/run_all_eevdf.sh --basic

# 전체 벤치마크 실행 (워크로드 시나리오 포함)
./scripts/run_all_eevdf.sh

# 특정 커널 파라미터로 실행 (sudo 필요)
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 모든 설정 자동 비교 (sudo 필요)
sudo ./scripts/run_all_configs_eevdf.sh
```

## 벤치마크 종류

### 1. 기본 벤치마크
- **schbench**: 레이턴시 측정 (4, 6, 8 스레드)
  - Wakeup Latency (p50, p90, p99, p99.9)
  - Request Latency (p50, p90, p99, p99.9)
  - RPS (Requests Per Second)

- **hackbench**: 오버헤드 측정 (4, 6, 8 그룹)
  - Context switches
  - CPU migrations
  - Page faults
  - Task clock

### 2. 워크로드 시나리오
- CPU-Bound (16 스레드, 10 태스크)
- I/O-Bound (2 스레드, 20 태스크)
- 혼합 워크로드 (8 스레드, 8 태스크)
- 고부하 컨텍스트 스위칭 (16 그룹, 640 태스크)

### 3. 커널 파라미터 조정
환경변수처럼 사용 가능한 설정 파일로 커널 파라미터 조정:
- `baseline.conf` - 시스템 기본값
- `low_latency.conf` - 낮은 레이턴시 최적화
- `high_throughput.conf` - 높은 처리량 최적화
- `balanced.conf` - 균형잡힌 설정
- `minimal_migration.conf` - 마이그레이션 최소화

## 프로젝트 구조

```
scheduler_experiments_eevdf/
├── scripts/
│   ├── run_all_eevdf.sh              # 메인 실행 스크립트
│   ├── run_schbench_eevdf.sh         # schbench 벤치마크
│   ├── run_hackbench_eevdf.sh        # hackbench 벤치마크
│   ├── run_workload_scenarios_eevdf.sh # 워크로드 시나리오
│   ├── run_kernel_tuning_eevdf.sh    # 커널 튜닝 (레거시)
│   ├── run_with_config_eevdf.sh      # 설정 기반 실행
│   ├── run_all_configs_eevdf.sh      # 전체 설정 자동 비교
│   └── common.sh                     # 공통 설정 및 함수
├── configs/
│   └── *.conf                        # 커널 파라미터 설정 파일
├── results/
│   ├── BENCHMARK_REPORT.txt          # 종합 보고서
│   ├── schbench/                     # schbench 결과
│   ├── hackbench/                    # hackbench 결과
│   ├── workload_scenarios/           # 워크로드 결과
│   ├── kernel_tuning/                # 커널 튜닝 결과 (레거시)
│   └── config_based/                 # 설정 기반 결과
└── benchmarks/
    ├── schbench/                     # schbench 소스/빌드
    └── rt-tests/                     # hackbench 소스/빌드
```

## 설치 및 설정

### 필수 조건
```bash
# 빌드 도구
sudo apt install build-essential git

# perf 도구 (선택사항, 더 많은 메트릭 수집)
sudo apt install linux-tools-$(uname -r)
```

### perf 권한 설정
```bash
# perf 사용을 위한 권한 설정
sudo sysctl -w kernel.perf_event_paranoid=-1

# 영구 설정 (선택사항)
echo "kernel.perf_event_paranoid = -1" | sudo tee -a /etc/sysctl.conf
```

### 벤치마크 빌드
벤치마크 도구는 **자동으로 빌드**됩니다. 수동 빌드도 가능:

```bash
# schbench
cd benchmarks
git clone https://git.kernel.org/pub/scm/linux/kernel/git/mason/schbench.git
cd schbench && make

# hackbench
cd benchmarks
git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests && make hackbench
```

## 사용 가이드

### 기본 사용법

#### 1. 기본 벤치마크
```bash
# 빠른 테스트 (schbench + hackbench)
./scripts/run_all_eevdf.sh --basic

# 결과 확인
cat results/schbench/schbench_results.txt
cat results/hackbench/hackbench_results.txt
```

#### 2. 워크로드 시나리오 포함
```bash
# 전체 벤치마크
./scripts/run_all_eevdf.sh

# 워크로드 결과 확인
cat results/workload_scenarios/workload_results.txt

# 종합 보고서 확인
cat results/BENCHMARK_REPORT.txt
```

### 커널 파라미터 조정

#### 설정 파일로 실행
```bash
# 낮은 레이턴시 설정
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 높은 처리량 설정
sudo ./scripts/run_with_config_eevdf.sh configs/high_throughput.conf

# 균형잡힌 설정
sudo ./scripts/run_with_config_eevdf.sh configs/balanced.conf
```

#### 모든 설정 자동 비교
```bash
# 5개 설정 모두 자동 실행 (sudo 필요)
sudo ./scripts/run_all_configs_eevdf.sh

# 비교 결과
cat results/config_based/comparison_report.txt
```

#### 커스텀 설정 만들기
```bash
# 새 설정 파일 생성
cat > configs/my_config.conf <<EOF
SCHED_LATENCY_NS=6000000
SCHED_MIN_GRANULARITY_NS=1000000
SCHED_WAKEUP_GRANULARITY_NS=1500000
SCHED_MIGRATION_COST_NS=750000
DESCRIPTION="내 커스텀 설정"
CONFIG_NAME="my_config"
EOF

# 실행
sudo ./scripts/run_with_config_eevdf.sh configs/my_config.conf
```

## 결과 해석

### schbench 결과
```
[4 스레드]
─────────────────────────────────────
  RPS: 24.37
  
  Wakeup Latency (usec)    Request Latency (usec)
    p50:  9200                p50:  720000
    p90:  16800                p90:  1900000
    p99:  23400                p99:  3300000
    p99.9: 42000              p99.9: 4500000
```

- **RPS**: 높을수록 처리량이 좋음
- **Wakeup Latency**: 낮을수록 응답성이 좋음
- **Request Latency**: 낮을수록 전체 지연이 낮음
- **p99, p99.9**: tail latency - 낮을수록 일관성 있음

### hackbench 결과
```
[4 그룹 - 총 160 태스크]
─────────────────────────────────────
  실행 시간: 0.024초
  Task clock: 98.00 msec
  
  Context switches: 8572
  CPU migrations: 764
  Page faults: 6397
```

- **실행 시간**: 낮을수록 처리 속도가 빠름
- **Context switches**: 스케줄링 오버헤드 지표
- **CPU migrations**: 낮을수록 캐시 효율이 좋음
- **Page faults**: 메모리 접근 패턴 지표

## 실험 시나리오

### 시나리오 1: 레이턴시 vs 처리량 트레이드오프
```bash
# 낮은 레이턴시
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf
# → Wakeup/Request latency↓, Context switch↑

# 높은 처리량
sudo ./scripts/run_with_config_eevdf.sh configs/high_throughput.conf
# → RPS↑, Context switch↓
```

### 시나리오 2: 마이그레이션 영향 분석
```bash
sudo ./scripts/run_with_config_eevdf.sh configs/baseline.conf
sudo ./scripts/run_with_config_eevdf.sh configs/minimal_migration.conf
# → CPU migration 비교
```

### 시나리오 3: 전체 설정 비교
```bash
sudo ./scripts/run_all_configs_eevdf.sh
# → 5가지 설정 자동 비교
```

## 트러블슈팅

### schbench를 찾을 수 없음
```bash
cd benchmarks/schbench && make
```

### hackbench를 찾을 수 없음
```bash
cd benchmarks/rt-tests && make hackbench
```

### perf 권한 오류
```bash
sudo sysctl -w kernel.perf_event_paranoid=-1
```

### sudo 비밀번호 반복 입력
```bash
# sudoers 설정 (선택사항)
sudo visudo -f /etc/sudoers.d/scheduler-tuning
# 추가: yourusername ALL=(ALL) NOPASSWD: /usr/sbin/sysctl -w kernel.sched_*
```

## CFS vs EEVDF 비교

이 벤치마크는 CFS 스케줄러와 동일한 구조로 설계되어 직접 비교가 가능합니다:

### 비교 방법
1. **CFS VM**: `CFS/` 디렉토리에서 벤치마크 실행
2. **EEVDF VM**: `EEVDF/` 디렉토리에서 벤치마크 실행
3. **결과 비교**: 동일한 설정으로 결과 비교 분석

### 주요 비교 지표
- Wakeup/Request Latency 차이
- Context switch 빈도 차이
- CPU migration 패턴 차이
- 워크로드별 성능 특성

## 고급 기능

### 설정 기반 벤치마크
EEVDF만의 특징: 환경변수처럼 커널 파라미터 관리
- 자동 백업/복원
- 7단계 진행 상황 표시
- trap EXIT로 안전장치

### 결과 자동 수집
```bash
# 타임스탬프별로 결과 백업
cp -r results/ results_backup_$(date +%Y%m%d_%H%M%S)/
```

### 개선된 코드 구조
- `common.sh`: 공통 함수 및 설정
- `parse_schbench_result()`: 결과 파싱 함수화
- `parse_hackbench_result()`: 결과 파싱 함수화
- `check_sudo()`, `check_schbench()`, `check_hackbench()`: 체크 함수

## 라이센스

MIT License

## 기여

버그 리포트, 기능 제안, PR 환영합니다.
