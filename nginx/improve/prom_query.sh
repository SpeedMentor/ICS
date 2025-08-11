#!/bin/bash
set -euo pipefail

NS="monitoring"
SPAN="${1:-600}"   # saniye, varsayılan 10dk
TARGET="${2:-${NGINX_TARGET:-}}"

if [ -z "${TARGET}" ]; then
  echo "Usage: $0 <seconds> <http://EXT_IP_or_HOST/healthz>"
  echo "or export NGINX_TARGET and run: $0 600"
  exit 1
fi

TS="$(date '+%Y%m%d-%H%M%S')"
LOG="prom-query-${TS}.log"
STEP="15s"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Query last ${SPAN}s for target=${TARGET}" | tee -a "$LOG"

# Prometheus'a port-forward
kubectl -n "$NS" port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 >/dev/null 2>&1 &
PF=$!
trap "kill $PF >/dev/null 2>&1 || true" EXIT
sleep 2

START=$(($(date +%s) - SPAN))
END=$(date +%s)

# label kaçar karakterler için URL encode etmeye gerek kalmasın diye --data-urlencode kullanıyoruz
curl -s "http://127.0.0.1:9090/api/v1/query_range" \
  --get --data-urlencode "query=probe_success{target=\"${TARGET}\"}" \
  --data-urlencode "start=${START}" \
  --data-urlencode "end=${END}" \
  --data-urlencode "step=${STEP}" | jq . > "probe_success-${TS}.json"

curl -s "http://127.0.0.1:9090/api/v1/query_range" \
  --get --data-urlencode "query=probe_duration_seconds{target=\"${TARGET}\"}" \
  --data-urlencode "start=${START}" \
  --data-urlencode "end=${END}" \
  --data-urlencode "step=${STEP}" | jq . > "probe_duration-${TS}.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Saved -> probe_success-${TS}.json, probe_duration-${TS}.json" | tee -a "$LOG"
