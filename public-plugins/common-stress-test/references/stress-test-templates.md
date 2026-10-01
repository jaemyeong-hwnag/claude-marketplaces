# 스트레스 테스트 템플릿

모두 실제로 돌려 본 것이다 (k6 v2.3.0 · Docker 28 · Kubernetes 1.32 docker-desktop, 2026-10).
규칙은 [`stress-test-rules.md`](stress-test-rules.md), 근거는 [`stress-test-methods.md`](stress-test-methods.md).

## 1. k6 스크립트 — 유형 하나로 고른다

`TYPE` 으로 유형을 고른다. 모두 open 모델(ST-02)이고, `maxVUs`(ST-05) · thresholds(ST-03) · p99(ST-04) 를 갖췄다.
`UNIT` 은 단계 길이 배수다 — 기본 `1m`, 스크립트 점검은 `UNIT=1s` 로 짧게 돌린다.

| TYPE | 모양 (UNIT=1m) | 판정 |
|---|---|---|
| `load` | 2분 램프 → RATE 10분 → 1분 하강 | SLO |
| `stress` | RATE×2 까지 2분 → 10분 → 2분 하강 | 저하 정도 · 회복 |
| `spike` | RATE 1분 → 30초에 RATE×5 → 30초에 RATE → 5분 관찰 | 회복 시간 |
| `soak` | RATE 4시간 | 지연 · 메모리 기울기 |
| `breakpoint` | 30분 동안 0 → RATE×20, p99 1초를 넘으면 중단 (`abortOnFail`) | 지속 가능 용량 |
| `step` | RATE 로 UNIT 동안 고정 — 아래 단계 루프용 | 단계 한 줄 |

```javascript
// TYPE=load|stress|spike|soak|breakpoint|step  BASE_URL(host:port, 스킴 생략 시 http)  RATE(평균 rps)  UNIT(단계 길이 배수, 기본 1m)
import http from 'k6/http';
import { check } from 'k6';

const TARGET = __ENV.BASE_URL || 'localhost:8080';
const BASE_URL = TARGET.includes('://') ? TARGET : `http${'://'}${TARGET}`;
const TYPE = __ENV.TYPE || 'load';
const RATE = Number(__ENV.RATE || 100);
const UNIT = __ENV.UNIT || '1m';
const u = (n) => `${n * parseFloat(UNIT)}${UNIT.replace(/[0-9.]/g, '')}`;

const open = (stages, extra = {}) => ({
  executor: 'ramping-arrival-rate', startRate: 0, timeUnit: '1s', stages,
  preAllocatedVUs: Math.max(10, RATE), maxVUs: Math.max(100, RATE * 10), ...extra,
});
const scenarios = {
  load: open([{ duration: u(2), target: RATE }, { duration: u(10), target: RATE }, { duration: u(1), target: 0 }]),
  stress: open([{ duration: u(2), target: RATE * 2 }, { duration: u(10), target: RATE * 2 }, { duration: u(2), target: 0 }]),
  spike: open([{ duration: u(1), target: RATE }, { duration: u(0.5), target: RATE * 5 }, { duration: u(0.5), target: RATE }, { duration: u(5), target: RATE }]),
  soak: open([{ duration: u(5), target: RATE }, { duration: u(240), target: RATE }, { duration: u(5), target: 0 }]),
  breakpoint: open([{ duration: u(30), target: RATE * 20 }]),
  step: { executor: 'constant-arrival-rate', rate: RATE, timeUnit: '1s', duration: u(1), preAllocatedVUs: Math.max(10, RATE), maxVUs: Math.max(100, RATE * 10) },
};

export const options = {
  discardResponseBodies: true,
  summaryTrendStats: ['avg', 'min', 'med', 'p(95)', 'p(99)', 'p(99.9)', 'max'],
  scenarios: { [TYPE]: scenarios[TYPE] },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{expected_response:true}': ['p(99)<300'],
    ...(TYPE === 'breakpoint' ? { http_req_duration: [{ threshold: 'p(99)<1000', abortOnFail: true, delayAbortEval: '10s' }] } : {}),
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/work`);
  check(res, { 'status 200': (r) => r.status === 200 });
}
```

- 요청(`/work`)은 대상 엔드포인트로 바꾼다. 여러 엔드포인트면 운영 비율대로 섞는다 (운영 프로파일 — `stress-test-methods.md` 10절)
- thresholds 의 지연은 `{expected_response:true}` — 성공 요청만 본다 (ST-32)
- `preAllocatedVUs` 는 RATE (Little: 지연 1초까지 RATE × 1 s 개가 동시에 돈다), `maxVUs` 는 그 10배. 부족하면 `dropped_iterations` 가 생긴다 (ST-12)
- breakpoint 가 중단되면 종료 코드 99 다 — threshold 실패와 같다

## 2. 단계 루프 — knee · USL · 지속 가능 용량

도착률을 6단계 이상(ST-11) 올리며 단계마다 요약을 남기고 판정한다. 단계 사이에 쉬어 앞 단계의 대기열이 넘어오지 않게 한다.

```bash
P="${CLAUDE_PLUGIN_ROOT}/scripts"
mkdir -p out
"$P/stress-step-generate.sh" --header > out/steps.csv
for r in 50 100 150 200 250 300 400; do
  k6 run -q -e TYPE=step -e RATE=$r -e UNIT=60s -e BASE_URL=localhost:8080 \
    --summary-export=out/step-$r.json stress.js            # threshold 실패(99)여도 다음 단계로 간다
  "$P/stress-step-generate.sh" --load $r out/step-$r.json >> out/steps.csv
  sleep 15
