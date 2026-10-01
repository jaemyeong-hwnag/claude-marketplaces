---
name: stress-environment-create
description: 부하·스트레스 테스트를 돌릴 환경을 local·Docker Compose·Kubernetes 중에서 꾸밀 때 사용한다. 부하기와 대상 분리, CPU·메모리 고정, 오토스케일 끄기, 환경 기록을 정한다. 트리거 — "부하 테스트 환경", "docker compose 로 부하", "k8s 에서 k6", "부하기 어디서", "테스트 환경 구성".
---

# 스트레스 테스트 환경

규칙 원본: [`references/stress-test-rules.md`](../../references/stress-test-rules.md) — ST-01 · ST-33 ~ ST-35
템플릿: [`references/stress-test-templates.md`](../../references/stress-test-templates.md) — 4 · 5절

## 1. 환경을 고른다

| 환경 | 언제 | 주의 |
|---|---|---|
| local (같은 머신, 프로세스) | 스크립트 점검 · 마이크로 비교 | 부하기와 대상이 CPU 를 나눈다. 용량 수치로 보고하지 않는다 |
| Docker Compose | 자원을 고정해 재현 가능하게 잴 때 | `cpus` · `mem_limit` 합이 호스트보다 작아야 한다 |
| Kubernetes Job | 운영과 같은 네트워크 · 리소스 정책에서 잴 때 | replicas 고정 · HPA 끄기 · 부하기를 다른 노드에 |
| 별도 부하기 머신 | 대상이 큰 용량일 때 | 부하기 한 대가 포화되면 여러 대 — 결과는 원자료로 합친다 (ST-31) |

## 2. 꼭 할 것

1. **부하기와 대상을 떼어 놓는다** (ST-34). 같은 머신이면 컨테이너 CPU 를 나눠 고정하고, 실행 중 부하기 CPU 가 포화되지 않는지 본다 (`docker stats` · `kubectl top pod`)
2. **자원을 고정한다**. CPU · 메모리 limit 을 두고 그 값을 결과에 적는다
   - 컨테이너에서 런타임이 limit 을 인식하는지는 언어 플러그인이 본다 (JVM 힙 · GOMAXPROCS · 워커 수)
3. **오토스케일을 끈다** (ST-35). breakpoint · stress 동안 HPA · 클라우드 오토스케일이 켜져 있으면 한계 대신 청구 한도를 잰다
4. **대상 호스트를 허용 목록에 둔다** (ST-01)
   - 컨테이너 · 서비스 이름(점 없는 이름) · 사설 IP · `*.local` · `*.internal` 은 이미 허용된다
   - 전용 스테이징 도메인이면 사용자 확인 뒤 `.claude/settings.json` 에 넣는다
     ```json
     { "env": { "STRESS_TEST_ALLOWED_HOSTS": "staging.example.com,*.perf.example.com" } }
     ```
5. **환경을 기록한다** (ST-33)
   - 대상 · 부하기의 이미지 태그(버전)
   - CPU · 메모리 limit, 노드 · 인스턴스 유형
   - DB 크기, 반복 수, 실행 시각

## 3. 같은 결과가 다시 나오게

- 같은 인스턴스 유형도 성능이 다르다 (Leitner & Cito 2016). 비교는 **같은 머신에서 번갈아** 돌린다
- 클라우드 공유 인스턴스(버스트형)는 크레딧이 떨어지면 성능이 꺾인다. 고정 성능 유형을 쓴다
- 단계 사이에 쉬어 대기열 · 커넥션이 비워지게 한다
- 캐시 · DB 를 매 실행 같은 상태로 되돌린다 (데이터 스냅샷)

## 4. 절차

1. 1절에서 환경을 고른다
2. 템플릿 4절(Compose) 또는 5절(k8s)을 가져와 이미지 · 포트 · 자원을 바꾼다
3. `RATE=5`, `UNIT=5s` 로 짧게 돌려 연결을 확인한다
4. 환경 기록을 결과 디렉터리에 같이 남긴다
5. 끝나면 정리한다 — `docker compose down` · `kubectl delete namespace stress-test`
