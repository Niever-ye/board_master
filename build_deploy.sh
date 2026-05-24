#!/bin/bash
set -e

echo "=== Building Flutter web (wasm) ==="
MSYS_NO_PATHCONV=1 /c/Users/10028/development/flutter/bin/flutter build web --base-href=/board_master/ --release --wasm

echo "=== Patching flutter_bootstrap.js for local CanvasKit ==="
sed -i 's/_flutter\.loader\.load({/_flutter.loader.load({ config: { canvasKitBaseUrl: "canvaskit\/", useLocalCanvasKit: true },/' build/web/flutter_bootstrap.js

echo "=== Cleaning up unused canvaskit variants ==="
# Remove debug symbols (only needed for debugging)
rm -f build/web/canvaskit/*.symbols
rm -f build/web/canvaskit/chromium/*.symbols
rm -f build/web/canvaskit/experimental_webparagraph/*.symbols
# Remove variants not needed
rm -rf build/web/canvaskit/experimental_webparagraph
# For wasm build, we primarily use skwasm; keep canvaskit as fallback

echo "=== Copying to docs/ ==="
rm -rf docs
cp -r build/web docs

echo "=== Deploying to GitHub ==="
git add docs web/index.html build_deploy.sh lib/
git commit -m "Deploy: wasm build + loading animation + canvas cleanup" \
    -m "Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>" || echo "Nothing to commit"
git push origin master

echo "=== Done ==="
