#!/bin/bash
# Builds ProjectHub.app in release mode and zips it ready for distribution.
# Usage: bash package.sh
set -e

cd "$(dirname "$0")"

echo "→ Building release…"
bash build-app.sh release

echo "→ Zipping app…"
rm -f ProjectHub.zip
ditto -c -k --keepParent ProjectHub.app ProjectHub.zip

SHA=$(shasum -a 256 ProjectHub.zip | awk '{print $1}')
SIZE=$(du -h ProjectHub.zip | cut -f1)

echo ""
echo "✓ Built: $(pwd)/ProjectHub.zip ($SIZE)"
echo "  SHA256: $SHA"
