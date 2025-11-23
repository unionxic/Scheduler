# EEVDF 스케줄러 벤치마크 프로젝트 - PPT 참고자료

---

## 📋 목차
1. [프로젝트 개요](#1-프로젝트-개요)
2. [배경: CFS vs EEVDF](#2-배경-cfs-vs-eevdf)
3. [구현 내용](#3-구현-내용)
4. [프로젝트 구조](#4-프로젝트-구조)
5. [커널 파라미터 상세 설명](#5-커널-파라미터-상세-설명)
6. [벤치마크 메트릭 해석](#6-벤치마크-메트릭-해석)
7. [실험 결과](#7-실험-결과)
8. [NCP 네트워크 벤치마크](#8-ncp-네트워크-벤치마크)
9. [결론](#9-결론)

---

## 1. 프로젝트 개요

### 1.1 프로젝트 목표
- **Linux 커널 스케줄러 성능 비교**: CFS vs EEVDF
- **커널 파라미터 튜닝 효과 분석**
- **실제 워크로드 환경에서의 성능 측정**

### 1.2 프로젝트 범위
```
┌─────────────────────────────────────────────┐
│  로컬 벤치마크 (레이턴시, 처리량, 오버헤드)  │
│  ↓                                           │
│  커널 파라미터 조정 (5가지 설정)             │
│  ↓                                           │
│  네트워크 벤치마크 (NCP 서버 연결)           │
│  ↓                                           │
│  CFS vs EEVDF 비교 분석                      │
└─────────────────────────────────────────────┘
```

---

## 2. 배경: CFS vs EEVDF

### 2.1 CFS (Completely Fair Scheduler)
- **도입**: Linux 2.6.23 (2007년)
- **특징**: Red-Black Tree 기반 공정성 스케줄러
- **장점**: 공정한 CPU 시간 분배
- **단점**: Tail latency 높음, 예측 가능성 낮음

### 2.2 EEVDF (Earliest Eligible Virtual Deadline First)
- **도입**: Linux 6.6 (2023년)
- **특징**: Deadline 기반 스케줄러
- **장점**:
  - 낮은 tail latency (p99, p99.9)
  - 향상된 예측 가능성
  - 실시간 응답성 개선
- **단점**: 구현 복잡도 증가

### 2.3 핵심 차이점
| 항목 | CFS | EEVDF |
|------|-----|-------|
| 스케줄링 기준 | vruntime (실행 시간) | Virtual Deadline |
| 자료구조 | Red-Black Tree | Red-Black Tree + Deadline |
| 공정성 | 장기적 공정성 | 단기적 공정성 + Deadline 보장 |
| Tail Latency | 높음 | 낮음 (개선됨) |
| 적용 분야 | 범용 | 범용 + 저지연 요구 |

---

## 3. 구현 내용

### 3.1 구현한 벤치마크 종류

#### (1) 로컬 벤치마크
```bash
# schbench - 레이턴시 측정
./scripts/run_schbench_eevdf.sh
→ Wakeup Latency, Request Latency, RPS

# hackbench - 시스템 오버헤드 측정
./scripts/run_hackbench_eevdf.sh
→ Context switches, CPU migrations, Page faults

# 워크로드 시나리오
./scripts/run_workload_scenarios_eevdf.sh
→ CPU-Bound, I/O-Bound, Mixed, High-CS
```

#### (2) 커널 파라미터 기반 벤치마크
```bash
# 단일 설정 테스트
sudo ./scripts/run_with_config_eevdf.sh configs/low_latency.conf

# 전체 설정 자동 비교 (5가지)
sudo ./scripts/run_all_configs_eevdf.sh
```

#### (3) 네트워크 벤치마크 (NCP 서버)
```bash
# 단일 네트워크 테스트
./scripts/run_network_advanced_eevdf.sh

# 설정별 네트워크 비교
sudo ./scripts/run_network_advanced_configs_eevdf.sh
```

### 3.2 자동화 구조
```
[사용자 실행]
    ↓
[설정 파일 로드] → configs/*.conf
    ↓
[원본 파라미터 백업] → /sys/kernel/debug/sched/*
    ↓
[커널 파라미터 적용] → debugfs write
    ↓
[벤치마크 실행] → schbench, hackbench, iperf3
    ↓
[결과 파싱 및 저장] → results/
    ↓
[원본 파라미터 복원] → trap EXIT
```

---

## 4. 프로젝트 구조

### 4.1 디렉토리 구조
```
Scheduler/EEVDF/
├── scripts/                                    # 실행 스크립트
│   ├── common.sh                               # 공통 함수 및 설정
│   ├── run_all_eevdf.sh                        # 메인 벤치마크
│   ├── run_schbench_eevdf.sh                   # 레이턴시 테스트
│   ├── run_hackbench_eevdf.sh                  # 오버헤드 테스트
│   ├── run_workload_scenarios_eevdf.sh         # 워크로드 시나리오
│   ├── run_with_config_eevdf.sh                # 설정 기반 실행
│   ├── run_all_configs_eevdf.sh                # 전체 설정 비교
│   ├── run_network_advanced_eevdf.sh           # 단일 네트워크 테스트
│   └── run_network_advanced_configs_eevdf.sh   # 네트워크 설정 비교
│
├── configs/                                    # 커널 파라미터 설정
│   ├── baseline.conf                           # 기본값 (표준)
│   ├── low_latency.conf                        # 낮은 레이턴시
│   ├── high_throughput.conf                    # 높은 처리량
│   ├── balanced.conf                           # 균형잡힌 설정
│   └── minimal_migration.conf                  # 마이그레이션 최소화
│
├── results/                                    # 결과 저장
│   ├── schbench/                               # 레이턴시 결과
│   ├── hackbench/                              # 오버헤드 결과
│   ├── workload_scenarios/                     # 워크로드 결과
│   ├── config_based/                           # 설정별 비교 결과
│   └── network/                                # 네트워크 벤치마크 결과
│
└── benchmarks/                                 # 벤치마크 도구
    ├── schbench/                               # schbench 소스/빌드
    └── rt-tests/                               # hackbench 소스/빌드
```

### 4.2 핵심 스크립트 역할

| 스크립트 | 역할 | sudo 필요 |
|----------|------|-----------|
| `run_all_eevdf.sh` | 전체 벤치마크 실행 | ✗ |
| `run_with_config_eevdf.sh` | 설정 파일 기반 실행 | ✓ |
| `run_all_configs_eevdf.sh` | 5가지 설정 자동 비교 | ✓ |
| `run_network_advanced_eevdf.sh` | 네트워크 단일 테스트 | ✗ |
| `run_network_advanced_configs_eevdf.sh` | 네트워크 설정 비교 | ✓ |

---

## 5. 커널 파라미터 상세 설명

### 5.1 EEVDF 주요 파라미터

#### (1) base_slice_ns
- **의미**: 기본 타임슬라이스 (나노초)
- **표준값**: 2,250,000ns (2.25ms)
- **영향**:
  - **작을수록**: 낮은 레이턴시, 높은 Context Switch
  - **클수록**: 높은 처리량, 낮은 Context Switch
- **경로**: `/sys/kernel/debug/sched/base_slice_ns`

#### (2) migration_cost_ns
- **의미**: CPU 간 태스크 이동 비용 (나노초)
- **표준값**: 500,000ns (0.5ms)
- **영향**:
  - **작을수록**: 빠른 로드 밸런싱, 캐시 미스 증가
  - **클수록**: CPU 친화성 유지, 캐시 효율 증가
- **경로**: `/sys/kernel/debug/sched/migration_cost_ns`

#### (3) nr_migrate
- **의미**: 한 번에 마이그레이션할 수 있는 태스크 수
- **표준값**: 32
- **영향**:
  - **높을수록**: 적극적인 로드 밸런싱
  - **낮을수록**: 마이그레이션 억제, 캐시 친화성
- **경로**: `/sys/kernel/debug/sched/nr_migrate`

### 5.2 설정별 파라미터 값

| 설정 | base_slice_ns | migration_cost_ns | nr_migrate | 목적 |
|------|---------------|-------------------|------------|------|
| **baseline** | 2,250,000 (2.25ms) | 500,000 (0.5ms) | 32 | 시스템 기본값 |
| **low_latency** | 750,000 (0.75ms) | 100,000 (0.1ms) | 64 | 빠른 응답 |
| **high_throughput** | 6,000,000 (6ms) | 2,000,000 (2ms) | 8 | 배치 작업 |
| **balanced** | 1,500,000 (1.5ms) | 750,000 (0.75ms) | 24 | 균형 |
| **minimal_migration** | 2,250,000 (2.25ms) | 5,000,000 (5ms) | 4 | 캐시 효율 |

### 5.3 파라미터 조정 전략

```
┌─────────────────────────────────────────────┐
│  낮은 레이턴시 우선                          │
│  → base_slice ↓, migration_cost ↓, nr_migrate ↑  │
│                                              │
│  높은 처리량 우선                            │
│  → base_slice ↑, migration_cost ↑, nr_migrate ↓  │
│                                              │
│  캐시 효율 우선                              │
│  → migration_cost ↑↑, nr_migrate ↓↓         │
└─────────────────────────────────────────────┘
```

---

## 6. 벤치마크 메트릭 해석

### 6.1 schbench 메트릭

#### (1) Wakeup Latency
- **의미**: 태스크가 wake-up 신호를 받고 실제 실행되기까지 걸린 시간
- **단위**: μs (마이크로초)
- **해석**:
  - **p50 (중앙값)**: 절반의 경우 이 시간 이내 응답
  - **p99 (99th percentile)**: 99%의 경우 이 시간 이내 응답 (tail latency)
  - **p99.9**: 999/1000 경우 이 시간 이내 응답
- **좋은 값**: 낮을수록 좋음 (응답성 향상)

#### (2) Request Latency
- **의미**: 요청 제출부터 완료까지 전체 지연 시간
- **단위**: μs (마이크로초)
- **해석**: Wakeup Latency + 실행 시간
- **좋은 값**: 낮을수록 좋음

#### (3) RPS (Requests Per Second)
- **의미**: 초당 처리 요청 수
- **해석**: 시스템 처리량 지표
- **좋은 값**: 높을수록 좋음

### 6.2 hackbench 메트릭

#### (1) Context Switches
- **의미**: CPU가 한 태스크에서 다른 태스크로 전환한 횟수
- **해석**:
  - 높음 → 잦은 전환, 스케줄링 오버헤드 증가
  - 낮음 → 적은 전환, 처리량 향상 (단, 응답성 저하 가능)
- **표준값**: 워크로드 의존적 (일반적으로 수천~수만)

#### (2) CPU Migrations
- **의미**: 태스크가 CPU 간 이동한 횟수
- **해석**:
  - 높음 → 로드 밸런싱 활발, 캐시 미스 증가
  - 낮음 → CPU 친화성 유지, 캐시 효율 증가
- **좋은 값**: 워크로드에 따라 다름 (일반적으로 낮을수록 캐시 효율↑)

#### (3) Page Faults
- **의미**: 메모리 페이지 접근 실패 횟수
- **해석**: 메모리 접근 패턴 지표
- **좋은 값**: 낮을수록 좋음 (메모리 효율↑)

#### (4) Execution Time
- **의미**: 벤치마크 완료까지 걸린 시간
- **해석**: 전체 처리 속도 지표
- **좋은 값**: 낮을수록 좋음

### 6.3 네트워크 메트릭

#### (1) TCP 연결 시간 (RTT)
- **의미**: TCP 연결 수립까지 왕복 시간
- **단위**: ms (밀리초)
- **해석**:
  - p50: 일반적인 연결 시간
  - p99: tail latency (안정성 지표)
- **좋은 값**: 낮고 일관적일수록 좋음
- **표준값**: 인터넷 환경에서 ~1000ms (1초) 수준

#### (2) 양방향 처리량 (Bidirectional)
- **의미**: 동시 송수신 시 네트워크 처리량
- **단위**: Mbps
- **해석**: 실시간 통신 성능 지표
- **좋은 값**: 높을수록 좋음

#### (3) 소형 패킷 처리량
- **의미**: 64바이트 패킷 처리 성능
- **해석**: 패킷 처리 오버헤드 지표 (IoT, 실시간 통신)
- **좋은 값**: 높을수록 좋음

#### (4) CPU 부하 + 네트워크
- **의미**: CPU 부하 상황에서 네트워크 처리량
- **해석**: 멀티태스킹 환경에서 네트워크 성능
- **좋은 값**: 높을수록 좋음 (스케줄러 우수성 지표)

---

## 7. 실험 결과

### 7.1 로컬 벤치마크 결과 (EEVDF)

#### schbench 결과 (레이턴시)
```
설정               | RPS   | 해석
-------------------|-------|-------------------------------
balanced           | 33.53 | 높음 (균형잡힌 처리량)
baseline           | 23.43 | 표준
high_throughput    | 23.60 | 표준
low_latency        | 22.97 | 약간 낮음 (응답성 우선)
minimal_migration  | 23.20 | 표준
```

#### hackbench 결과 (오버헤드)
```
설정               | 실행시간 (초) | 해석
-------------------|--------------|----------------------------
balanced           | 0.072        | 느림 (Context Switch 많음)
baseline           | 0.026        | 빠름
high_throughput    | 0.031        | 빠름
low_latency        | 0.034        | 보통
minimal_migration  | 0.022        | 가장 빠름 (마이그레이션 적음)
```

### 7.2 CFS vs EEVDF 로컬 비교

#### CFS 파라미터 vs EEVDF 파라미터
```
┌───────────────────────────────────────────────────────┐
│  CFS (Completely Fair Scheduler)                      │
│  ─────────────────────────────────────────────────    │
│  • sched_latency_ns         (타임슬라이스 주기)       │
│  • sched_min_granularity_ns (최소 실행 시간)          │
│  • sched_wakeup_granularity_ns (선점 임계값)          │
│  • sched_migration_cost_ns  (마이그레이션 비용)       │
│                                                        │
│  EEVDF (Earliest Eligible Virtual Deadline First)     │
│  ─────────────────────────────────────────────────    │
│  • base_slice_ns            (기본 타임슬라이스)       │
│  • migration_cost_ns        (마이그레이션 비용)       │
│  • nr_migrate               (마이그레이션 개수)       │
└───────────────────────────────────────────────────────┘
```

#### schbench RPS 비교 (높을수록 좋음)
```
설정               | CFS   | EEVDF | 차이     | 분석
-------------------|-------|-------|----------|------------------------
balanced           | 23.10 | 33.53 | +45.2% ✓ | EEVDF 크게 우수
baseline           | 23.23 | 23.43 | +0.9%    | 거의 동일
high_throughput    | 24.73 | 23.60 | -4.6%    | CFS 약간 우수
low_latency        | 22.10 | 22.97 | +3.9% ✓  | EEVDF 약간 우수
minimal_migration  | 20.43 | 23.20 | +13.6% ✓ | EEVDF 우수
```

#### hackbench 실행시간 비교 (낮을수록 좋음)
```
설정               | CFS     | EEVDF   | 차이      | 분석
-------------------|---------|---------|-----------|------------------------
balanced           | 0.023   | 0.072   | +213% ✗   | CFS 크게 우수
baseline           | 0.024   | 0.026   | +8.3%     | 거의 동일
high_throughput    | 0.029   | 0.031   | +6.9%     | 거의 동일
low_latency        | 0.021   | 0.034   | +61.9% ✗  | CFS 우수
minimal_migration  | 0.023   | 0.022   | -4.3% ✓   | EEVDF 약간 우수
```

#### 로컬 벤치마크 종합 분석
```
┌─────────────────────────────────────────────────────┐
│  EEVDF 장점:                                         │
│  ✓ balanced RPS +45.2% (처리량 대폭 향상)            │
│  ✓ minimal_migration RPS +13.6% (안정적 처리)       │
│                                                      │
│  CFS 장점:                                           │
│  ✓ balanced 실행시간 -67% (빠른 완료)                │
│  ✓ low_latency 실행시간 -38% (낮은 오버헤드)        │
│                                                      │
│  결론:                                               │
│  • EEVDF: 처리량(RPS) 우수 (특히 balanced)          │
│  • CFS: 실행시간(완료속도) 우수 (특히 balanced)     │
│  • 워크로드에 따라 최적 스케줄러 다름                │
└─────────────────────────────────────────────────────┘
```

### 7.3 네트워크 벤치마크 결과 (EEVDF)

```
설정               | RTT p99 (ms) | 양방향 (Mbps) | CPU부하 (Mbps)
-------------------|--------------|---------------|---------------
balanced           | 1069.41      | 21.0          | 26.3
baseline           | 1078.54      | 22.2          | 20.0
high_throughput    | 1075.10      | 22.7          | 13.7
low_latency        | 1046.17 ★    | 13.9          | 22.5
minimal_migration  | 1056.25      | 32.8 ★        | 40.4 ★
```

### 7.4 CFS vs EEVDF 네트워크 비교

#### 네트워크 RTT p99 비교 (단위: ms)
```
설정               | CFS      | EEVDF    | 개선율
-------------------|----------|----------|--------
balanced           | 1302.74  | 1050.51  | -19.4% ✓
baseline           | 1065.89  | 1091.49  | +2.4%
high_throughput    | 1058.37  | 1044.06  | -1.4% ✓
low_latency        | 1059.28  | 1054.53  | -0.4% ✓
minimal_migration  | 1061.23  | 1054.53  | -0.6% ✓
```

#### CPU 부하 시 네트워크 처리량 비교 (단위: Mbps)
```
설정               | CFS   | EEVDF | 개선율
-------------------|-------|-------|--------
balanced           | 18.1  | 12.7  | -29.8%
baseline           | 7.17  | 14.4  | +100% ✓
high_throughput    | 14.9  | 27.2  | +82.6% ✓
low_latency        | 21.3  | 24.7  | +16.0% ✓
minimal_migration  | 13.8  | 27.3  | +97.8% ✓
```

---

## 8. NCP 네트워크 벤치마크

### 8.1 NCP 연결 이유

#### 문제 상황
```
┌─────────────────────────────────────────────┐
│  기존 로컬 벤치마크의 한계                   │
│  ----------------------------------------    │
│  • CPU, 메모리만 측정                        │
│  • 네트워크 I/O 성능 미측정                  │
│  • 실제 서버 환경 반영 부족                  │
└─────────────────────────────────────────────┘
```

#### 해결 방법: 외부 NCP 서버 활용
```
┌─────────────────────────────────────────────┐
│  NCP 서버 (223.130.152.25:5281)              │
│  ↕ 네트워크 (인터넷)                         │
│  로컬 EEVDF 시스템 (벤치마크 실행)           │
└─────────────────────────────────────────────┘
```

#### NCP 활용 이유
1. **실제 환경 시뮬레이션**
   - 인터넷 연결을 통한 실제 네트워크 지연 측정
   - 패킷 손실, 지터 등 실제 상황 반영

2. **스케줄러의 네트워크 성능 평가**
   - 네트워크 I/O 대기 시 스케줄링 효율성 측정
   - CPU 부하 + 네트워크 동시 처리 능력 평가

3. **ICMP 차단 환경 대응**
   - NCP 환경에서 ICMP (ping) 차단
   - TCP 연결 시간 측정으로 대체 (nc 활용)

### 8.2 네트워크 벤치마크 구성

#### 테스트 항목
```
[1] TCP 연결 시간 (RTT)
    └─ nc (netcat)로 TCP handshake 측정
    └─ p50, p90, p99 백분위 계산

[2] 양방향 동시 전송
    └─ iperf3 --bidir 사용
    └─ 송신/수신 동시 처리 성능

[3] 소형 패킷 (64B)
    └─ iperf3 -l 64
    └─ 패킷 처리 오버헤드 측정

[4] CPU 부하 + 네트워크
    └─ stress-ng --cpu 4 동시 실행
    └─ 멀티태스킹 환경 네트워크 성능
```

#### 환경 변수
```bash
TARGET_IP=223.130.152.25      # NCP 서버 IP
TARGET_PORT=5281              # iperf3 포트
PING_COUNT=20                 # RTT 측정 횟수
TEST_DURATION=10              # 각 테스트 시간 (초)
```

### 8.3 NCP 벤치마크 결과 의미

#### RTT p99 개선 (EEVDF)
- **balanced**: 1302ms → 1050ms (-19.4%)
  - EEVDF가 네트워크 I/O 대기 시 더 빠른 응답

#### CPU 부하 시 처리량 향상
- **minimal_migration**: 13.8 Mbps → 27.3 Mbps (+97.8%)
  - CPU 부하 상황에서 EEVDF의 우수한 멀티태스킹

---

## 9. 결론

### 9.1 주요 발견

#### (1) 로컬 벤치마크
```
✓ minimal_migration: 가장 빠른 실행 시간 (0.022초)
  → 마이그레이션 억제로 캐시 효율 극대화

✓ balanced: 가장 높은 RPS (33.53)
  → 레이턴시와 처리량의 균형점 발견
```

#### (2) 네트워크 벤치마크 (EEVDF)
```
✓ low_latency: 가장 낮은 RTT p99 (1046ms)
  → 네트워크 응답성 최적화

✓ minimal_migration: 최고 처리량
  - 양방향: 32.8 Mbps
  - CPU 부하: 40.4 Mbps
  → 캐시 친화성이 네트워크 성능에도 긍정적 영향
```

#### (3) CFS vs EEVDF 종합
```
【로컬 벤치마크】
✓ EEVDF 우수:
  - RPS 처리량: balanced +45.2%, minimal_migration +13.6%
  - 안정적인 처리 성능

✓ CFS 우수:
  - 실행 속도: balanced -67%, low_latency -38%
  - 낮은 컨텍스트 스위치 오버헤드

【네트워크 벤치마크】
✓ EEVDF 우수:
  - RTT p99 안정성: balanced -19.4%
  - CPU 부하 시 처리량: 최대 +100%
  - 네트워크 + CPU 멀티태스킹 성능

【결론】
→ EEVDF: 처리량, 멀티태스킹, 네트워크 성능 우수
→ CFS: 단순 실행 속도, 낮은 오버헤드 우수
→ 워크로드 특성에 따라 최적 스케줄러 선택 필요
```

### 9.2 파라미터 조정 가이드

```
┌─────────────────────────────────────────────────┐
│  사용 사례별 추천 설정                           │
│  ─────────────────────────────────────────────  │
│  • 웹 서버 (낮은 레이턴시): low_latency          │
│  • 배치 작업 (높은 처리량): high_throughput      │
│  • 데이터베이스 (캐시 효율): minimal_migration   │
│  • 범용 시스템: balanced                         │
└─────────────────────────────────────────────────┘
```

### 9.3 프로젝트 성과

#### 기술적 성과
1. **자동화 벤치마크 시스템 구축**
   - 5가지 설정 자동 비교
   - 파라미터 백업/복원 자동화
   - 결과 자동 수집 및 보고서 생성

2. **다양한 워크로드 측정**
   - 로컬: 레이턴시, 오버헤드, 워크로드 시나리오
   - 네트워크: RTT, 처리량, CPU 부하 영향

3. **실제 환경 반영**
   - NCP 외부 서버 연결
   - 인터넷 환경 네트워크 성능 측정

#### 학습 성과
1. **Linux 커널 스케줄러 이해**
   - CFS vs EEVDF 동작 원리
   - 커널 파라미터 영향 분석

2. **성능 측정 방법론**
   - 벤치마크 도구 활용 (schbench, hackbench, iperf3)
   - 백분위 (percentile) 기반 성능 분석

3. **시스템 튜닝 경험**
   - 파라미터 조정 전략 수립
   - Trade-off 분석 (레이턴시 vs 처리량)

### 9.4 향후 개선 방향

1. **더 많은 워크로드**
   - 데이터베이스 트랜잭션
   - 컨테이너 환경 (Docker, Kubernetes)
   - 실시간 스트리밍

2. **장기 안정성 테스트**
   - 24시간 이상 연속 측정
   - 메모리 누수, 성능 저하 확인

3. **자동화 개선**
   - CI/CD 파이프라인 통합
   - 그래프 자동 생성
   - 웹 대시보드 구축

---

## 📊 PPT 슬라이드 구성 제안

### 슬라이드 1: 표지
- 제목: EEVDF 스케줄러 벤치마크 프로젝트
- 부제: CFS vs EEVDF 성능 비교 분석

### 슬라이드 2: 프로젝트 개요
- 목표, 범위, 프로젝트 흐름도

### 슬라이드 3: 배경
- CFS vs EEVDF 비교 표
- 핵심 차이점

### 슬라이드 4: 구현 내용
- 3가지 벤치마크 종류
- 자동화 구조 다이어그램

### 슬라이드 5: 프로젝트 구조
- 디렉토리 트리
- 핵심 스크립트 역할

### 슬라이드 6: 커널 파라미터 설명
- 3가지 파라미터 의미
- 설정별 파라미터 값 표

### 슬라이드 7: 벤치마크 메트릭 해석
- schbench, hackbench, 네트워크 메트릭
- 각 메트릭의 의미와 표준값

### 슬라이드 8: 실험 결과 (로컬 - EEVDF)
- schbench, hackbench 결과 표
- 핵심 발견 하이라이트

### 슬라이드 9: CFS vs EEVDF 로컬 비교
- 파라미터 차이 (CFS 4개 vs EEVDF 3개)
- RPS 비교 표 (EEVDF balanced +45.2%)
- 실행시간 비교 표 (CFS balanced 우수)
- 종합 분석

### 슬라이드 10: 실험 결과 (네트워크 - EEVDF)
- EEVDF 네트워크 결과 표
- 설정별 성능 비교

### 슬라이드 11: CFS vs EEVDF 네트워크 비교
- RTT p99 비교 표
- CPU 부하 시 처리량 비교 표

### 슬라이드 12: NCP 네트워크 벤치마크
- NCP 연결 이유
- 네트워크 벤치마크 구성
- 결과 의미

### 슬라이드 13: 결론
- 주요 발견 (로컬 + 네트워크)
- CFS vs EEVDF 종합 분석
- 파라미터 조정 가이드
- 프로젝트 성과

### 슬라이드 14: Q&A
- 질문 받기

---

## 📌 핵심 수치 요약

### 표준값 (baseline)

#### EEVDF 파라미터
```
base_slice_ns:      2,250,000ns (2.25ms)
migration_cost_ns:  500,000ns   (0.5ms)
nr_migrate:         32
```

#### CFS 파라미터 (참고)
```
sched_latency_ns:            24,000,000ns (24ms)
sched_min_granularity_ns:    3,000,000ns  (3ms)
sched_wakeup_granularity_ns: 4,000,000ns  (4ms)
sched_migration_cost_ns:     500,000ns    (0.5ms)
```

### 최고 성능 설정
```
로컬 처리량:        minimal_migration (0.022초)
네트워크 레이턴시:  low_latency (RTT p99 1046ms)
네트워크 처리량:    minimal_migration (CPU부하 40.4 Mbps)
```

### CFS vs EEVDF 주요 차이
```
【로컬 벤치마크】
RPS (balanced):       CFS 23.10 → EEVDF 33.53 (+45.2%)
실행시간 (balanced):  CFS 0.023s → EEVDF 0.072s (+213%)

【네트워크 벤치마크】
RTT p99 (balanced):   CFS 1302ms → EEVDF 1050ms (-19.4%)
CPU부하 (minimal):    CFS 13.8 Mbps → EEVDF 27.3 Mbps (+97.8%)
```

---

**작성일**: 2025-11-21
**프로젝트**: Linux Scheduler Benchmark (EEVDF)
**작성자**: EEVDF 벤치마크 팀
