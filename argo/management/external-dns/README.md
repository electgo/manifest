# external-dns (management cluster)

Syncs mgmt-cluster ingress hosts into **per-host** Route53 private zones
(`zot.electgo.com`, `rancher.electgo.com`, `argocd.`, `zitadel.`, `pm.`,
`grafana.`, `alertmanager.`), all attached to `electgo-vpc`
(vpc-0197654adba9e146a, ap-southeast-3).

Public `electgo.com` DNS lives in Cloudflare and is NOT managed here.

## Rules

- **NEVER create a private hosted zone named `electgo.com`** or any broad
  parent. Route53 private zones shadow their entire subtree inside the
  associated VPC with no fallback to public DNS. A broad `electgo.com`
  private zone (10 Jun 2026) made every public name (auto8, chat, www,
  pim, ...) NXDOMAIN from prod EKS for two days. Per-host zones only.
- New internal-only hostname: create a new per-host private zone, attach it
  to `electgo-vpc`, then append its zone ID to the `--zone-id-filter` list
  in `external-dns.yaml`. external-dns populates the record from the
  ingress within 1m.
- `registry: noop` is intentional: TXT ownership records cannot live at the
  apex of a per-host zone. Safe only while external-dns is the sole writer
  in these zones. Do not hand-edit records there.
