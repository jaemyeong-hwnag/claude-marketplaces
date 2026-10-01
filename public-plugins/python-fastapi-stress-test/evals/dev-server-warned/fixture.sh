#!/usr/bin/env bash
# FastAPI 주문 서비스. Dockerfile 이 개발 서버(fastapi dev)로 띄운다
set -e
git init -q -b main .
git config user.email eval@example.com
git config user.name eval
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
printf 'FROM python:3.13-slim\nCOPY . /app\nWORKDIR /app\nRUN pip install -r requirements.txt\nCMD ["fastapi", "dev", "app/main.py", "--host", "0.0.0.0"]\n' > Dockerfile
git add -A
git commit -qm init
