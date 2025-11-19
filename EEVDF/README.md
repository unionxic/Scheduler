# EEVDF 스케줄러 벤치마크

리눅스 커널의 EEVDF(Earliest Eligible Virtual Deadline First) 스케줄러 성능 측정 자동화 스크립트

## 빠른 시작

### 1. 사전 준비

```bash
# 빌드 도구 및 perf 설치
sudo apt-get update
sudo apt-get install -y build-essential linux-tools-common linux-tools-generic

# perf 권한 설정
sudo sysctl kernel.perf_event_paranoid=-1

# hackbench 빌드
cd ~/scheduler_experiments_eevdf/benchmarks
git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests && make hackbench
```

### 2. 벤치마크 실행

#### 기본 벤치마크 (빠름 - 약 2분)
```bash
cd ~/scheduler_experiments_eevdf
./scripts/run_all_eevdf.sh --basic
```

#### 전체 벤치마크 (워크로드 포함 - 약 5분)
```bash
./scripts/run_all_eevdf.sh
```

#### 설정 기반 벤치마크 (추천)
```bash
# 단일 설정으로 테스트
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 모든 설정 자동 비교 (약 10-15분)
sudo ./scripts/run_all_configs_eevdf.sh
```

## 벤치마크 구성

### 1. 기본 벤치마크 (`--basic`)

#### schbench (레이턴시)
- 4, 6, 8 스레드 테스트
- 측정: RPS, Wakeup Latency, Request Latency

#### hackbench (처리량/오버헤드)
- 4, 6, 8 그룹 테스트
- 측정: 실행 시간, Context switches, CPU migrations, Page faults

### 2. 워크로드 시나리오

4가지 실제 워크로드 패턴:
1. CPU-Bound: 16 스레드, 10 태스크 (CPU 집약적)
2. I/O-Bound: 2 스레드, 20 태스크 (I/O 대기 많음)
3. 혼합 워크로드: 8 스레드, 8 태스크 (균형잡힌 부하)
4. 고부하 컨텍스트 스위칭: 16 그룹, 640 태스크 (극한 부하)

### 3. 커널 파라미터 조정 (레거시)

4가지 설정으로 성능 비교:
1. Baseline: 기본 설정
2. Low Latency: sched_latency_ns=3ms
3. High Throughput: sched_latency_ns=24ms
4. Minimal Migration: sched_migration_cost_ns=5ms

### 4. 설정 기반 벤치마크 (신규)

환경변수 파일처럼 커널 파라미터를 관리

5가지 사전 정의된 설정:

#### `configs/baseline.conf`
```bash
SCHED_LATENCY_NS=24000000          # 24ms (기본값)
SCHED_MIN_GRANULARITY_NS=3000000   # 3ms
DESCRIPTION="기본 설정 (Baseline)"
```

#### `configs/low_latency.conf`
```bash
SCHED_LATENCY_NS=3000000           # 3ms (응답성 향상)
SCHED_MIN_GRANULARITY_NS=500000    # 0.5ms
DESCRIPTION="낮은 레이턴시 - 응답시간 감소, Context switch 증가"
```

#### `configs/high_throughput.conf`
```bash
SCHED_LATENCY_NS=48000000          # 48ms (처리량 향상)
SCHED_MIN_GRANULARITY_NS=6000000   # 6ms
DESCRIPTION="높은 처리량 - Context switch 감소, 처리량 증가"
```

#### `configs/balanced.conf`
```bash
SCHED_LATENCY_NS=12000000          # 12ms (균형)
SCHED_MIN_GRANULARITY_NS=1500000   # 1.5ms
DESCRIPTION="균형 설정 - 레이턴시와 처리량 균형"
```

#### `configs/minimal_migration.conf`
```bash
SCHED_MIGRATION_COST_NS=5000000    # 5ms (마이그레이션 억제)
DESCRIPTION="마이그레이션 최소화 - 캐시 지역성 향상"
```

**작동 원리**
1. 설정 파일 로드 (source)
2. 원본 파라미터 자동 백업
3. 커널 파라미터 적용 (sysctl)
4. 벤치마크 실행
5. 자동 복원 (trap EXIT)

**장점**
- 환경변수처럼 편리
- 안전 (자동 백업/복원)
- 재사용 가능 (설정 파일 공유)
- Git 버전 관리

## 사용 예시

### 기본 사용법

```bash
# 기본 벤치마크 (빠름)
./scripts/run_all_eevdf.sh --basic

# 전체 벤치마크
./scripts/run_all_eevdf.sh

# 개별 테스트
./scripts/run_schbench_eevdf.sh
./scripts/run_hackbench_eevdf.sh
./scripts/run_workload_scenarios_eevdf.sh
```

### 설정 기반 벤치마크

```bash
# 단일 설정으로 테스트
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 모든 설정 자동 비교
sudo ./scripts/run_all_configs_eevdf.sh

# 커스텀 설정 만들기
cat > configs/custom.conf <<EOF
SCHED_LATENCY_NS=10000000
SCHED_MIN_GRANULARITY_NS=1000000
DESCRIPTION="나만의 설정"
CONFIG_NAME="custom"
EOF

sudo ./scripts/run_with_config_eevdf.sh configs/custom.conf
```