done
"$P/stress-report-generate.sh" --model open --slo-p99 300 out/steps.csv
```

- 서버 in-flight 평균을 알면 `--inflight` 로 넣는다 → Little 검사(ST-13)
- closed 모델로 USL 을 잴 때는 동시 사용자 수를 load 로 두고 `--model closed` (executor `constant-vus`, 파일에 `stress-test: closed-model`)

**실측** (동시 처리 4 · 요청당 20 ms 서버, 이론 용량 200 rps)

| load | 처리량 | p99 ms | dropped | 판정 |
|---|---|---|---|---|
| 50 | 50.0 | 25.1 | 0 | ✅ |
| 100 | 99.9 | 24.7 | 0 | ✅ |
| 150 | 149.8 | 27.5 | 0 | ✅ |
| 180 | 179.8 | 27.6 | 0 | ✅ |
| 200 | 188.6 | 569.0 | 65 | ❌ |
| 220 | 188.4 | 1355.5 | 214 | ❌ |
| 260 | 184.0 | 2142.2 | 747 | ❌ |

지속 가능 용량 180 · 처리량 knee 180 · p99 knee 180.

## 3. 다른 도구의 결과를 같은 CSV 로

| 도구 | 남길 파일 | 주의 |
|---|---|---|
| k6 | `--summary-export=out.json` 또는 `handleSummary` 의 JSON | 기본 요약에 p99 가 없다 — `summaryTrendStats` 에 넣는다 |
| Locust | `--headless --csv=out` → `out_stats.csv` | closed 루프다 (ST-02). 분위수가 2자리 유효숫자로 반올림된다 |
| JMeter | `-n -t plan.jmx -l res.jtl -e -o report` → `report/statistics.json` | closed 루프다. `pct1/2/3` 기본 90/95/99 — 바꿨으면 열이 달라진다 |
| Gatling | 콘솔 출력을 파일로 (`... | tee gatling.txt`) | 3.2 와 3.16 형식 모두 읽는다. 3.16 은 `global_stats.json` 을 쓰지 않는다. 분위수 기본 50/75/95/99 |

```bash
"$P/stress-step-generate.sh" --load 200 out_stats.csv              # Locust
"$P/stress-step-generate.sh" --load 200 report/statistics.json     # JMeter
"$P/stress-step-generate.sh" --load 200 --tool gatling gatling.txt # Gatling
```

## 4. 환경 — Docker Compose

대상과 부하기를 **다른 컨테이너 · 고정 자원**으로 둔다 (ST-33 · ST-34). 결과와 같이 이 파일을 남긴다.

```yaml
# 대상과 부하기를 다른 컨테이너 · 고정 자원으로 — 결과에 이 파일을 같이 남긴다
services:
  app:
    image: nginx:alpine          # 대상 앱 이미지로 바꾼다
    cpus: "1.0"
    mem_limit: 512m
  k6:
    image: grafana/k6
    profiles: ["load"]
    cpus: "1.0"
    depends_on: [app]
    volumes: ["./:/scripts"]
    working_dir: /scripts
    environment:
      BASE_URL: app
    command: ["run", "--summary-export=/scripts/out/summary.json", "stress.js"]
