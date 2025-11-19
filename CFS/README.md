# CFS 스케줄러 벤치마크 프로젝트

CFS (Completely Fair Scheduler) 스케줄러의 레이턴시 및 오버헤드를 측정하는 자동화된 벤치마크 시스템입니다.

## 빠른 시작

```bash
# 기본 벤치마크 실행 (schbench + hackbench)
./scripts/run_all_cfs.sh --basic

# 전체 벤치마크 실행 (워크로드 시나리오 포함)
./scripts/run_all_cfs.sh

# 특정 커널 파라미터로 실행
./scripts/run_with_config.sh configs/low_latency.conf

# 모든 설정 자동 비교
./scripts/run_all_configs.sh
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
- `default.conf` - 시스템 기본값
- `low_latency.conf` - 낮은 레이턴시 최적화
- `high_throughput.conf` - 높은 처리량 최적화
- `minimal_migration.conf` - 마이그레이션 최소화
- `aggressive_preempt.conf` - 공격적 선점 (실험용)

## 프로젝트 구조

```
scheduler_experiments_cfs/
├── scripts/
│   ├── run_all_cfs.sh              # 메인 실행 스크립트
│   ├── run_schbench_cfs.sh         # schbench 벤치마크
│   ├── run_hackbench_cfs.sh        # hackbench 벤치마크
│   ├── run_workload_scenarios.sh   # 워크로드 시나리오
│   ├── run_with_config.sh          # 설정 기반 실행
│   ├── run_all_configs.sh          # 전체 설정 자동 비교
│   └── config_cfs.sh               # 공통 설정
├── configs/
│   ├── *.conf                      # 커널 파라미터 설정 파일
│   └── README.md                   # 설정 파일 가이드
├── results/
│   ├── schbench/                   # schbench 결과
│   ├── hackbench/                  # hackbench 결과
│   ├── workload_scenarios/         # 워크로드 결과
│   └── config_comparison/          # 설정 비교 결과
└── benchmarks/
    ├── schbench/                   # schbench 소스/빌드
    └── rt-tests/                   # hackbench 소스/빌드
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
./scripts/run_all_cfs.sh --basic

# 결과 확인
cat results/schbench/schbench_results.txt
cat results/hackbench/hackbench_results.txt
```

#### 2. 워크로드 시나리오 포함
```bash
# 전체 벤치마크
./scripts/run_all_cfs.sh

# 워크로드 결과 확인
cat results/workload_scenarios/workload_results.txt
```

### 커널 파라미터 조정

#### 설정 파일로 실행
```bash
# 낮은 레이턴시 설정
./scripts/run_with_config.sh configs/low_latency.conf

# 높은 처리량 설정
./scripts/run_with_config.sh configs/high_throughput.conf
```

#### 모든 설정 자동 비교
```bash
# 5개 설정 모두 자동 실행
./scripts/run_all_configs.sh

# 비교 결과
cat results/config_comparison/comparison_results.txt
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
EOF

# 실행
./scripts/run_with_config.sh configs/my_config.conf
```

## 결과 해석

### schbench 결과
```
[4 스레드]
─────────────────────────────────────
  RPS: 21.57
  
  Wakeup Latency (usec)    Request Latency (usec)
    p50:  9168                p50:  711680
    p90:  16736                p90:  1886208
    p99:  23392                p99:  3289088
    p99.9: 42304              p99.9: 4497408
```

- **RPS**: 높을수록 처리량이 좋음
- **Wakeup Latency**: 낮을수록 응답성이 좋음
- **Request Latency**: 낮을수록 전체 지연이 낮음
- **p99, p99.9**: tail latency - 낮을수록 일관성 있음

### hackbench 결과
```
[4 그룹 - 총 160 태스크]
─────────────────────────────────────
  실행 시간: 0.031초
  Task clock: 123.06 msec
  
  Context switches: 4865
  CPU migrations: 437
  Page faults: 6317
```

- **실행 시간**: 낮을수록 처리 속도가 빠름
- **Context switches**: 스케줄링 오버헤드 지표
- **CPU migrations**: 낮을수록 캐시 효율이 좋음
- **Page faults**: 메모리 접근 패턴 지표

## 실험 시나리오

### 시나리오 1: 레이턴시 vs 처리량 트레이드오프
```bash
# 낮은 레이턴시
./scripts/run_with_config.sh configs/low_latency.conf
# → Wakeup/Request latency↓, Context switch↑

# 높은 처리량
./scripts/run_with_config.sh configs/high_throughput.conf
# → RPS↑, Context switch↓
```

### 시나리오 2: 마이그레이션 영향 분석
```bash
./scripts/run_with_config.sh configs/default.conf
./scripts/run_with_config.sh configs/minimal_migration.conf
# → CPU migration 비교
```

### 시나리오 3: 전체 설정 비교
```bash
./scripts/run_all_configs.sh
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

## 추가 문서

- **configs/README.md**: 커널 파라미터 설명

## 고급 기능

### 환경변수 사용
```bash
# 벤치마크 파라미터 커스터마이즈 (추후 구현)
BENCH_THREADS="4 8 16" ./scripts/run_schbench_cfs.sh
```

### 결과 자동 수집
```bash
# 타임스탬프별로 결과 백업
cp -r results/ results_backup_$(date +%Y%m%d_%H%M%S)/
```

## 라이센스

MIT License

## 기여

버그 리포트, 기능 제안, PR 환영합니다.
