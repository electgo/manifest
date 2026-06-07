#!/usr/bin/env bash
set -euo pipefail

cluster="${1:?usage: $0 dev|management|migration}"

case "$cluster" in
  dev)
    kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic mysql \
      --from-literal=MYSQL_ROOT_PASSWORD="${DEV_MYSQL_ROOT_PASSWORD:?}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic postgresql \
      --from-literal=POSTGRES_USER="${DEV_POSTGRES_USER:?}" \
      --from-literal=POSTGRES_PASSWORD="${DEV_POSTGRES_PASSWORD:?}" \
      --from-literal=POSTGRES_DB="${DEV_POSTGRES_DB:-postgres}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic mongodb \
      --from-literal=MONGO_INITDB_ROOT_USERNAME="${DEV_MONGODB_ROOT_USER:?}" \
      --from-literal=MONGO_INITDB_ROOT_PASSWORD="${DEV_MONGODB_ROOT_PASSWORD:?}" \
      --dry-run=client -o yaml | kubectl apply -f -
    if [[ -n "${ELECTGO_BACKUP_BUCKET:-}" ]]; then
      kubectl -n kube-system create secret generic backup-s3 \
        --from-literal=bucket="${ELECTGO_BACKUP_BUCKET}" \
        --dry-run=client -o yaml | kubectl apply -f -
    fi
    ;;
  management)
    kubectl create namespace database --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic postgresql \
      --from-literal=POSTGRES_USER="${MGMT_POSTGRES_USER:?}" \
      --from-literal=POSTGRES_PASSWORD="${MGMT_POSTGRES_PASSWORD:?}" \
      --from-literal=POSTGRES_DB="${MGMT_POSTGRES_DB:-postgres}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic mysql \
      --from-literal=MYSQL_ROOT_PASSWORD="${MGMT_MYSQL_ROOT_PASSWORD:?}" \
      --from-literal=MYSQL_DATABASE="${MGMT_MYSQL_DATABASE:-matomo}" \
      --from-literal=MYSQL_USER="${MGMT_MYSQL_USER:-matomo}" \
      --from-literal=MYSQL_PASSWORD="${MGMT_MYSQL_PASSWORD:-${MGMT_MYSQL_ROOT_PASSWORD:?}}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl -n database create secret generic backup-s3 \
      --from-literal=bucket="${ELECTGO_BACKUP_BUCKET:?}" \
      --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace cattle-resources-system --dry-run=client -o yaml | kubectl apply -f -
    if [[ -n "${RANCHER_BACKUP_AWS_ACCESS_KEY_ID:-}" && -n "${RANCHER_BACKUP_AWS_SECRET_ACCESS_KEY:-}" ]]; then
      kubectl -n cattle-resources-system create secret generic s3-creds \
        --from-literal=accessKey="${RANCHER_BACKUP_AWS_ACCESS_KEY_ID}" \
        --from-literal=secretKey="${RANCHER_BACKUP_AWS_SECRET_ACCESS_KEY}" \
        --dry-run=client -o yaml | kubectl apply -f -
    fi
    if [[ -n "${RANCHER_BACKUP_ENCRYPTION_KEY:-}" ]]; then
      kubectl -n cattle-resources-system create secret generic rancher-backup-encryption \
        --from-literal=encryptionConfigSecretKey="${RANCHER_BACKUP_ENCRYPTION_KEY}" \
        --dry-run=client -o yaml | kubectl apply -f -
    fi
    ;;
  migration)
    envsubst < infra/migration/mysql-eks-to-dev.yaml | kubectl apply -f -
    envsubst < infra/migration/postgresql-eks-to-dev.yaml | kubectl apply -f -
    envsubst < infra/migration/elasticsearch-eks-to-dev.yaml | kubectl apply -f -
    envsubst < infra/migration/redis-eks-to-dev.yaml | kubectl apply -f -
    ;;
  *)
    echo "unknown cluster: $cluster" >&2
    exit 1
    ;;
esac
