#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./script/build_and_run.sh --package

cat <<'INFO'
Package created:
  dist/OGameMac.app
  dist/OGameMac.zip

Signing/notarization:
  1. Sign with a Developer ID Application certificate when available.
  2. Notarize the signed archive with notarytool.
  3. Staple the ticket before public distribution.

Current local package is suitable for private playtesting on this Mac.

Optional package metadata:
  NATIVE_OGAME_VERSION=0.1.0
  NATIVE_OGAME_BUILD_NUMBER=100
  NATIVE_OGAME_BUNDLE_ID=com.example.NativeOGame

Example:
  NATIVE_OGAME_VERSION=0.1.0 NATIVE_OGAME_BUILD_NUMBER=100 ./script/build_and_run.sh --package
INFO
