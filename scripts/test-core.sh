#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TASK_BINARY=$(mktemp -t jol-core)
trap 'rm -f "$TASK_BINARY"' EXIT
swiftc -parse-as-library Sources/ParcelCore/*.swift scripts/CoreSmoke.swift -o "$TASK_BINARY"
"$TASK_BINARY"
