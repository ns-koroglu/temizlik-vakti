#!/bin/bash
# Temizlik Vakti — derleme ve .app paketleme betiği
#
#   ./build.sh              → build/Temizlik Vakti.app üretir
#   ./build.sh --install    → üretir ve /Applications içine kopyalar
#   ./build.sh --run        → üretir ve çalıştırır
#   ./build.sh --notarize   → Developer ID ile imzalar, Apple'a gönderir, staple eder
#   ./build.sh --reset-perm → Erişilebilirlik iznini sıfırlar (yeniden izin vermen gerekir)
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Temizlik Vakti"
BUNDLE_ID="app.temizlikvakti.mac"
EXEC_NAME="TemizlikVakti"
OUT_DIR="build"
APP="$OUT_DIR/$APP_NAME.app"

INSTALL=0; RUN=0; NOTARIZE=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --run) RUN=1 ;;
    --notarize) NOTARIZE=1 ;;
    --reset-perm)
      tccutil reset Accessibility "$BUNDLE_ID" || true
      echo "İzin sıfırlandı. Uygulamayı yeniden başlatıp izni tekrar ver."
      exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg"; exit 1 ;;
  esac
done

# Hata günlüğü dünya-yazılır /tmp yerine güvenli geçici dosyaya
ERR_LOG="$(mktemp -t build_err)"
trap 'rm -f "$ERR_LOG"' EXIT

# ---------------------------------------------------------------------------
# Notarization (Apple onayı)
#
# Neden gerekiyor: yerel kendinden imzalı paketi başka bir Mac'e indiren kişi
# Gatekeeper uyarısı görür ("geliştirici doğrulanamıyor"). Notarize edilmiş ve
# staple edilmiş bir paket ise çift tıklamayla, uyarısız açılır.
#
# Ön koşullar:
#   1) Apple Developer Program üyeliği ve anahtarlıkta bir
#      "Developer ID Application: ..." sertifikası
#   2) notarytool kimlik bilgisi. En temizi bir kez saklamak:
#        xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#          --apple-id "seninmailin@example.com" \
#          --team-id "ABCDE12345" \
#          --password "uygulamaya-özel-parola"
#      Alternatif: APPLE_ID / TEAM_ID / APP_PASSWORD ortam değişkenleri.
# ---------------------------------------------------------------------------

find_developer_id() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1
}

notarize_app() {
  local app="$1"

  local dev_id
  dev_id="${DEVELOPER_ID_IDENTITY:-$(find_developer_id)}"
  if [ -z "$dev_id" ]; then
    echo "✗ Notarization için 'Developer ID Application' sertifikası gerekiyor."
    echo "  Anahtarlıkta bulunamadı. Apple Developer Program üyeliği ve"
    echo "  Xcode → Settings → Accounts → Manage Certificates ile üretilen"
    echo "  bir Developer ID Application sertifikası şart."
    echo "  (Yerel kendinden imzalı kimlik notarize EDİLEMEZ.)"
    exit 1
  fi

  echo "▸ Developer ID ile yeniden imzalanıyor: $dev_id"
  # --timestamp: notarization güvenli zaman damgası şart koşuyor
  # --options runtime: hardened runtime olmadan notarization reddedilir
  codesign --force --deep --options runtime --timestamp \
    --sign "$dev_id" --identifier "$BUNDLE_ID" "$app"

  local zip="$OUT_DIR/$APP_NAME-notarize.zip"
  rm -f "$zip"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

  echo "▸ Apple'a gönderiliyor (birkaç dakika sürebilir)…"
  if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    xcrun notarytool submit "$zip" \
      --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_PASSWORD" --wait
  else
    local profile="${NOTARY_PROFILE:-$BUNDLE_ID}"
    if ! xcrun notarytool history --keychain-profile "$profile" >/dev/null 2>&1; then
      echo "✗ notarytool kimlik bilgisi bulunamadı."
      echo "  Bir kez şunu çalıştır:"
      echo "    xcrun notarytool store-credentials \"$profile\" \\"
      echo "      --apple-id \"<apple kimliğin>\" --team-id \"<takım kimliğin>\" \\"
      echo "      --password \"<uygulamaya özel parola>\""
      echo "  ya da APPLE_ID / TEAM_ID / APP_PASSWORD ortam değişkenlerini ver."
      rm -f "$zip"
      exit 1
    fi
    xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
  fi

  echo "▸ Onay pakete iliştiriliyor (staple)…"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"

  echo "▸ Gatekeeper doğrulaması…"
  spctl --assess --type execute --verbose=2 "$app"

  rm -f "$zip"
  # Dağıtıma hazır arşiv: staple edilmiş hâlinden
  local dist="$OUT_DIR/$APP_NAME-$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString).zip"
  rm -f "$dist"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$dist"
  echo "✓ Notarize edildi ve staple edildi: $dist"
}

