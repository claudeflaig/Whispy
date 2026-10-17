#!/bin/bash
set -euo pipefail

# Whispy macOS App - Build & Run
# Voraussetzungen: Full Xcode with Command Line Tools, xcodegen

RUN_AFTER=false
INSTALL_APP=false
BUILD_CONFIGURATION="Release"
UNIVERSAL_ARCHS="arm64 x86_64"

for arg in "$@"; do
    case "$arg" in
        --debug)
            BUILD_CONFIGURATION="Debug"
            ;;
        --run)
            RUN_AFTER=true
            ;;
        --install)
            INSTALL_APP=true
            ;;
        --release)
            BUILD_CONFIGURATION="Release"
            ;;
        *)
            echo "Unbekannte Option: $arg"
            echo "Verwendung: ./build.sh [--install] [--run] [--release] [--debug]"
            exit 1
            ;;
    esac
done

verify_universal_app() {
    local app_path="$1"
    local app_name
    local binary_path
    local archs

    app_name="$(basename "$app_path" .app)"
    binary_path="$app_path/Contents/MacOS/$app_name"

    if [ ! -f "$binary_path" ]; then
        echo "❌ Konnte App-Binary nicht finden: $binary_path"
        exit 1
    fi

    archs="$(lipo -archs "$binary_path" 2>/dev/null || true)"

    if [[ -z "$archs" ]]; then
        echo "❌ Konnte Architekturen nicht lesen: $binary_path"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    if [[ " $archs " != *" arm64 "* || " $archs " != *" x86_64 "* ]]; then
        echo "❌ Build ist nicht universal. Erwartet: arm64 + x86_64"
        echo "   Gefunden: $archs"
        file "$binary_path" 2>/dev/null || true
        exit 1
    fi

    echo "✅ Universal Binary verifiziert: $archs"
}

ensure_xcodebuild_available() {
    if xcodebuild -version >/dev/null 2>&1; then
        return
    fi

    local default_xcode="/Applications/Xcode.app/Contents/Developer"
    if [ -d "$default_xcode" ]; then
        export DEVELOPER_DIR="$default_xcode"
        if xcodebuild -version >/dev/null 2>&1; then
            echo "⚠️  Aktiver Developer-Pfad nutzt kein vollständiges Xcode. Verwende: $DEVELOPER_DIR"
            return
        fi
    fi

    echo "❌ xcodebuild ist nicht verfügbar."
    echo "   Installiere Xcode und wähle es mit:"
    echo "   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
}

# Signiert wie Pastely: mit einem eigenen Zertifikat aus dem Schlüsselbund, damit
# macOS jeden Neubau als dieselbe App erkennt und Mikrofon, Bedienungshilfen und
# Spracherkennung nicht nach jeder Anpassung neu freigegeben werden müssen.
# Gesucht wird SIGN_IDENTITY, sonst "Whispy Developer", sonst das bereits
# vorhandene "Pastely Developer". Ohne Zertifikat wird ad hoc signiert, und
# macOS fragt nach jedem Build erneut nach den Rechten (siehe README).
BUNDLE_ID="app.claudeflaig.whispy"

resolve_sign_identity() {
    local candidates=()
    if [ -n "${SIGN_IDENTITY:-}" ]; then
        candidates+=("$SIGN_IDENTITY")
    fi
    candidates+=("Whispy Developer" "Pastely Developer")

    local identities
    identities="$(security find-identity -p codesigning 2>/dev/null || true)"
    for candidate in "${candidates[@]}"; do
        if grep -q "\"$candidate" <<<"$identities"; then
            echo "$candidate"
            return
        fi
    done
}

