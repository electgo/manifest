import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const dashboardsDir = join(import.meta.dir, "..", "k8s", "management", "grafana-dashboards");
const dashboardFiles = readdirSync(dashboardsDir)
  .filter((name) => name.endsWith(".json"))
  .sort();

const requiredDashboardUids = new Set([
  "electgo-overview",
  "electgo-fleet",
  "electgo-prod-apps",
  "electgo-dev-apps",
  "electgo-prod-data-layer",
  "electgo-dev-data-layer",
  "electgo-cronjobs",
  "electgo-app-file-logs",
]);

const allowedDatasourceUids = new Set([
  "prometheus",
  "loki",
  "loki-mgmt",
  "cloudwatch",
  "tempo",
  "${datasource}",
  "-- Mixed --",
  "grafana",
  "-100",
]);

const forbiddenDatasourceTokens = [
  "prometheus-kube-prometheus-prometheus.monitoring.svc:9090",
  "alertmanager.electgo.com",
  "prometheus.electgo.com",
  "prometheus-legacy",
];

function collectDatasourceUids(value: unknown, found = new Set<string>()): Set<string> {
  if (Array.isArray(value)) {
    for (const item of value) collectDatasourceUids(item, found);
    return found;
  }

  if (value && typeof value === "object") {
    const record = value as Record<string, unknown>;
    if (record.datasource && typeof record.datasource === "object") {
      const datasource = record.datasource as Record<string, unknown>;
      if (typeof datasource.uid === "string") found.add(datasource.uid);
    }
    if (typeof record.datasourceUid === "string") found.add(record.datasourceUid);
    for (const item of Object.values(record)) collectDatasourceUids(item, found);
  }

  return found;
}

describe("OTEL LGTM dashboard migration", () => {
  test("contains required ElectGo dashboards", () => {
    const uids = new Set(
      dashboardFiles.map((file) => JSON.parse(readFileSync(join(dashboardsDir, file), "utf8")).dashboard?.uid),
    );

    for (const uid of requiredDashboardUids) expect(uids.has(uid)).toBe(true);
  });

  test.each(dashboardFiles)("%s uses only final LGTM datasource UIDs", (file) => {
    const raw = readFileSync(join(dashboardsDir, file), "utf8");
    for (const token of forbiddenDatasourceTokens) expect(raw).not.toContain(token);

    const dashboard = JSON.parse(raw);
    const uids = collectDatasourceUids(dashboard);
    for (const uid of uids) expect(allowedDatasourceUids.has(uid)).toBe(true);
  });
});
