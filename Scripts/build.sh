#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$PROJECT_ROOT/artifacts.nosync"
STAGING="$(mktemp -d "${TMPDIR:-/private/tmp/}macswitch-build.XXXXXX")"
APP="$STAGING/MacSwitch.app"
trap 'rm -rf "$STAGING"' EXIT
mkdir -p "$OUTPUT/ModuleCache"
export CLANG_MODULE_CACHE_PATH="$OUTPUT/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$OUTPUT/ModuleCache"
cd "$PROJECT_ROOT"

swift build --disable-sandbox --configuration release \
    --arch arm64 --arch x86_64 \
    --scratch-path "$OUTPUT/SwiftPM" --cache-path "$OUTPUT/cache" \
    --config-path "$OUTPUT/configuration" --security-path "$OUTPUT/security" \
    -Xswiftc -module-cache-path -Xswiftc "$OUTPUT/ModuleCache" \
    -Xswiftc -file-prefix-map -Xswiftc "$PROJECT_ROOT=." \
    -Xswiftc -debug-prefix-map -Xswiftc "$PROJECT_ROOT=."

BIN_DIR="$(swift build --disable-sandbox --configuration release \
    --arch arm64 --arch x86_64 \
    --scratch-path "$OUTPUT/SwiftPM" --cache-path "$OUTPUT/cache" \
    --config-path "$OUTPUT/configuration" --security-path "$OUTPUT/security" --show-bin-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Icons" "$APP/Contents/Resources/ThirdParty"
cp -X "$BIN_DIR/MacSwitch" "$APP/Contents/MacOS/MacSwitch"
strip -S -x "$APP/Contents/MacOS/MacSwitch"
for architecture in arm64 x86_64; do
    xcrun lipo "$APP/Contents/MacOS/MacSwitch" -verify_arch "$architecture"
done
cp -X "$PROJECT_ROOT/Info.plist" "$APP/Contents/Info.plist"
cp -X "$PROJECT_ROOT/LICENSE" "$APP/Contents/Resources/LICENSE-MacSwitch.txt"
cp -X "$PROJECT_ROOT"/Sources/MacSwitch/Resources/Icons/*.svg "$APP/Contents/Resources/Icons/"
cp -X "$PROJECT_ROOT"/ThirdParty/* "$APP/Contents/Resources/ThirdParty/"

swift -module-cache-path "$OUTPUT/ModuleCache" "$PROJECT_ROOT/Scripts/make-icon.swift" \
    "$PROJECT_ROOT/Sources/MacSwitch/Resources/Icons" "$OUTPUT/AppIcon.iconset"
iconutil -c icns "$OUTPUT/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
plutil -lint "$APP/Contents/Info.plist"
xattr -cr "$APP"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"
ditto --norsrc --noextattr -c -k --keepParent "$APP" "$OUTPUT/MacSwitch.zip"
ln -s /Applications "$STAGING/Applications"
cp -X "$PROJECT_ROOT/docs/INSTALL.ko.txt" "$STAGING/사용법-KO.txt"
cp -X "$PROJECT_ROOT/docs/INSTALL.en.txt" "$STAGING/START-HERE-EN.txt"
hdiutil create -quiet -volname MacSwitch -srcfolder "$STAGING" -format UDZO -ov "$OUTPUT/MacSwitch.dmg"
(
    cd "$OUTPUT"
    shasum -a 256 MacSwitch.zip MacSwitch.dmg > SHA256SUMS.txt
)
printf '\n앱 압축 파일 생성 완료: %s\n' "$OUTPUT/MacSwitch.zip"
printf '설치 및 실행: bash Scripts/install.sh\n'
