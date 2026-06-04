# root (app-of-apps)

Single root Argo Application that watches `argo/` recursive in this repo. When
applied to the in-cluster argocd, it spawns and reconciles every Application
declared under `argo/**/-application.yaml` plus AppProject manifests under
`argo/projects/*.yaml`.

## State today

**NOT applied.** Manual sync only. The repo manifests still drift from live state
on several Apps (most live Apps carry inline `spec.source.helm.parameters` with
env-secret values set via `argocd app set --helm-set`).

## When ready to adopt

1. Audit each live App: `argocd app get <name> -o json | jq '.spec.source.helm.parameters'`
2. For every parameter that's a secret (DB creds, tokens, etc), move it into a
   Kubernetes Secret + reference via chart's `envFrom`. Leave only image.repository
   and image.tag in helm.parameters (those are image-updater's territory).
3. Confirm each `argo/**/-application.yaml` matches live `.spec`. Add missing
   `helm.parameters` (non-secret only) to git.
4. First-time apply:
   ```
   kubectl apply -f argo/root/root-application.yaml
   ```
   Root will sync, take ownership of every child App. The `ignoreDifferences`
   on `/spec/source/helm/parameters` ensures CLI/image-updater-written inline
   params aren't reverted on each tick.
5. After 24h of stable operation, enable `syncPolicy.automated.selfHeal: true`
   so any future `argocd app set` reverts within seconds — true GitOps.

## Why this design

- One directory source, one place to add new Apps (drop yaml in `argo/<app>/`).
- AppProjects also reconciled — no more manual `kubectl apply -f argo/projects/`.
- `ignoreDifferences` on parameters lets image-updater coexist (write-back=argocd
  for dev still works; root won't fight inline writes).
- No ApplicationSet generator complexity — direct directory mode is enough.

## Limitations / future work

- Helm values files in `argo/<app>/values-*.yaml` are SKIPPED by the include
  glob — Argo treats them as referenced via `source.helm.valueFiles` from each
  child App, not as resources to apply. Verified safe.
- If a Helm chart Application uses `$values` ref (e.g. `argo/zot-local`), the
  values file path stays repo-relative — works under app-of-apps too.
