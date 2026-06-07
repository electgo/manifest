# Zot Local Recovery

This directory restores `zot.electgo.com` by letting Argo CD take over the
existing Zot release shape in the `local` cluster with the upstream
`project-zot/zot` Helm chart.

## What Argo CD manages

- `zot-local-application.yaml`
- `values-local.yaml`
- namespace targeting for `electgo-registry`
- Helm release state in the `local` cluster

## What stays manual

- the `htpasswd` secret for Zot auth
- the TLS secret used by the ingress
- image republish and namespace `regcred` recovery in dev and prod

Do not commit the Zot admin password or a rendered `htpasswd` file into Git.

## 1. Ensure the namespace exists

```bash
kubectl --kubeconfig=./local.yaml create namespace electgo-registry
```

If the namespace already exists, Kubernetes returns an `AlreadyExists` error.

## 2. Create the Zot htpasswd file locally

Generate a bcrypt entry locally. Replace `<password>` with the current admin
password:

```bash
htpasswd -Bbn admin '<password>' > /tmp/zot-htpasswd
```

## 3. Create the manual Zot secret in the local cluster

The upstream chart mounts a secret named `<releaseName>-secret`, so this setup
expects `zot-registry-secret`.

```bash
kubectl --kubeconfig=./local.yaml -n electgo-registry create secret generic zot-registry-secret \
  --from-file=htpasswd=/tmp/zot-htpasswd
```

If you need to rotate it later:

```bash
kubectl --kubeconfig=./local.yaml -n electgo-registry delete secret zot-registry-secret
kubectl --kubeconfig=./local.yaml -n electgo-registry create secret generic zot-registry-secret \
  --from-file=htpasswd=/tmp/zot-htpasswd
```

## 4. Ensure the ingress TLS secret exists

`values-local.yaml` expects the ingress TLS secret `zot-tls` in namespace
`electgo-registry`.

If cert-manager is not managing it already, create it manually:

```bash
kubectl --kubeconfig=./local.yaml -n electgo-registry create secret tls zot-tls \
  --cert=/path/to/fullchain.pem \
  --key=/path/to/privkey.pem
```

## 5. Apply the Argo CD application

Commit and push this directory first. Argo CD resolves `$values/...` from the
remote Git repository, not from your local working tree.

```bash
kubectl --kubeconfig=./local.yaml apply -f argo/zot-local/zot-local-application.yaml
```

## 6. Verify Zot resources

```bash
kubectl --kubeconfig=./local.yaml --insecure-skip-tls-verify=true -n electgo-registry get pods,svc,ing,pvc
curl -skI https://zot.electgo.com/v2/
```

Expected result from the registry endpoint is `401 Unauthorized` or `200 OK`,
but not `503 Service Temporarily Unavailable`.

## Current blocker observed on 2026-04-09

The existing PVC was provisioned with `local-path` node affinity for
`electgo-management-k3s-server`, but the current node hostname is
`electgo-mgmt-control`. Kubernetes treats PV node affinity as immutable, so that
old PVC cannot be patched in place. If you want to preserve the old registry
data, fix the node-affinity mismatch manually before syncing this Argo app.
If you only need service recovery, a fresh PVC on the current node is the
cleaner path.
