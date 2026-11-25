#!/usr/bin/env zsh
set -euo pipefail

# Ensures a persistent local code-signing identity ("AICall Local Signing")
# stored in ~/.t3/aicall-signing.keychain-db so every rebuild produces a stable
# designated requirement instead of an ad-hoc CDHash that triggers macOS Keychain
# ("t3code Safe Storage") password prompts on every update.

SIGN_KEYCHAIN="${AICALL_SIGN_KEYCHAIN:-$HOME/.t3/aicall-signing.keychain-db}"
SIGN_KC_PASS="aicall-local-signing"
CERT_NAME="AICall Local Signing"

mkdir -p "$(dirname "$SIGN_KEYCHAIN")"

if [ -f "$SIGN_KEYCHAIN" ]; then
  security unlock-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN" 2>/dev/null || true
  if security find-certificate -c "$CERT_NAME" "$SIGN_KEYCHAIN" >/dev/null 2>&1; then
    echo "$SIGN_KEYCHAIN"
    exit 0
  fi
fi

TMP_CERT_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_CERT_DIR"' EXIT

cat > "$TMP_CERT_DIR/openssl.cnf" <<'EOF'
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_code_sign
prompt = no

[req_distinguished_name]
CN = AICall Local Signing
O = AICall Local

[v3_code_sign]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMP_CERT_DIR/aicall.key" \
  -out "$TMP_CERT_DIR/aicall.crt" \
  -days 3650 \
  -config "$TMP_CERT_DIR/openssl.cnf" 2>/dev/null

openssl pkcs12 -export -legacy \
  -out "$TMP_CERT_DIR/aicall.p12" \
  -inkey "$TMP_CERT_DIR/aicall.key" \
  -in "$TMP_CERT_DIR/aicall.crt" \
  -passout pass:aicall-local 2>/dev/null || \
openssl pkcs12 -export \
  -out "$TMP_CERT_DIR/aicall.p12" \
  -inkey "$TMP_CERT_DIR/aicall.key" \
  -in "$TMP_CERT_DIR/aicall.crt" \
  -passout pass:aicall-local 2>/dev/null

rm -f "$SIGN_KEYCHAIN"
security create-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN"
security set-keychain-settings "$SIGN_KEYCHAIN"
security unlock-keychain -p "$SIGN_KC_PASS" "$SIGN_KEYCHAIN"
security import "$TMP_CERT_DIR/aicall.p12" -k "$SIGN_KEYCHAIN" -P "aicall-local" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$SIGN_KC_PASS" "$SIGN_KEYCHAIN" >/dev/null

echo "$SIGN_KEYCHAIN"
