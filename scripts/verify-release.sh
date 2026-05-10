#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift run OGameCoreTests
swift run OGamePersistenceTests
swift run OGameBalanceTool
swift build
./script/build_and_run.sh --package

APP_PLIST="$ROOT_DIR/dist/OGameMac.app/Contents/Info.plist"
APP_BINARY="$ROOT_DIR/dist/OGameMac.app/Contents/MacOS/OGameMac"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

test -f "$ROOT_DIR/dist/OGameMac.app/Contents/Resources/skins/xnova/gebaeude/1.gif"
test -f "$ROOT_DIR/dist/OGameMac.app/Contents/Resources/skins/xnova/planeten/mond.jpg"
test -f "$ROOT_DIR/dist/OGameMac.zip"
test -x "$APP_BINARY"

"$PLIST_BUDDY" -c "Print :CFBundleShortVersionString" "$APP_PLIST" >/dev/null
"$PLIST_BUDDY" -c "Print :CFBundleVersion" "$APP_PLIST" >/dev/null
test "$("$PLIST_BUDDY" -c "Print :CFBundleDisplayName" "$APP_PLIST")" = "Native OGame"
test "$("$PLIST_BUDDY" -c "Print :LSApplicationCategoryType" "$APP_PLIST")" = "public.app-category.strategy-games"
test "$("$PLIST_BUDDY" -c "Print :NSHighResolutionCapable" "$APP_PLIST")" = "true"

if git status --short -- '*.php' '*.tpl' | grep -q .; then
  echo "Legacy PHP/TPL files changed; inspect before release." >&2
  exit 1
fi

echo "Release verification passed."
