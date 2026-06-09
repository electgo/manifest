#!/usr/bin/env bash
set -euo pipefail

VALUES_FILE="${1:-$(dirname "$0")/values.yaml}"

check() {
  local expr="$1"
  local expected="$2"
  local actual
  actual="$(yq eval "$expr" "$VALUES_FILE")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL $expr: expected $expected, got $actual" >&2
    return 1
  fi
}

check '.configs.params."server.repo.server.timeout.seconds"' '180'
check '.configs.params."reposerver.git.request.timeout"' '90s'
check '.configs.params."reposerver.git.lsremote.parallelism.limit"' '8'
check '.configs.params."reposerver.parallelism.limit"' '10'
check '.server.replicas' '2'
check '.server.pdb.enabled' 'true'
check '.server.pdb.minAvailable' '1'
check '.server.deploymentStrategy.rollingUpdate.maxSurge' '0'
check '.server.deploymentStrategy.rollingUpdate.maxUnavailable' '1'
check '.server.topologySpreadConstraints[0].whenUnsatisfiable' 'DoNotSchedule'
check '.server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey' 'kubernetes.io/hostname'
check '.repoServer.replicas' '2'
check '.repoServer.pdb.enabled' 'true'
check '.repoServer.pdb.minAvailable' '1'
check '.repoServer.deploymentStrategy.rollingUpdate.maxSurge' '0'
check '.repoServer.deploymentStrategy.rollingUpdate.maxUnavailable' '1'
check '.repoServer.topologySpreadConstraints[0].whenUnsatisfiable' 'DoNotSchedule'
check '.repoServer.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey' 'kubernetes.io/hostname'
check '.repoServer.resources.requests.cpu' '50m'
check '.repoServer.resources.requests.memory' '128Mi'
check '.controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key' 'kubernetes.io/hostname'
check '.controller.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]' 'electgo-mgmt-gitops'
check '.redis.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key' 'kubernetes.io/hostname'
check '.redis.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]' 'electgo-mgmt-gitops'
