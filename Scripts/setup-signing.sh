#!/bin/bash
# Yerel, sabit bir kod imzalama kimliği oluşturur.
#
# Neden gerekli: ad-hoc imzada (codesign -s -) macOS, Erişilebilirlik iznini
# uygulamanın imza özetine (cdhash) bağlar. Her yeniden derlemede bu özet
# değiştiği için Sistem Ayarları'ndaki anahtar açık görünse bile izin geçersiz
# olur. Sabit bir sertifikayla imzalandığında izin sertifikaya bağlanır ve
# yeniden derlemelerden etkilenmez.
#
# Kullanım: ./Scripts/setup-signing.sh     (bir kez yeter, idempotent)
set -euo pipefail

CN="${SIGN_IDENTITY:-Yerel Kod Imzasi}"

if security find-certificate -c "$CN" >/dev/null 2>&1; then
  echo "✓ '$CN' kimliği zaten var, bir şey yapılmadı."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/openssl.cnf" <<CFG
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $CN
O = Yerel Gelistirme
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/openssl.cnf" >/dev/null 2>&1

openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/id.p12" -passout pass:local -name "$CN" >/dev/null 2>&1

# -T /usr/bin/codesign -A : imzalama sırasında anahtar erişimi için pencere çıkmasın
security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P local -T /usr/bin/codesign -A >/dev/null

echo "✓ '$CN' kimliği oluşturuldu ve giriş anahtarlığına eklendi."
echo "  Kaldırmak için: security delete-identity -c \"$CN\""
