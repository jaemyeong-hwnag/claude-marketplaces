#!/usr/bin/env bash
# Django 주문 서비스. django-prometheus 는 있지만 in-flight 게이지가 없고 Gunicorn 워커 수를 정하지 않았다 — 저장소 초기화를 하지 않는다 (하면 eval-all 이 Bash 를 줘 샌드박스가 필요하다)
set -e
mkdir -p shop orders
printf "Django==6.0\ngunicorn\ndjango-prometheus\n" > requirements.txt
cat > manage.py <<'PY'
import os
import sys

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "shop.settings")
from django.core.management import execute_from_command_line

execute_from_command_line(sys.argv)
PY
touch shop/__init__.py orders/__init__.py
cat > shop/settings.py <<'PY'
SECRET_KEY = "eval"
DEBUG = True
ALLOWED_HOSTS = ["*"]
ROOT_URLCONF = "shop.urls"
INSTALLED_APPS = ["django.contrib.contenttypes", "django_prometheus", "orders"]
MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": "db.sqlite3"}}
PY
cat > shop/urls.py <<'PY'
from django.urls import include, path

from orders import views

urlpatterns = [path("orders", views.order_list), path("", include("django_prometheus.urls"))]
PY
cat > orders/views.py <<'PY'
import time

from django.http import JsonResponse


def order_list(request):
    time.sleep(0.05)
    return JsonResponse({"orders": []})
PY
cat > load.js <<'JS'
import http from "k6/http";
export const options = { scenarios: { s: { executor: "constant-arrival-rate", rate: 50, timeUnit: "1s", duration: "10s", preAllocatedVUs: 20, maxVUs: 200 } } };
export default function () { http.get("http://127.0.0.1:8000/orders"); }
JS
sed -i.bak 's/^DEBUG = True/DEBUG = False/' shop/settings.py && rm -f shop/settings.py.bak
printf 'FROM python:3.13-slim\nCOPY . /app\nWORKDIR /app\nRUN pip install -r requirements.txt\nCMD ["gunicorn", "shop.wsgi:application", "-b", "0.0.0.0:8000"]\n' > Dockerfile
