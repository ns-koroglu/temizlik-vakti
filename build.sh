#!/bin/bash
# Temizlik Vakti — derleme ve .app paketleme betiği
#
#   ./build.sh              → build/Temizlik Vakti.app üretir
#   ./build.sh --install    → üretir ve /Applications içine kopyalar
#   ./build.sh --run        → üretir ve çalıştırır
#   ./build.sh --reset-perm → Erişilebilirlik iznini sıfırlar (yeniden izin vermen gerekir)
#
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Temizlik Vakti"
BUNDLE_ID="app.temizlikvakti.mac"
EXEC_NAME="TemizlikVakti"
OUT_DIR="build"
APP="$OUT_DIR/$APP_NAME.app"

INSTALL=0; RUN=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --run) RUN=1 ;;
    --reset-perm)
      tccutil reset Accessibility "$BUNDLE_ID" || true
      echo "İzin sıfırlandı. Uygulamayı yeniden başlatıp izni tekrar ver."
      exit 0 ;;
    *) echo "Bilinmeyen seçenek: $arg"; exit 1 ;;
  esac
done

echo "▸ Derleniyor…"
if ! swift build -c release 2>/tmp/tv_build_err.txt; then
  if grep -q "Xcode license" /tmp/tv_build_err.txt; then
    echo "  (Xcode lisansı onaylanmamış — Command Line Tools araç zinciriyle deneniyor)"
    DEVELOPER_DIR=/Library/Developer/CommandLineTools swift build -c release
  else
    cat /tmp/tv_build_err.txt; exit 1
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
  echo "▸ İmzalanıyor ($SIGN_IDENTITY)…"
  codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP"
  STABLE_SIGN=1
else
  echo "▸ İmzalanıyor (ad-hoc)…"
  codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP"
  STABLE_SIGN=0
fi

if [ "$INSTALL" = "1" ]; then
  echo "▸ /Applications içine kopyalanıyor…"
  osascript -e 'quit app "Temizlik Vakti"' >/dev/null 2>&1 || true
  rm -rf "/Applications/$APP_NAME.app"
  cp -R "$APP" "/Applications/$APP_NAME.app"
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
