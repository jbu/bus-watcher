#!/bin/sh
set -e

cat > "$CI_WORKSPACE/Sources/BusWatcher/Secrets.swift" <<EOF
enum Secrets {
    static let appId  = "$TFWM_APP_ID"
    static let appKey = "$TFWM_APP_KEY"
}
EOF
