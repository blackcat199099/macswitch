#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$PROJECT_ROOT/artifacts.nosync"
mkdir -p "$OUTPUT/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$OUTPUT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$OUTPUT/ModuleCache"
cd "$PROJECT_ROOT"
swift test --disable-sandbox --scratch-path "$OUTPUT/SwiftPM" --cache-path "$OUTPUT/cache" \
    --config-path "$OUTPUT/configuration" --security-path "$OUTPUT/security" \
    -Xswiftc -module-cache-path -Xswiftc "$OUTPUT/ModuleCache"
