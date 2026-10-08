#!/usr/bin/env bash
# Builds the business website (the Flutter app compiled for the web) on
# Render, which has no Flutter of its own — see render.yaml. Run from mobile/.
set -euo pipefail

# Same Flutter as development, so the website and the phone app are built alike.
FLUTTER_VERSION=3.32.4
FLUTTER_DIR="$HOME/flutter-$FLUTTER_VERSION"
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --disable-analytics >/dev/null
flutter pub get
# --no-web-resources-cdn: the rendering engine is served from this site, not
# Google's CDN, so the security policy can allow scripts from 'self' only.
# --pwa-strategy=none: no offline cache, which would keep serving an old
# version of the site after a deploy.
flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=FASTAPI_BASE_URL="$FASTAPI_BASE_URL"