## 결과 확인

```bash
# 종합 보고서
cat results/BENCHMARK_REPORT.txt

# 기본 벤치마크 결과
cat results/schbench/schbench_results.txt
cat results/hackbench/hackbench_results.txt

# 워크로드 시나리오
cat results/workload_scenarios/workload_results.txt

# 설정 기반 비교 보고서
cat results/config_based/comparison_report.txt

# 개별 설정 결과
cat results/config_based/low_latency/config_info.txt
```

## 결과 구조

```
results/
├── BENCHMARK_REPORT.txt              # 전체 종합 보고서
├── schbench/
│   ├── schbench_results.txt          # 4, 6, 8 스레드 통합 결과
│   └── raw_*.txt
├── hackbench/
│   ├── hackbench_results.txt         # 4, 6, 8 그룹 통합 결과
│   └── raw_*.txt
├── workload_scenarios/
│   ├── workload_results.txt          # 4가지 시나리오 통합
│   └── *_raw.txt
├── kernel_tuning/
│   ├── tuning_results.txt            # 4가지 설정 통합 (레거시)
│   └── *_schbench.txt, *_hackbench.txt
└── config_based/                      # 신규
    ├── comparison_report.txt          # 전체 설정 비교 보고서
    ├── baseline/
    │   ├── config_info.txt
    │   ├── schbench.txt
    │   └── hackbench.txt
    ├── low_latency/
    ├── high_throughput/
    ├── balanced/
    └── minimal_migration/
```

## 프로젝트 구조

```
scheduler_experiments_eevdf/
├── scripts/                           # 실행 스크립트 (7개)
│   ├── run_all_eevdf.sh              # 전체 실행 (--basic 옵션)
│   ├── run_schbench_eevdf.sh         # schbench
│   ├── run_hackbench_eevdf.sh        # hackbench
│   ├── run_workload_scenarios_eevdf.sh    # 워크로드
│   ├── run_kernel_tuning_eevdf.sh    # 커널 튜닝 (레거시)
│   ├── run_with_config_eevdf.sh      # 단일 설정 실행
│   └── run_all_configs_eevdf.sh      # 전체 설정 비교
├── configs/                           # 설정 파일 (5개)
│   ├── baseline.conf
│   ├── low_latency.conf
│   ├── high_throughput.conf
│   ├── balanced.conf
│   └── minimal_migration.conf
├── benchmarks/                        # 벤치마크 도구 (자동 생성)
│   ├── schbench/
│   └── rt-tests/
├── results/                           # 측정 결과 (자동 생성)
└── README.md
```

## 측정 지표

### schbench (레이턴시)
- RPS: 초당 처리 요청 수
- Wakeup Latency: 작업이 깨어나서 실행되기까지의 시간
- Request Latency: 작업 시작부터 완료까지의 총 시간

### hackbench (처리량/오버헤드)
- 실행 시간: 총 처리 시간
- Context Switches: 문맥 교환 횟수
- CPU Migrations: CPU 간 프로세스 이동 횟수
- Page Faults: 페이지 폴트 발생 횟수

## CFS vs EEVDF 비교

이 벤치마크는 CFS 스케줄러와 동일한 구조로 설계되었습니다:

1. CFS VM에서 `scheduler_experiments_cfs` 실행
2. EEVDF VM에서 `scheduler_experiments_eevdf` 실행
3. 각 VM의 결과 비교 분석

## 트러블슈팅

### perf 권한 에러
```bash
sudo sysctl kernel.perf_event_paranoid=-1
```

### hackbench를 찾을 수 없음
```bash
cd ~/scheduler_experiments_eevdf/benchmarks
git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests && make hackbench
```

### schbench 빌드 실패
```bash
cd ~/scheduler_experiments_eevdf/benchmarks
git clone https://git.kernel.org/pub/scm/linux/kernel/git/mason/schbench.git
cd schbench && make
```

### 설정 기반 벤치마크 실행 안됨
```bash
# sudo 권한 필요
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 또는
sudo ./scripts/run_all_configs_eevdf.sh
```

## 실행 시간

- 기본 벤치마크 (`--basic`): 약 2분
- 전체 벤치마크 (워크로드 포함): 약 4-5분
- 단일 설정 테스트: 약 2-3분
- 전체 설정 비교 (5개 설정): 약 10-15분

## 주의사항

- VM 환경에서는 일부 하드웨어 성능 카운터를 사용할 수 없습니다
- 설정 기반 벤치마크는 sudo 권한이 필요합니다
- 커널 파라미터는 자동으로 백업/복원됩니다 (안전)
- 재현성을 위해 테스트 전 불필요한 백그라운드 프로세스를 종료하세요
- 네트워크 활동을 최소화하여 측정 정확도를 높이세요

## 체크리스트

실행 전 확인사항:
- 빌드 도구 설치됨 (gcc, make)
- perf 권한 설정됨 (perf_event_paranoid=-1)
- hackbench 빌드 완료
- 백그라운드 작업 최소화
- sudo 권한 확인 (설정 기반 벤치마크 시)