```

```bash
docker compose up -d app
docker compose run --rm -e TYPE=step -e RATE=100 -e UNIT=60s k6
docker compose down
```

- `BASE_URL` 의 `app` 은 점 없는 서비스 이름이라 ST-01 을 통과한다
- 한 머신에서 돌리면 CPU 를 나눠 쓴다. `cpus` 합이 호스트 코어보다 작게 두고, 부하기 CPU 가 포화되지 않는지 본다 (`docker stats`)

## 5. 환경 — Kubernetes Job

같은 클러스터 안에서 부하기를 Job 으로 띄워 Service 이름으로 겨눈다. 대상 Deployment 는 replicas 를 고정하고 HPA 를 끈다 (ST-35).

```yaml
# 같은 클러스터 안에서 부하기를 Job 으로 — 대상 Service 이름(점 없는 이름)으로 겨눈다
apiVersion: v1
kind: Namespace
metadata: { name: stress-test }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: app, namespace: stress-test }
spec:
  replicas: 1                      # breakpoint · stress 동안 HPA 를 끄고 고정한다 (ST-35)
  selector: { matchLabels: { app: app } }
  template:
    metadata: { labels: { app: app } }
    spec:
      containers:
        - name: app
          image: nginx:alpine      # 대상 앱 이미지로 바꾼다
          resources:
            requests: { cpu: "1", memory: 256Mi }
            limits: { cpu: "1", memory: 256Mi }
---
apiVersion: v1
kind: Service
metadata: { name: app, namespace: stress-test }
spec: { selector: { app: app }, ports: [{ port: 80 }] }
---
apiVersion: batch/v1
kind: Job
metadata: { name: k6-step, namespace: stress-test }
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      affinity:                    # 부하기를 대상과 다른 노드에 둔다 (노드가 하나면 효과 없음)
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm: { topologyKey: kubernetes.io/hostname, labelSelector: { matchLabels: { app: app } } }
      containers:
        - name: k6
          image: grafana/k6
          # 로그에는 요약 JSON 만 남긴다 — kubectl logs job/k6-step > summary.json
          command: ["sh", "-c", "k6 run -q --summary-export=/tmp/summary.json /scripts/stress.js >/dev/null 2>&1; code=$?; cat /tmp/summary.json; exit $code"]
          env:
            - { name: BASE_URL, value: "app" }
            - { name: TYPE, value: "step" }
            - { name: RATE, value: "100" }
            - { name: UNIT, value: "20s" }
          resources:
            requests: { cpu: "1", memory: 256Mi }
          volumeMounts: [{ name: scripts, mountPath: /scripts }]
      volumes:
        - name: scripts
          configMap: { name: k6-scripts }
```

```bash
kubectl create namespace stress-test
kubectl -n stress-test create configmap k6-scripts --from-file=stress.js
kubectl apply -f k8s.yaml
kubectl -n stress-test wait --for=condition=complete job/k6-step --timeout=10m
kubectl -n stress-test logs job/k6-step > out/step-100.json     # 요약 JSON 만 나온다
kubectl delete namespace stress-test
```

- `kubectl logs` 는 stdout 과 stderr 를 합친다 — k6 출력은 버리고 요약 파일만 `cat` 한다 (`--summary-mode=disabled` 는 `--summary-export` 까지 끈다)
- 부하기를 여러 Pod 로 나누면 요약도 여럿이다. 분위수를 평균 내지 말고(ST-31) 원자료(`--out` 로 내보낸 요청 단위 지표)를 모아 다시 계산한다
