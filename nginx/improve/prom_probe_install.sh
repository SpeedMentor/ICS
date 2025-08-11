#!/bin/bash
set -euo pipefail

NS="monitoring"
TARGET="${1:-${NGINX_TARGET:-}}"

if [ -z "${TARGET}" ]; then
  echo "Usage: $0 <http://EXT_IP_or_HOST/healthz>"
  echo "or export NGINX_TARGET and run without args."
  exit 1
fi

TS="$(date '+%Y%m%d-%H%M%S')"
LOG="prom-probe-install-${TS}.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Blackbox + Probe install start -> TARGET=${TARGET}" | tee -a "$LOG"

# prereqs
for b in kubectl helm; do command -v "$b" >/dev/null || { echo "Missing $b" | tee -a "$LOG"; exit 1; }; done
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" | tee -a "$LOG"

# blackbox exporter
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Installing blackbox-exporter" | tee -a "$LOG"
helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter -n "$NS" \
  --wait --timeout 10m | tee -a "$LOG"

# Probe (Prometheus Operator CRD)
cat <<YAML | kubectl apply -n "$NS" -f - | tee -a "$LOG"
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: nginx-health-probe
spec:
  prober:
    url: http://blackbox-prometheus-blackbox-exporter.${NS}.svc.cluster.local:9115
  module: http_2xx
  targets:
    staticConfig:
      static:
        - "${TARGET}"
YAML

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Probe created. Waiting pods Ready..." | tee -a "$LOG"
kubectl -n "$NS" wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout=10m | tee -a "$LOG"
kubectl -n "$NS" wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus-blackbox-exporter --timeout=5m | tee -a "$LOG"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Done. In Grafana (http://grafana.local): query 'probe_success' & 'probe_duration_seconds'." | tee -a "$LOG"
