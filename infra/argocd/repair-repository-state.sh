#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
REPO_URL="${ARGOCD_REPO_URL:-https://github.com/electgo/manifest.git}"
REPO_PROJECT="${ARGOCD_REPO_PROJECT:-management}"
INGRESS_NAME="${ARGOCD_INGRESS_NAME:-argocd-server}"

repo_project_for_url() {
  case "$1" in
    https://github.com/electgo/manifest.git) echo management ;;
    https://github.com/electgo/pim-master) echo product ;;
    https://github.com/electgo/pim-bucket-upload.git) echo product ;;
    https://github.com/electgo/product-ai-enrich) echo product ;;
    https://github.com/electgo/pim-sku-finder) echo product ;;
    https://github.com/electgo/pim-partners-bundling) echo product ;;
    https://github.com/electgo/pim-chatbot) echo product ;;
    https://github.com/electgo/pim-partners-punchoutclient.git) echo product ;;
    https://github.com/electgo/electgo-be-utils) echo marketplace ;;
    https://github.com/electgo/electgo-be-user) echo marketplace ;;
    https://github.com/electgo/electgo-be-product) echo marketplace ;;
    https://github.com/electgo/matomo.git) echo platform ;;
    https://charts.fairwinds.com/stable) echo platform ;;
    https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner) echo management ;;
    https://project-zot.github.io/helm-charts) echo management ;;
    https://releases.rancher.com/server-charts/alpha) echo management ;;
    https://prometheus-community.github.io/helm-charts) echo observability ;;
    https://grafana.github.io/helm-charts) echo observability ;;
    *) return 1 ;;
  esac
}

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

all_repo_secrets="$(
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r '.items[].metadata.name'
)"

while IFS= read -r secret_name; do
  [[ -z "$secret_name" ]] && continue
  repo_url="$(
    kubectl -n "$NAMESPACE" get secret "$secret_name" -o json |
      jq -r '.data.url // "" | @base64d'
  )"
  if project="$(repo_project_for_url "$repo_url")"; then
    patch="$(jq -n --arg project "$project" '{stringData: {project: $project}}')"
    kubectl -n "$NAMESPACE" patch secret "$secret_name" --type merge -p "$patch"
  elif [[ "$repo_url" == "$REPO_URL" ]]; then
    patch="$(jq -n --arg project "$REPO_PROJECT" '{stringData: {project: $project}}')"
    kubectl -n "$NAMESPACE" patch secret "$secret_name" --type merge -p "$patch"
  fi
  if kubectl -n "$NAMESPACE" get secret "$secret_name" -o json | jq -e '.data.name != null' >/dev/null; then
    kubectl -n "$NAMESPACE" patch secret "$secret_name" --type json -p '[{"op":"remove","path":"/data/name"}]'
  fi
done <<< "$all_repo_secrets"

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

for workload in deploy/argocd-redis sts/argocd-application-controller; do
  if ! kubectl -n "$NAMESPACE" get "$workload" >/dev/null 2>&1; then
    continue
  fi
  if kubectl -n "$NAMESPACE" get "$workload" -o json |
    jq -e '.spec.template.spec.affinity.nodeAffinity != null' >/dev/null; then
    kubectl -n "$NAMESPACE" patch "$workload" --type json \
      -p '[{"op":"remove","path":"/spec/template/spec/affinity/nodeAffinity"}]'
  fi
done

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

bad_mapped_projects=""
while IFS= read -r repo_entry; do
  [[ -z "$repo_entry" ]] && continue
  secret_name="${repo_entry%%	*}"
  repo_url="${repo_entry#*	}"
  if ! expected_project="$(repo_project_for_url "$repo_url")"; then
    continue
  fi
  actual_project="$(
    kubectl -n "$NAMESPACE" get secret "$secret_name" -o json |
      jq -r '.data.project // "" | @base64d'
  )"
  if [[ "$actual_project" != "$expected_project" ]]; then
    bad_mapped_projects+="${secret_name}:${repo_url}:${actual_project}->${expected_project}"$'\n'
  fi
done <<< "$(
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r '.items[] | [.metadata.name, (.data.url // "" | @base64d)] | @tsv'
)"
if [[ -n "$bad_mapped_projects" ]]; then
  echo "FAIL repository secrets have wrong projects:" >&2
  echo "$bad_mapped_projects" >&2
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

bad_names="$(
  kubectl -n "$NAMESPACE" get secrets \
    -l argocd.argoproj.io/secret-type=repository \
    -o json |
    jq -r '
      .items[]
      | select(.data.name != null)
      | .metadata.name
    '
)"
if [[ -n "$bad_names" ]]; then
  echo "FAIL repository secrets still have short alias names: $bad_names" >&2
  exit 1
fi

bad_node_affinity="$(
  kubectl -n "$NAMESPACE" get deploy argocd-redis -o json |
    jq -r 'select(.spec.template.spec.affinity.nodeAffinity != null) | .metadata.name'
  kubectl -n "$NAMESPACE" get sts argocd-application-controller -o json |
    jq -r 'select(.spec.template.spec.affinity.nodeAffinity != null) | .metadata.name'
)"
if [[ -n "$bad_node_affinity" ]]; then
  echo "FAIL stale nodeAffinity remains: $bad_node_affinity" >&2
  exit 1
fi

echo "repository state repaired"
