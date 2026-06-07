#!/usr/bin/env bash
set -euo pipefail

IN_DIR="${IN_DIR:-/tmp/electgo-argocd-export}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

for file in argocd-repo-secrets.yaml argocd-cluster-secrets.yaml argocd-rbac.yaml argocd-cm.yaml argocd-projects.yaml argocd-apps.yaml; do
  path="$IN_DIR/$file"
  if [[ ! -s "$path" ]]; then
    echo "missing export file: $path" >&2
    exit 1
  fi
  kubectl apply -n "$NAMESPACE" -f "$path"
done
