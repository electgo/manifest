#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${OUT_DIR:-/tmp/electgo-argocd-export}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

mkdir -p "$OUT_DIR"

kubectl get applications -n "$NAMESPACE" -o yaml > "$OUT_DIR/argocd-apps.yaml"
kubectl get appprojects -n "$NAMESPACE" -o yaml > "$OUT_DIR/argocd-projects.yaml"
kubectl get secrets -n "$NAMESPACE" -l argocd.argoproj.io/secret-type=repository -o yaml > "$OUT_DIR/argocd-repo-secrets.yaml"
kubectl get secrets -n "$NAMESPACE" -l argocd.argoproj.io/secret-type=cluster -o yaml > "$OUT_DIR/argocd-cluster-secrets.yaml"
kubectl get configmap argocd-rbac-cm -n "$NAMESPACE" -o yaml > "$OUT_DIR/argocd-rbac.yaml"
kubectl get configmap argocd-cm -n "$NAMESPACE" -o yaml > "$OUT_DIR/argocd-cm.yaml"

echo "$OUT_DIR"
