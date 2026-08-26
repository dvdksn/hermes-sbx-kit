#!/bin/sh
set -eu

# `extends: shell` contributes `-l` as its command tail. Empty child command
# arrays do not clear inherited lists, so consume that shell-only argument here.
if [ "${1:-}" = "-l" ]; then
  shift
fi

exec /home/agent/.local/bin/hermes "$@"
