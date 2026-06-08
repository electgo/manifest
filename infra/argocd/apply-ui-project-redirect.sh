#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl apply -f "$SCRIPT_DIR/ui-project-redirect.yaml"
kubectl -n "$NAMESPACE" annotate ingress argocd-server \
  traefik.ingress.kubernetes.io/router.middlewares='argocd-argocd-create-app-project-redirect@kubernetescrd,argocd-argocd-repo-apps-project-redirect@kubernetescrd' \
  --overwrite
