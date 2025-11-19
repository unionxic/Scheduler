# 커널 파라미터 설정 파일

이 디렉토리의 `.conf` 파일들은 환경변수처럼 사용할 수 있는 커널 파라미터 설정입니다.

## 📁 사용 가능한 설정

### 1. `default.conf` - 기본 설정
- 대부분의 리눅스 시스템 기본값
- Baseline 비교용

### 2. `low_latency.conf` - 낮은 레이턴시
- 응답 시간 최소화
- 실시간성이 중요한 워크로드
- Context switch 증가, Latency 감소 예상

### 3. `high_throughput.conf` - 높은 처리량
- 전체 처리량 최대화
- 배치 작업, 서버 워크로드
- Context switch 감소, RPS 증가 예상

### 4. `minimal_migration.conf` - 마이그레이션 최소화
- 캐시 효율성 향상
- CPU 친화성이 중요한 워크로드
- CPU migration 감소 예상

### 5. `aggressive_preempt.conf` - 공격적 선점
- 극단적 저지연 (실험용)
- 높은 오버헤드 예상

## 🚀 사용 방법

### 개별 설정으로 실행
```bash
# 낮은 레이턴시 설정으로 벤치마크 실행
./scripts/run_with_config.sh configs/low_latency.conf

# 높은 처리량 설정으로 벤치마크 실행
./scripts/run_with_config.sh configs/high_throughput.conf
```

### 모든 설정 자동 비교
```bash
# 모든 .conf 파일로 자동 벤치마크 실행
./scripts/run_all_configs.sh

# 결과: results/config_comparison/comparison_results.txt
```

## ✏️ 커스텀 설정 만들기

새로운 설정 파일을 만들어서 실험할 수 있습니다:

```bash
# configs/my_custom.conf
SCHED_LATENCY_NS=12000000
SCHED_MIN_GRANULARITY_NS=1500000
SCHED_WAKEUP_GRANULARITY_NS=2000000
SCHED_MIGRATION_COST_NS=1000000

DESCRIPTION="나만의 커스텀 설정"
```

```bash
# 사용
./scripts/run_with_config.sh configs/my_custom.conf
```

## 📊 파라미터 설명

### `SCHED_LATENCY_NS`
- CPU 바운드 태스크의 목표 선점 지연 시간
- **낮을수록**: 빠른 응답, 높은 컨텍스트 스위칭
- **높을수록**: 높은 처리량, 낮은 컨텍스트 스위칭

### `SCHED_MIN_GRANULARITY_NS`
- 최소 선점 세분성
- 태스크가 선점되기 전 최소 실행 시간

### `SCHED_WAKEUP_GRANULARITY_NS`
- 깨우기 선점 세분성
- **낮을수록**: 빠른 깨우기, 높은 선점
- **높을수록**: 선점 감소, 안정적 실행

### `SCHED_MIGRATION_COST_NS`
- 태스크 마이그레이션 비용
- **낮을수록**: 자유로운 마이그레이션, 부하 분산
- **높을수록**: 마이그레이션 억제, 캐시 효율성

## ⚠️ 주의사항

- 모든 스크립트는 **자동으로 원본 값을 복원**합니다 (trap EXIT)
- sudo 권한이 필요합니다
- 극단적인 값은 시스템 불안정을 초래할 수 있습니다

