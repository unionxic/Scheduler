# Linux Scheduler Benchmark: EEVDF vs CFS

리눅스 커널 스케줄러(EEVDF vs CFS) 성능 비교 프로젝트

## 프로젝트 구조

```
Scheduler/
├── CFS/              # CFS (Completely Fair Scheduler) 벤치마크
│   ├── scripts/      # 벤치마크 실행 스크립트
│   ├── configs/      # 커널 파라미터 설정 파일
│   ├── results/      # 벤치마크 결과
│   └── README.md     # CFS 상세 가이드
│
└── EEVDF/            # EEVDF (Earliest Eligible Virtual Deadline First) 벤치마크
    ├── scripts/      # 벤치마크 실행 스크립트 (CFS와 동일 구조)
    ├── configs/      # 커널 파라미터 설정 파일
    ├── results/      # 벤치마크 결과
    └── README.md     # EEVDF 상세 가이드
```

## 벤치마크 도구

### 1. schbench
- **목적**: 레이턴시 측정
- **메트릭**: Wakeup Latency, Request Latency, RPS
- **테스트**: 4, 6, 8 스레드

### 2. hackbench
- **목적**: 시스템 오버헤드 측정
- **메트릭**: Context switches, CPU migrations, Page faults
- **테스트**: 4, 6, 8 그룹

### 3. 워크로드 시나리오
- CPU-Bound
- I/O-Bound
- 혼합 워크로드
- 고부하 컨텍스트 스위칭

## 빠른 시작

### CFS 벤치마크
```bash
cd CFS
./scripts/run_all_cfs.sh --basic
```

### EEVDF 벤치마크
```bash
cd EEVDF
./scripts/run_all_eevdf.sh --basic
```

### 커널 파라미터 조정 실험
```bash
# CFS
cd CFS
./scripts/run_with_config.sh configs/low_latency.conf

# EEVDF
cd EEVDF
./scripts/run_with_config.sh configs/low_latency.conf
```

## 비교 분석

각 스케줄러별로 동일한 벤치마크를 실행한 후, 결과를 비교 분석합니다:

1. **레이턴시 비교**
   - CFS: `CFS/results/schbench/schbench_results.txt`
   - EEVDF: `EEVDF/results/schbench/schbench_results.txt`

2. **오버헤드 비교**
   - CFS: `CFS/results/hackbench/hackbench_results.txt`
   - EEVDF: `EEVDF/results/hackbench/hackbench_results.txt`

3. **워크로드 시나리오 비교**
   - CFS: `CFS/results/workload_scenarios/workload_results.txt`
   - EEVDF: `EEVDF/results/workload_scenarios/workload_results.txt`

4. **커널 파라미터 영향 비교**
   - CFS: `CFS/results/config_comparison/comparison_results.txt`
   - EEVDF: `EEVDF/results/config_comparison/comparison_results.txt`

## 주요 비교 지표

### 레이턴시 특성
- Wakeup Latency (p50, p90, p99, p99.9)
- Request Latency (p50, p90, p99, p99.9)
- RPS (Requests Per Second)

### 시스템 오버헤드
- Context switches
- CPU migrations
- Page faults
- Task clock

### 처리량
- 실행 시간
- 평균 RPS
- Tail latency (p99, p99.9)

## 실험 환경

- **CFS VM**: Linux Kernel 5.15 이상
- **EEVDF VM**: Linux Kernel 6.6 이상
- **벤치마크**: schbench, hackbench (rt-tests)
- **측정 도구**: perf stat, /usr/bin/time

## 문서

- **CFS/README.md**: CFS 벤치마크 상세 가이드
- **EEVDF/README.md**: EEVDF 벤치마크 상세 가이드
- **CFS/configs/README.md**: 커널 파라미터 설명
- **EEVDF/configs/README.md**: 커널 파라미터 설명

## 라이센스

MIT License

## 기여

버그 리포트, 기능 제안, PR 환영합니다.

