#!/bin/bash
set -euo pipefail

NS="monitoring"
GRAFANA_HOST="grafana.local"   # DNS yoksa /etc/hosts ile Ingress IP’ye eşleyebilirsin

TS="$(date '+%Y%m%d-%H%M%S')"
LOG="prom-install-${TS}.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] kube-prometheus-stack INSTALL start" | tee -a "$LOG"

for b in kubectl helm; do command -v "$b" >/dev/null || { echo "Missing $b" | tee -a "$LOG"; exit 1; }; done

# repo + ns
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS" | tee -a "$LOG"

# install (helm --wait: chart kendi resource’larının ready olmasını bekler)
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Installing kube-prometheus-stack (Grafana Ingress)" | tee -a "$LOG"
helm upgrade --install kps prometheus-community/kube-prometheus-stack -n "$NS" \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=gce \
  --set grafana.ingress.hosts[0]="$GRAFANA_HOST" \
  --set grafana.service.type=ClusterIP \
  --set prometheus.service.type=ClusterIP \
  --wait --timeout 20m | tee -a "$LOG"

# ekstra bekleme: label-bazlı (sürümden bağımsız)
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Waiting by labels (Grafana/Prometheus pods Ready)" | tee -a "$LOG"
kubectl -n "$NS" wait --for=condition=Ready pod -l app.kubernetes.io/name=grafana --timeout=10m | tee -a "$LOG"
kubectl -n "$NS" wait --for=condition=Ready pod -l app.kubernetes.io/name=prometheus --timeout=10m | tee -a "$LOG"

# grafana ingress IP (hosts için ip yazdır)
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Waiting for Grafana Ingress IP..." | tee -a "$LOG"
for i in {1..60}; do
  GIP="$(kubectl -n "$NS" get ing kps-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
  [ -n "$GIP" ] && break
  sleep 5
done
GIP="${GIP:-}"
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Grafana Ingress IP: ${GIP:-n/a} (host: $GRAFANA_HOST)" | tee -a "$LOG"
[ -n "$GIP" ] && echo "$GIP  $GRAFANA_HOST" | tee -a "$LOG"

# grafana admin şifresi (chart default: prom-operator; yine de secret’tan çekelim)
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Grafana admin password:" | tee -a "$LOG"
kubectl -n "$NS" get secret kps-grafana -o jsonpath="{.data.admin-password}" | base64 -d | tee -a "$LOG"; echo

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] kube-prometheus-stack INSTALL done" | tee -a "$LOG"
echo "Grafana URL: http://$GRAFANA_HOST  (admin user: admin)" | tee -a "$LOG"
