#!/bin/bash
set -euo pipefail

NS="default"
TS="$(date '+%Y%m%d-%H%M%S')"
DATE_TIME="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Step4: NGINX deploy starting (TS=${TS})"

# 1) HTML ConfigMap (timestamp göm)
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Apply HTML ConfigMap (k8s/configmap.yaml)" | tee "nginx-apply-${TS}.log"
export DATE_TIME
envsubst < configmap.yaml | kubectl apply -n "${NS}" -f - 2>&1 | tee -a "nginx-apply-${TS}.log"

# 2) Tuning ConfigMap
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Apply tuning ConfigMap (k8s/nginx-tuning.yaml)" | tee -a "nginx-apply-${TS}.log"
kubectl apply -n "${NS}" -f nginx-tuning.yaml 2>&1 | tee -a "nginx-apply-${TS}.log"

# 3) Deployment & Service
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Apply deployment & service (k8s/nginx-deployment.yaml)" | tee -a "nginx-apply-${TS}.log"
kubectl apply -n "${NS}" -f nginx-deployment.yaml 2>&1 | tee -a "nginx-apply-${TS}.log"

# 4) Ingress
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Apply ingress (k8s/nginx-ingress.yaml)" | tee -a "nginx-apply-${TS}.log"
kubectl apply -n "${NS}" -f nginx-ingress.yaml 2>&1 | tee -a "nginx-apply-${TS}.log"

# 5) Rollout
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Wait rollout (deploy/nginx-optimized)" | tee -a "nginx-apply-${TS}.log"
kubectl -n "${NS}" rollout status deploy/nginx-optimized --timeout=300s 2>&1 | tee -a "nginx-apply-${TS}.log"

# 6) Ingress IP & kanıt
EXT_IP="$(kubectl -n "${NS}" get ing nginx-web-ing -o jsonpath='{.status.loadBalancer.ingress[0].ip}' || true)"
echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Ingress IP: ${EXT_IP}" | tee "nginx-proof-${TS}.log"

if [ -n "${EXT_IP}" ]; then
  curl -s "http://${EXT_IP}/" | tee "nginx-page-${TS}.html" >/dev/null
  curl -si "http://${EXT_IP}/" | tee -a "nginx-proof-${TS}.log" >/dev/null
else
  echo "Ingress IP not ready yet" | tee -a "nginx-proof-${TS}.log"
fi

# 7) Canlı config export (timestamp’li)
mkdir -p configs
kubectl get configmap nginx-html    -n "${NS}" -o yaml > "configs/nginx-html-${TS}.yaml"
kubectl get configmap nginx-tuning  -n "${NS}" -o yaml > "configs/nginx-tuning-${TS}.yaml"
kubectl get deployment nginx-optimized -n "${NS}" -o yaml > "configs/nginx-deploy-${TS}.yaml"
kubectl get service nginx-svc       -n "${NS}" -o yaml > "configs/nginx-svc-${TS}.yaml"
kubectl get ingress nginx-web-ing   -n "${NS}" -o yaml > "configs/nginx-ing-${TS}.yaml"

echo "[$(date '+%Y-%m-%d %H:%M:%S%z')] Step4: done"