sign_app() {
    local app_path="$1"
    local identity
    identity="$(resolve_sign_identity)"

    # iCloud Drive (Documents) versieht Dateien mit Attributen, die codesign
    # ablehnt. Deshalb wird außerhalb des Projekts signiert und dann kopiert.
    local stage
    stage="$(mktemp -d)"
    ditto --noextattr --norsrc "$app_path" "$stage/Whispy.app"

    if [ -n "$identity" ]; then
        echo "🔏 Signiere mit Zertifikat \"$identity\" – Rechte bleiben über Neubauten erhalten."
        codesign --force --deep --sign "$identity" \
            --identifier "$BUNDLE_ID" \
            --entitlements "$PROJECT_DIR/Resources/BlitztextMac.entitlements" \
            "$stage/Whispy.app"
    elif [ "${REQUIRE_IDENTITY:-0}" = 1 ]; then
        echo "❌ Kein Signier-Zertifikat im Schlüsselbund gefunden."
        rm -rf "$stage"
        exit 1
    else
        echo "⚠️  Kein Zertifikat \"Whispy Developer\" gefunden – signiere ad hoc."
        echo "   macOS wird die Rechte nach jedem Build neu verlangen. Einrichtung: siehe README."
        codesign --force --deep --sign - \
            --identifier "$BUNDLE_ID" \
            --entitlements "$PROJECT_DIR/Resources/BlitztextMac.entitlements" \
            -r="designated => identifier \"$BUNDLE_ID\"" \
            "$stage/Whispy.app"
    fi

    # Prüfen, solange die App noch außerhalb von iCloud liegt: iCloud hängt
    # im Projektordner sofort wieder Attribute an, die --strict ablehnt.
    codesign --verify --deep --strict "$stage/Whispy.app"
    echo "   Signatur ok: $(codesign -dvv "$stage/Whispy.app" 2>&1 | grep -E "^Authority=" | head -1 || echo 'ad hoc')"

    rm -rf "$app_path"
    ditto --noextattr --norsrc "$stage/Whispy.app" "$app_path"
    rm -rf "$stage"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/BlitztextMac"
PROJECT_FILE="$PROJECT_DIR/BlitztextMac.xcodeproj"
DERIVED_DATA_PATH="$SCRIPT_DIR/.derivedData-blitztextmac-build"
cd "$PROJECT_DIR"

ensure_xcodebuild_available

if command -v xcodegen &> /dev/null; then
    echo "⚙️  Generiere Xcode-Projekt ..."
    xcodegen generate 2>&1
elif [ -d "$PROJECT_FILE" ]; then
    echo "⚠️  xcodegen nicht gefunden – nutze vorhandenes Xcode-Projekt."
else
    echo "❌ xcodegen fehlt."
    echo "   Installiere xcodegen explizit mit:"
    echo "   brew install xcodegen"
    echo "   Oder stelle sicher, dass $PROJECT_FILE vorhanden ist."
    exit 1
fi

# Bauen
echo "🔨 Baue Whispy ..."
export COPYFILE_DISABLE=1
xcodebuild \
    -project BlitztextMac.xcodeproj \
    -scheme BlitztextMac \
    -destination 'platform=macOS' \
    -configuration "$BUILD_CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="$UNIVERSAL_ARCHS" \
    CODE_SIGNING_ALLOWED=NO \
    clean build

# App finden
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$BUILD_CONFIGURATION/Whispy.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build fehlgeschlagen – keine App gefunden."
    exit 1
fi

xattr -cr "$APP_PATH" 2>/dev/null || true
verify_universal_app "$APP_PATH"

# Resources manuell ins Bundle kopieren (xcodegen kopiert sie nicht automatisch)
echo "📋 Kopiere Resources ..."
RESOURCES_DIR="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES_DIR"
cp -f "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/menubar_icon.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp -f "$PROJECT_DIR/Resources/menubar_icon@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true

# In Projektordner kopieren
DEST="$SCRIPT_DIR/Whispy.app"
rm -rf "$DEST"
cp -R "$APP_PATH" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true
sign_app "$DEST"
verify_universal_app "$DEST"

RUN_TARGET="$DEST"

if [ "$INSTALL_APP" = true ]; then
    APPS_DIR="/Applications"
    INSTALL_DEST="$APPS_DIR/Whispy.app"
    if [ ! -w "$APPS_DIR" ]; then
        echo "❌ /Applications ist nicht beschreibbar."
        echo "   Fuehre den Befehl mit passenden Rechten erneut aus oder ziehe die App manuell nach /Applications."
        exit 1
    fi
    # Laufende Instanz beenden, damit die neue Version sauber ersetzt wird.
    osascript -e 'tell application id "app.claudeflaig.whispy" to quit' >/dev/null 2>&1 || true
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --norsrc "$DEST" "$INSTALL_DEST"
    codesign --verify --deep --strict "$INSTALL_DEST"
    verify_universal_app "$INSTALL_DEST"
    RUN_TARGET="$INSTALL_DEST"
fi

echo ""
echo "✅ Fertig! App liegt unter:"
echo "   $DEST"
if [ "$INSTALL_APP" = true ]; then
    echo "   $RUN_TARGET"
fi
echo ""
echo "Build-Typ: $BUILD_CONFIGURATION"
echo "Architekturen: $UNIVERSAL_ARCHS"
echo "Kompatibel: Apple Silicon + Intel (macOS 14+)"
echo ""
echo "Naechste Schritte:"
echo "1. App starten"
echo "2. Mikrofon erlauben"
echo "3. Fuer direktes Einfuegen zusaetzlich Bedienungshilfen erlauben"
echo "4. In Whispy deinen eigenen OpenAI API Key eintragen"
echo "5. Loslegen und bei Bedarf im Code weiterbauen"
echo ""

# Optional: direkt starten
if [ "$RUN_AFTER" = true ]; then
    echo "🚀 Starte Whispy ..."
    open "$RUN_TARGET"
fi
