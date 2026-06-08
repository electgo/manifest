#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
REPO_URL="${ARGOCD_REPO_URL:-https://github.com/electgo/manifest.git}"
REPO_PROJECT="${ARGOCD_REPO_PROJECT:-management}"
INGRESS_NAME="${ARGOCD_INGRESS_NAME:-argocd-server}"

find_active_repo_secrets() {
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r --arg url "$REPO_URL" '
      .items[]
      | select((.data.url // "" | @base64d) == $url)
      | .metadata.name
    '
}

active_repo_secrets="$(find_active_repo_secrets)"
if [[ -z "$active_repo_secrets" ]]; then
  echo "FAIL no active ArgoCD repository secret for $REPO_URL" >&2
  exit 1
fi

while IFS= read -r secret_name; do
  [[ -z "$secret_name" ]] && continue
  patch="$(jq -n --arg project "$REPO_PROJECT" '{stringData: {project: $project}}')"
  kubectl -n "$NAMESPACE" patch secret "$secret_name" --type merge -p "$patch"
done <<< "$active_repo_secrets"

for stale_secret in electgo-manifest-repo repo-electgo-manifest; do
  if ! kubectl -n "$NAMESPACE" get secret "$stale_secret" >/dev/null 2>&1; then
    continue
  fi

  stale_url="$(
    kubectl -n "$NAMESPACE" get secret "$stale_secret" -o json |
      jq -r '.data.url // "" | @base64d'
  )"
  secret_type="$(
    kubectl -n "$NAMESPACE" get secret "$stale_secret" -o json |
      jq -r '.metadata.labels["argocd.argoproj.io/secret-type"] // ""'
  )"

  if [[ "$secret_type" == "" && ( "$stale_url" == "$REPO_URL" || "$stale_url" == "${REPO_URL%.git}" ) ]]; then
    kubectl -n "$NAMESPACE" delete secret "$stale_secret"
  fi
done

if kubectl -n "$NAMESPACE" get ingress "$INGRESS_NAME" >/dev/null 2>&1; then
  kubectl -n "$NAMESPACE" annotate ingress "$INGRESS_NAME" \
    traefik.ingress.kubernetes.io/router.middlewares- || true
fi

if kubectl api-resources --api-group=traefik.io --no-headers 2>/dev/null | awk '{print $1}' | grep -qx 'middlewares'; then
  kubectl -n "$NAMESPACE" delete middleware \
    argocd-create-app-project-redirect \
    argocd-repo-apps-project-redirect \
    --ignore-not-found
fi

bad_projects="$(
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r --arg url "$REPO_URL" --arg project "$REPO_PROJECT" '
      .items[]
      | select((.data.url // "" | @base64d) == $url)
      | select((.data.project // "" | @base64d) != $project)
      | .metadata.name
    '
)"
if [[ -n "$bad_projects" ]]; then
  echo "FAIL repository secrets missing project $REPO_PROJECT: $bad_projects" >&2
  exit 1
fi

repo_count="$(
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r --arg url "$REPO_URL" '
      [.items[] | select((.data.url // "" | @base64d) == $url)] | length
    '
)"
if [[ "$repo_count" != "1" ]]; then
  echo "FAIL expected 1 active repository secret for $REPO_URL, got $repo_count" >&2
  exit 1
fi

echo "repository state repaired"
