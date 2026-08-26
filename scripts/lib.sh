#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE=${SBX_ENV_FILE:-$ROOT/sbxenv.yaml}
SANDBOX_NAME=${HERMES_SANDBOX_NAME:-hermes-agent}

if [[ -n ${HERMES_BACKUP_DIR:-} ]]; then
  BACKUP_DIR=$HERMES_BACKUP_DIR
elif [[ $(uname -s) == Darwin ]]; then
  BACKUP_DIR="$HOME/Library/Application Support/hermes-sbx/backups"
else
  BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hermes-sbx/backups"
fi

export ROOT ENV_FILE SANDBOX_NAME BACKUP_DIR
