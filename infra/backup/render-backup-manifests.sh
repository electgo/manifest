#!/usr/bin/env bash
set -euo pipefail

: "${ELECTGO_BACKUP_BUCKET:?}"

envsubst < infra/backup/rancher-backup-schedule.yaml
