#!/bin/bash
#
# BDM Native Messaging Host — Installer
#
# Installs native messaging host manifests for Chrome and Firefox on macOS.
# Run this script after installing BDM.app to /Applications.
#
# Usage:
#   chmod +x install.sh
#   ./install.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BDM_HOST_PATH="/Applications/BDM.app/Contents/Resources/bdm-native-host"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "================================================"
echo "  BDM Native Messaging Host Installer"
echo "================================================"
echo ""

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------

if [ ! -f "$BDM_HOST_PATH" ]; then
    echo -e "${YELLOW}Warning:${NC} BDM native host binary not found at:"
    echo "  $BDM_HOST_PATH"
    echo ""
    echo "Make sure BDM.app is installed in /Applications before using the extension."
    echo "Continuing with installation of manifest files..."
    echo ""
fi

# ---------------------------------------------------------------------------
# Chrome
# ---------------------------------------------------------------------------

CHROME_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
CHROME_MANIFEST="com.amirhpcom.bdm.json"

echo "--- Chrome ---"

if [ -d "$HOME/Library/Application Support/Google/Chrome" ]; then
    mkdir -p "$CHROME_DIR"
    cp "$SCRIPT_DIR/$CHROME_MANIFEST" "$CHROME_DIR/$CHROME_MANIFEST"

    # Update the path in the installed manifest
    sed -i '' "s|/Applications/BDM.app/Contents/Resources/bdm-native-host|$BDM_HOST_PATH|g" \
        "$CHROME_DIR/$CHROME_MANIFEST"

    echo -e "${GREEN}Installed:${NC} $CHROME_DIR/$CHROME_MANIFEST"
else
    echo -e "${YELLOW}Skipped:${NC} Chrome not found (no profile directory)"
fi

# Also install for Chromium-based browsers
CHROMIUM_DIR="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
if [ -d "$HOME/Library/Application Support/Chromium" ]; then
    mkdir -p "$CHROMIUM_DIR"
    cp "$SCRIPT_DIR/$CHROME_MANIFEST" "$CHROMIUM_DIR/$CHROME_MANIFEST"
    sed -i '' "s|/Applications/BDM.app/Contents/Resources/bdm-native-host|$BDM_HOST_PATH|g" \
        "$CHROMIUM_DIR/$CHROME_MANIFEST"
    echo -e "${GREEN}Installed:${NC} $CHROMIUM_DIR/$CHROME_MANIFEST"
fi

BRAVE_DIR="$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
if [ -d "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" ]; then
    mkdir -p "$BRAVE_DIR"
    cp "$SCRIPT_DIR/$CHROME_MANIFEST" "$BRAVE_DIR/$CHROME_MANIFEST"
    sed -i '' "s|/Applications/BDM.app/Contents/Resources/bdm-native-host|$BDM_HOST_PATH|g" \
        "$BRAVE_DIR/$CHROME_MANIFEST"
    echo -e "${GREEN}Installed:${NC} $BRAVE_DIR/$CHROME_MANIFEST"
fi

EDGE_DIR="$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
if [ -d "$HOME/Library/Application Support/Microsoft Edge" ]; then
    mkdir -p "$EDGE_DIR"
    cp "$SCRIPT_DIR/$CHROME_MANIFEST" "$EDGE_DIR/$CHROME_MANIFEST"
    sed -i '' "s|/Applications/BDM.app/Contents/Resources/bdm-native-host|$BDM_HOST_PATH|g" \
        "$EDGE_DIR/$CHROME_MANIFEST"
    echo -e "${GREEN}Installed:${NC} $EDGE_DIR/$CHROME_MANIFEST"
fi

echo ""

# ---------------------------------------------------------------------------
# Firefox
# ---------------------------------------------------------------------------

FIREFOX_DIR="$HOME/Library/Application Support/Mozilla/NativeMessagingHosts"
FIREFOX_MANIFEST="com.amirhpcom.bdm-firefox.json"
FIREFOX_INSTALLED_NAME="com.amirhpcom.bdm.json"

echo "--- Firefox ---"

if [ -d "$HOME/Library/Application Support/Mozilla" ]; then
    mkdir -p "$FIREFOX_DIR"
    # Firefox expects the manifest filename to match the "name" field
    cp "$SCRIPT_DIR/$FIREFOX_MANIFEST" "$FIREFOX_DIR/$FIREFOX_INSTALLED_NAME"

    sed -i '' "s|/Applications/BDM.app/Contents/Resources/bdm-native-host|$BDM_HOST_PATH|g" \
        "$FIREFOX_DIR/$FIREFOX_INSTALLED_NAME"

    echo -e "${GREEN}Installed:${NC} $FIREFOX_DIR/$FIREFOX_INSTALLED_NAME"
else
    echo -e "${YELLOW}Skipped:${NC} Firefox not found (no profile directory)"
fi

echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo "================================================"
echo -e "${GREEN}Installation complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Make sure BDM.app is in /Applications"
echo "  2. Restart your browser(s)"
echo "  3. Install the BDM browser extension:"
echo "     - Chrome:  Load unpacked from extensions/chrome/"
echo "     - Firefox: Load temporary add-on from extensions/firefox/"
echo "     - Safari:  Build the Xcode project from extensions/safari/"
echo ""
echo "If you installed the Chrome extension, update the"
echo "  allowed_origins in $CHROME_DIR/$CHROME_MANIFEST"
echo "  with your extension's actual ID."
echo "================================================"