echo "▸ Derleniyor…"
if ! swift build -c release 2>"$ERR_LOG"; then
  if grep -q "Xcode license" "$ERR_LOG"; then
    echo "  (Xcode lisansı onaylanmamış — Command Line Tools araç zinciriyle deneniyor)"
    DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build -c release
  else
    cat "$ERR_LOG"; exit 1
  fi
fi
BIN=".build/release/$EXEC_NAME"

echo "▸ Simge hazırlanıyor…"
ICONSET="$OUT_DIR/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
PNG="$OUT_DIR/icon-1024.png"
swift Scripts/makeicon.swift "$PNG" >/dev/null 2>&1 || \
  DEVELOPER_DIR=/Library/Developer/CommandLineTools swift Scripts/makeicon.swift "$PNG" >/dev/null
for s in 16 32 128 256 512; do
  sips -z $s $s "$PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUT_DIR/AppIcon.icns"

echo "▸ Paketleniyor…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$EXEC_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$OUT_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

SIGN_IDENTITY="${SIGN_IDENTITY:-Yerel Kod Imzasi}"
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
  echo "▸ İmzalanıyor ($SIGN_IDENTITY, hardened runtime)…"
  # --options runtime: kütüphane enjeksiyonunu ve hata ayıklayıcı iliştirmeyi engeller.
  # Klavye olaylarını gören bir uygulama için anlamlı bir sertleştirme; Erişilebilirlik
  # izni imza gereksinimine (identifier + sertifika kökü) bağlı olduğu için korunuyor.
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
  STABLE_SIGN=1
else
  echo "▸ İmzalanıyor (ad-hoc)…"
  codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP"
  STABLE_SIGN=0
fi

if [ "$NOTARIZE" = "1" ]; then
  notarize_app "$APP"
fi

if [ "$INSTALL" = "1" ]; then
  echo "▸ /Applications içine kopyalanıyor…"
  osascript -e 'quit app "Temizlik Vakti"' >/dev/null 2>&1 || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
  # Yerel kopyayı bırakma: Spotlight/Launchpad'de aynı uygulamanın iki kaydı görünmesin
  rm -rf "$OUT_DIR/$APP_NAME.app"
  APP="/Applications/$APP_NAME.app"
fi

echo "✓ Hazır: $APP"
if [ "$STABLE_SIGN" = "0" ]; then
  echo "⚠︎  Ad-hoc imzalandı: her derlemede imza özeti değiştiği için macOS izinleri"
  echo "   (Erişilebilirlik) geçersiz olur. Kalıcı çözüm: ./Scripts/setup-signing.sh"
fi

if [ "$RUN" = "1" ]; then
  osascript -e 'quit app "Temizlik Vakti"' >/dev/null 2>&1 || true
  sleep 0.5
  open "$APP"
  echo "✓ Çalıştırıldı — menü çubuğundaki ✨ simgesine bak."
fi
