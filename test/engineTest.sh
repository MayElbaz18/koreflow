#!/bin/bash
set -e

echo "[INFO] Waiting for app pods to be ready..."
kubectl wait --for=condition=ready pod -l app=koreflow --timeout=120s

POD=$(kubectl get pods -l app=koreflow -o jsonpath="{.items[0].metadata.name}")

echo "[INFO] Running health check on pod: $POD"
kubectl exec "$POD" -- curl -sf http://localhost:8080/health || {
  echo "[ERROR] App health check failed!"
  exit 1
}

echo "[SUCCESS] Integration test passed!"