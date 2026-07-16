#!/usr/bin/env bash
# Build script cho Render Static Site (Flutter Web).
# Build Command tren Render chi can: bash render-build.sh
# Publish Directory: apps/runny_app/build/web
set -euo pipefail

FLUTTER_VERSION="3.44.0"

# 1. Cai Flutter SDK (Render khong co san)
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" _flutter
fi
export PATH="$PATH:$(pwd)/_flutter/bin"

# 2. Sinh .env tu bien moi truong cua Render (Flutter Web nhung file nay vao bundle)
cd apps/runny_app
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
EOF

# 3. Build
flutter pub get
flutter build web --release --no-web-resources-cdn
