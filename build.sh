#!/usr/bin/env bash
set -euo pipefail

echo "Generating .env from Vercel environment variables..."
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
API_BASE_URL=${API_BASE_URL:-https://app.artyug.art}
ARTYUG_APP_MODE=${ARTYUG_APP_MODE:-live}
ARTYUG_CHAIN_MODE=${ARTYUG_CHAIN_MODE:-devnet}
ENABLE_NFC=${ENABLE_NFC:-false}
ENABLE_SOLANA=${ENABLE_SOLANA:-true}
SOLANA_RPC_URL=${SOLANA_RPC_URL:-}
SOLANA_PRIVATE_KEY=${SOLANA_PRIVATE_KEY:-}
RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID:-}
CHECKOUT_ENABLE_DODO=${CHECKOUT_ENABLE_DODO:-true}
CHECKOUT_ENABLE_STRIPE=${CHECKOUT_ENABLE_STRIPE:-true}
CHECKOUT_ENABLE_ARC_PAY=${CHECKOUT_ENABLE_ARC_PAY:-false}
DODO_PAYMENTS_API_KEY=${DODO_PAYMENTS_API_KEY:-}
STRIPE_PUBLISHABLE_KEY=${STRIPE_PUBLISHABLE_KEY:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-}
GEMINI_MODEL=${GEMINI_MODEL:-gemini-2.5-flash}
EOF
echo ".env generated with $(wc -l < .env) lines"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found. Installing Flutter stable..."
  FLUTTER_DIR="${HOME}/flutter"
  rm -rf "${FLUTTER_DIR}"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_DIR}"
  export PATH="${FLUTTER_DIR}/bin:${PATH}"
fi

flutter --version

rm -rf .dart_tool build
flutter pub get
flutter build web --release --no-wasm-dry-run

echo "Build completed successfully."