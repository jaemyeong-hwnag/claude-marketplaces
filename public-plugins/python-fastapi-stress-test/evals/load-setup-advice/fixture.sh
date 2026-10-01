#!/usr/bin/env bash
# FastAPI 주문 서비스. 워커 4개 + prometheus 인데 멀티프로세스 디렉터리가 없다 — 저장소 초기화를 하지 않는다 (하면 eval-all 이 Bash 를 줘 샌드박스가 필요하다)
set -e
mkdir -p app
printf "fastapi[standard]\nprometheus-fastapi-instrumentator\n" > requirements.txt
cat > app/main.py <<'PY'
import time

from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

app = FastAPI()
Instrumentator().instrument(app).expose(app)


@app.get("/orders")
def orders():
    time.sleep(0.05)
    return []
PY
cat > load.js <<'JS'
import http from "k6/http";
export const options = { scenarios: { s: { executor: "constant-arrival-rate", rate: 50, timeUnit: "1s", duration: "10s", preAllocatedVUs: 20, maxVUs: 200 } } };
export default function () { http.get("http://127.0.0.1:8000/orders"); }
JS
printf 'FROM python:3.13-slim\nCOPY . /app\nWORKDIR /app\nRUN pip install -r requirements.txt\nCMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--workers", "4"]\n' > Dockerfile
