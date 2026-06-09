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
check '.server.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key' 'kubernetes.io/hostname'
check '.server.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[0]' 'electgo-mgmt-control'
check '.server.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].values[1]' 'electgo-mgmt-gitops'
check '.server.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution[0].topologyKey' 'kubernetes.io/hostname'
check '.server.initContainers[0].name' 'install-electgo-argocd-server'
check '.server.initContainers[0].image' 'amazon/aws-cli:2.17.56'
check '.server.initContainers[0].envFrom[0].secretRef.name' 'argocd-aws-creds'
check '.server.initContainers[0].volumeMounts[0].name' 'argocd-server-patched-bin'
check '.server.volumeMounts[0].mountPath' '/usr/local/bin/argocd-server'
check '.server.volumeMounts[0].subPath' 'argocd-server'
check '.server.volumes[0].name' 'argocd-server-patched-bin'
check '.server.initContainers[0].args[0] | contains("s3://electgo-prod-storage/electgo/management/argocd/${server_bin}")' 'true'
check '.server.initContainers[0].args[0] | contains("argocd-server-v3.4.3-electgo.2-linux-amd64")' 'true'
check '.server.initContainers[0].args[0] | contains("5ee15f174fcf24ca4ed48d055803ad3990b342d45774644e039f6303a851eba6")' 'true'
check '.server.initContainers[0].args[0] | contains("argocd-server-v3.4.3-electgo.2-linux-arm64")' 'true'
check '.server.initContainers[0].args[0] | contains("5337062b054bc1db84c98830769c00c7820914b30dd2e2a3a0505a77f5728548")' 'true'
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
