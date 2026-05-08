#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swift run OGameCoreTests
swift run OGamePersistenceTests
swift run OGameBalanceTool
swift build
./script/build_and_run.sh --package

test -f "$ROOT_DIR/dist/OGameMac.app/Contents/Resources/skins/xnova/gebaeude/1.gif"
test -f "$ROOT_DIR/dist/OGameMac.app/Contents/Resources/skins/xnova/planeten/mond.jpg"
test -f "$ROOT_DIR/dist/OGameMac.zip"

if git status --short -- '*.php' '*.tpl' | grep -q .; then
  echo "Legacy PHP/TPL files changed; inspect before release." >&2
  exit 1
fi

echo "Release verification passed."
