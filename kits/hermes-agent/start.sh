#!/bin/sh
set -eu

hermes_home=${HERMES_HOME:-/home/agent/.hermes}

# `scripts/create` sets this for mount-backed environments. Keep Hermes from
# opening config/state files in the image filesystem during the short interval
# between sandbox creation and the live bind mount being attached.
if [ "${HERMES_WAIT_FOR_HOME_MOUNT:-0}" = "1" ]; then
  while [ ! -e "$hermes_home/.sbx-persistent-home" ]; do
    sleep 1
  done
fi

exec /home/agent/.local/bin/hermes "$@"