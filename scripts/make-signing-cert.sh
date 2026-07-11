#!/bin/bash
# Crea un certificado autofirmado de firma de código llamado "ScreenRec Dev" en tu
# llavero de inicio de sesión. Con él, el permiso de Grabación de pantalla se
# mantiene entre recompilaciones (con firma ad-hoc macOS puede volver a pedirlo).
#
# EJECÚTALO TÚ MISMO (te pedirá tu contraseña para autorizar el llavero):
#   bash scripts/make-signing-cert.sh
#
set -euo pipefail

NAME="ScreenRec Dev"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if security find-identity -v -p codesigning | grep -q "$NAME"; then
  echo "El certificado '$NAME' ya existe. Nada que hacer."
  exit 0
fi

cat > "$TMP/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $NAME
[ ext ]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:false
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf"

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/cert.p12" -passout pass:screenrec

security import "$TMP/cert.p12" -k "$KEYCHAIN" -P screenrec -T /usr/bin/codesign

# Marcar el certificado como de confianza para firma de código (pedirá contraseña)
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"

echo
echo "Listo. Recompila con 'make app' y la firma usará '$NAME'."
echo "Si el llavero pregunta al firmar, elige 'Permitir siempre'."
