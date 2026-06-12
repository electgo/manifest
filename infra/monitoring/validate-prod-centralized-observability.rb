#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

ROOT = File.expand_path("../..", __dir__)

def read(path)
  File.read(File.join(ROOT, path))
end

def yaml(path)
  YAML.load_file(File.join(ROOT, path))
end

def values_for(app_path)
  app = yaml(app_path)
  source = app.dig("spec", "source")
  sources = app.dig("spec", "sources")
  helm = if source
    source["helm"]
  else
    sources.find { |item| item["chart"] == "alloy" }["helm"]
  end
  helm.fetch("values")
end

def assert(name)
  ok = yield
  puts("#{ok ? "ok" : "FAIL"} - #{name}")
  abort("validation failed: #{name}") unless ok
end

alloy_prod = values_for("argo/observability/alloy-prod-application.yaml")
prom_mgmt = values_for("argo/observability/prometheus-mgmt-application.yaml")
mgmt_loki_bridge = read("k8s/production/monitoring/mgmt-ingest-bridge.yaml")

assert("alloy-prod ships logs to mgmt Loki") do
  alloy_prod.include?('loki.write "mgmt"') &&
    alloy_prod.include?('url = "http://loki-mgmt.monitoring.svc:3100/loki/api/v1/push"') &&
    alloy_prod.include?('cluster = "production"')
end

assert("alloy-prod ships full metrics to mgmt Prometheus") do
  alloy_prod.include?('prometheus.scrape "kubelet"') &&
    alloy_prod.include?('prometheus.scrape "cadvisor"') &&
    alloy_prod.include?('prometheus.scrape "ksm"') &&
    alloy_prod.include?('prometheus.scrape "node"') &&
    alloy_prod.include?('prometheus.remote_write "mgmt"') &&
    alloy_prod.include?('url = "http://prometheus-mgmt-rw.monitoring.svc:9090/api/v1/write"')
end

assert("prod cluster has mgmt Loki bridge") do
  mgmt_loki_bridge.include?("name: loki-mgmt") &&
    mgmt_loki_bridge.include?("targetPort: 30311")
end

assert("mgmt Grafana prod datasources read from mgmt stores") do
  prom_mgmt.include?("name: Prometheus (prod)") &&
    prom_mgmt.include?("uid: prometheus") &&
    prom_mgmt.include?("url: http://prometheus-kube-prometheus-prometheus.monitoring.svc:9090") &&
    prom_mgmt.include?("name: Loki") &&
    prom_mgmt.include?("uid: loki") &&
    prom_mgmt.include?("url: http://loki.monitoring.svc:3100")
end

assert("prod storage apps are not active") do
  !File.exist?(File.join(ROOT, "argo/observability/prometheus-prod-application.yaml")) &&
    !File.exist?(File.join(ROOT, "argo/observability/loki-prod-application.yaml"))
end
