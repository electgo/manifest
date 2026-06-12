import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const baseUrl = process.env.GRAFANA_URL ?? "http://localhost:3000";
const user = process.env.GRAFANA_USER ?? "admin";
const password = process.env.GRAFANA_PASSWORD ?? "";

if (!password) {
  throw new Error("GRAFANA_PASSWORD is required");
}

const auth = "Basic " + Buffer.from(`${user}:${password}`).toString("base64");
const dashboardsDir = join(import.meta.dir, "..", "k8s", "management", "grafana-dashboards");
const requiredDashboardUids = new Set([
  "electgo-overview",
  "electgo-prod-apps",
  "electgo-dev-apps",
  "electgo-prod-data-layer",
  "electgo-dev-data-layer",
  "electgo-app-file-logs",
]);

type Target = {
  uid: string;
  expr: string;
};

function normalizeExpr(expr: string): string {
  return expr
    .replaceAll("$__rate_interval", "5m")
    .replaceAll("$__interval", "5m")
    .replaceAll("$__range", "1h")
    .replaceAll("$namespace", ".+")
    .replaceAll("$pod", ".+")
    .replaceAll("$app", ".+")
    .replaceAll("$cluster", ".+")
    .replaceAll("$search", ".*");
}

function collectTargets(value: unknown, out: Target[] = [], inheritedUid?: string): Target[] {
  if (Array.isArray(value)) {
    for (const item of value) collectTargets(item, out, inheritedUid);
    return out;
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    const datasource = record.datasource as { uid?: string } | undefined;
    const nextUid = typeof datasource?.uid === "string" ? datasource.uid : inheritedUid;
    if (typeof nextUid === "string" && typeof record.expr === "string") {
      out.push({ uid: nextUid, expr: normalizeExpr(record.expr) });
    }
    for (const item of Object.values(record)) collectTargets(item, out, nextUid);
  }

  return out;
}

async function get(path: string): Promise<any> {
  const res = await fetch(`${baseUrl}${path}`, { headers: { Authorization: auth } });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${path} returned ${res.status}: ${body.slice(0, 300)}`);
  }
  return res.json();
}

async function query(target: Target): Promise<any> {
  const encoded = encodeURIComponent(target.expr);
  if (target.uid === "prometheus" || target.uid === "${datasource}" || target.uid === "-- Mixed --") {
    return get(`/api/datasources/proxy/uid/prometheus/api/v1/query?query=${encoded}`);
  }
  if (target.uid === "loki" || target.uid === "loki-mgmt") {
    return get(`/api/datasources/proxy/uid/loki/loki/api/v1/query?query=${encoded}`);
  }
  return { status: "skipped", data: { result: [] } };
}

for (const file of readdirSync(dashboardsDir).filter((name) => name.endsWith(".json")).sort()) {
  const parsed = JSON.parse(readFileSync(join(dashboardsDir, file), "utf8"));
  const dashboard = parsed.dashboard ?? parsed;
  if (!requiredDashboardUids.has(dashboard.uid)) continue;

  const targets = collectTargets(dashboard)
    .filter((target) => target.expr && !target.expr.includes("$"))
    .slice(0, 16);

  let nonEmpty = 0;
  let ok = 0;
  let checked = 0;
  for (const target of targets) {
    checked += 1;
    try {
      const result = await query(target);
      ok += 1;
      if (Array.isArray(result.data?.result) && result.data.result.length > 0) nonEmpty += 1;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`${dashboard.uid}: query failed for ${target.uid}: ${message}`);
    }
  }

  if (checked === 0) {
    throw new Error(`${dashboard.uid} has no sampled panel queries`);
  }

  if (ok === 0) {
    throw new Error(`${dashboard.uid} had ${checked} sampled panel queries but none executed successfully`);
  }

  console.log(`${dashboard.uid}: ${ok}/${checked} sampled panel queries executed, ${nonEmpty}/${checked} returned data`);
}
