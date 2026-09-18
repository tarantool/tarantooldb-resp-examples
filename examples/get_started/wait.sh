#!/bin/bash

# Waits until the started cluster is ready to serve clients: every
# TDB-Redis instance and every Sentinel must answer a RESP PING.
# Uses bash /dev/tcp, so no redis-cli is required.
# Exits non-zero on timeout.

set -euo pipefail

PORTS=(
    "46379" "46380" "46381"  # TDB-Redis RESP
    "36379" "36380" "36381"  # Sentinel
)
TIMEOUT=120

# Sends a RESP PING to 127.0.0.1:$1 and succeeds on a +PONG reply.
ping_ok() {
    (
        exec 3<>/dev/tcp/127.0.0.1/"$1" || exit 1
        printf '*1\r\n$4\r\nPING\r\n' >&3 || exit 1
        IFS= read -r -t 5 reply <&3 || exit 1
        [[ $reply == +PONG* ]]
    ) 2>/dev/null
}

echo "Waiting for the cluster to initialize..."
deadline=$((SECONDS + TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
    ok=1
    for port in "${PORTS[@]}"; do
        ping_ok "$port" || ok=0
    done
    if [ "$ok" = 1 ]; then
        exit 0
    fi
    sleep 1
done
echo "ERROR: cluster is not ready within ${TIMEOUT}s" >&2
exit 1
