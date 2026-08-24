#!/bin/bash
#
# Install the lab's Splunk conf, then hand off to the stock Splunk entrypoint.
# /opt/splunk/etc is a Docker VOLUME owned by the base image, so the conf ships
# at /lab/conf and is copied in here, before splunkd starts.
set -euo pipefail
shopt -s nullglob

SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
ETC_LOCAL="${SPLUNK_HOME}/etc/system/local"
LAB_CONF="/lab/conf"
LAB_NAME="${LAB_NAME:-splunk-lab}"

conf_files=("${LAB_CONF}"/*.conf)

if [[ ${#conf_files[@]} -gt 0 ]]; then
  echo "[${LAB_NAME}] Installing lab configuration into ${ETC_LOCAL}"
  sudo mkdir -p "${ETC_LOCAL}"
  for conf in "${conf_files[@]}"; do
    echo "[${LAB_NAME}]   $(basename "${conf}")"
    sudo cp "${conf}" "${ETC_LOCAL}/"
    sudo chown splunk:splunk "${ETC_LOCAL}/$(basename "${conf}")"
  done
else
  # Without conf there is no index and no inputs, so the container would come up
  # healthy with an empty lab.
  echo "[${LAB_NAME}] ERROR: no .conf files under ${LAB_CONF}." >&2
  echo "[${LAB_NAME}] The image was built without its configuration; rebuild it." >&2
  exit 1
fi

if [[ ! -d /lab/logs ]]; then
  echo "[${LAB_NAME}] ERROR: /lab/logs is missing; there is nothing to index." >&2
  exit 1
fi

echo "[${LAB_NAME}] Handing off to the Splunk entrypoint. First boot provisions"
echo "[${LAB_NAME}] Splunk and then indexes the logs, which takes a while; see"
echo "[${LAB_NAME}] README.md for how to tell when indexing has finished."

exec /sbin/entrypoint.sh "$@"
