#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE="$PROJECT_ROOT/artifacts.nosync/MacSwitch.zip"
DESTINATION="$HOME/Applications/MacSwitch.app"
if [ ! -f "$ARCHIVE" ]; then
    /bin/bash "$PROJECT_ROOT/Scripts/build.sh"
fi

# Do not replace a running app or an unrelated pre-existing app.
if /usr/bin/pgrep -x MacSwitch >/dev/null 2>&1; then
    printf '먼저 메뉴 막대의 더 보기 → MacSwitch 종료를 눌러 주세요.\n' >&2
    exit 1
fi
if [ -d "$DESTINATION" ]; then
    BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$DESTINATION/Contents/Info.plist")"
    if [ "$BUNDLE_ID" != 'io.github.blackcat199099.MacSwitch' ]; then
        printf '같은 이름의 다른 앱이 있어 설치를 중단했습니다: %s\n' "$DESTINATION" >&2
        exit 1
    fi
fi

STAGING="$(mktemp -d "${TMPDIR:-/private/tmp/}macswitch-install.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto -x -k "$ARCHIVE" "$STAGING"
codesign --verify --deep --strict "$STAGING/MacSwitch.app"
mkdir -p "$HOME/Applications"
ditto --norsrc --noextattr "$STAGING/MacSwitch.app" "$DESTINATION"
codesign --verify --deep --strict "$DESTINATION"
printf '설치 완료: %s\n' "$DESTINATION"
open "$DESTINATION"
