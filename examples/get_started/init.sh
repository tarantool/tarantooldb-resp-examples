#!/bin/bash

# Publishes the tdbredis cluster configuration to the config storage cluster.
# Retries the publish across all endpoints until one accepts (the leader,
# followers reject as read-only, unreachable nodes fail to connect).
# Exits non-zero on timeout.

set -euo pipefail

STORAGE=(
    "config-storage-1:4401"
    "config-storage-2:4402"
    "config-storage-3:4403"
)
TIMEOUT=60

publish_config() {
    echo "Publishing the tdbredis cluster config..."
    local deadline=$((SECONDS + TIMEOUT)) addr
    while [ "$SECONDS" -lt "$deadline" ]; do
        for addr in "${STORAGE[@]}"; do
            if tt cluster publish \
                    "http://sampleuser:123456@${addr}/tdbredis" \
                    instances.enabled/tdbredis/source.yaml 2>/dev/null; then
                echo "Config published successfully to ${addr}."
                return 0
            fi
        done
        sleep 1
    done
    echo "ERROR: failed to publish config within ${TIMEOUT}s" >&2
    return 1
}

publish_config
