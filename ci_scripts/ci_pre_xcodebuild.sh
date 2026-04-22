#!/bin/sh
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cat > "$REPO_ROOT/Sources/BusWatcher/Secrets.swift" <<EOF
enum Secrets {
    static let appId  = "$TFWM_APP_ID"
    static let appKey = "$TFWM_APP_KEY"
}
EOF
