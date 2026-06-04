# Registry Pull Secret Recovery

After Zot is healthy again in the `local` cluster, recreate `regcred` in every
namespace that pulls from `zot.electgo.com`.

## Development cluster

Create or replace `regcred` in each affected namespace:

```bash
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-bucket-upload delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-bucket-upload create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'

kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n product-ai-enrich delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n product-ai-enrich create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'

kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-websocket delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-websocket create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'

kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-partners-punchout-client delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n pim-partners-punchout-client create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'

kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n sku-finder-id delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n sku-finder-id create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'

kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n sku-finder-sg delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true -n sku-finder-sg create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'
```

## Production cluster

Use the same pattern against the production kubeconfig and the matching
production namespaces:

```bash
kubectl --kubeconfig=./k3s-production.yaml --insecure-skip-tls-verify=true -n <namespace> delete secret regcred --ignore-not-found
kubectl --kubeconfig=./k3s-production.yaml --insecure-skip-tls-verify=true -n <namespace> create secret docker-registry regcred \
  --docker-server=zot.electgo.com \
  --docker-username=admin \
  --docker-password='<password>'
```

## Verify

```bash
kubectl --kubeconfig=./k3s-development.yaml.bak --insecure-skip-tls-verify=true get secret -A | rg regcred
kubectl --kubeconfig=./k3s-production.yaml --insecure-skip-tls-verify=true get secret -A | rg regcred
```

If `k3s-production.yaml` is not present in this repo checkout, run the
production commands from the machine that has the production kubeconfig.
