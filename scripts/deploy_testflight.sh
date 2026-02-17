#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Build settings
SCHEME="${SCHEME:-NewsAlert}"
CONFIGURATION="${CONFIGURATION:-Release}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
TEAM_ID="${TEAM_ID:-3PQUPPT6U8}"

# You can provide WORKSPACE_PATH instead of PROJECT_PATH.
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/NewsAlert.xcodeproj}"
WORKSPACE_PATH="${WORKSPACE_PATH:-}"

# Output paths
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build/testflight}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_DIR/$SCHEME.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$BUILD_DIR/export}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$BUILD_DIR/ExportOptions.plist}"

# Build behavior
CLEAN_BUILD="${CLEAN_BUILD:-1}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

# App Store Connect API key auth
# Required: ASC_KEY_ID, ASC_ISSUER_ID
# Optional: ASC_KEY_PATH (path to AuthKey_<KEY_ID>.p8)
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
ASC_KEY_PATH="${ASC_KEY_PATH:-}"

usage() {
  cat <<EOF
Usage:
  ASC_KEY_ID=<KEY_ID> ASC_ISSUER_ID=<ISSUER_ID> [ASC_KEY_PATH=/path/AuthKey_<KEY_ID>.p8] ./scripts/deploy_testflight.sh

Optional environment overrides:
  SCHEME                       (default: NewsAlert)
  CONFIGURATION                (default: Release)
  DESTINATION                  (default: generic/platform=iOS)
  TEAM_ID                      (default: 3PQUPPT6U8)
  PROJECT_PATH                 (default: <repo>/NewsAlert.xcodeproj)
  WORKSPACE_PATH               (if set, used instead of PROJECT_PATH)
  BUILD_DIR                    (default: <repo>/build/testflight)
  ARCHIVE_PATH                 (default: <BUILD_DIR>/<SCHEME>.xcarchive)
  EXPORT_DIR                   (default: <BUILD_DIR>/export)
  EXPORT_OPTIONS_PLIST         (default: <BUILD_DIR>/ExportOptions.plist)
  CLEAN_BUILD                  (default: 1)
  ALLOW_PROVISIONING_UPDATES   (default: 1)

Examples:
  ASC_KEY_ID=ABC123DEF4 ASC_ISSUER_ID=11111111-2222-3333-4444-555555555555 ./scripts/deploy_testflight.sh
  WORKSPACE_PATH="\$PWD/NewsAlert.xcworkspace" ASC_KEY_ID=ABC123DEF4 ASC_ISSUER_ID=... ./scripts/deploy_testflight.sh
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd xcodebuild
require_cmd xcrun
require_cmd plutil

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$ASC_KEY_ID" || -z "$ASC_ISSUER_ID" ]]; then
  echo "ASC_KEY_ID and ASC_ISSUER_ID are required." >&2
  usage
  exit 1
fi

if [[ -z "$WORKSPACE_PATH" && ! -d "$PROJECT_PATH" ]]; then
  echo "Project not found at: $PROJECT_PATH" >&2
  exit 1
fi

if [[ -n "$WORKSPACE_PATH" && ! -d "$WORKSPACE_PATH" ]]; then
  echo "Workspace not found at: $WORKSPACE_PATH" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR" "$EXPORT_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
EOF

plutil -lint "$EXPORT_OPTIONS_PLIST" >/dev/null

TEMP_KEYS_DIR=""
cleanup() {
  if [[ -n "$TEMP_KEYS_DIR" && -d "$TEMP_KEYS_DIR" ]]; then
    rm -rf "$TEMP_KEYS_DIR"
  fi
}
trap cleanup EXIT

if [[ -n "$ASC_KEY_PATH" ]]; then
  if [[ ! -f "$ASC_KEY_PATH" ]]; then
    echo "ASC_KEY_PATH file not found: $ASC_KEY_PATH" >&2
    exit 1
  fi

  TEMP_KEYS_DIR="$(mktemp -d)"
  cp "$ASC_KEY_PATH" "$TEMP_KEYS_DIR/AuthKey_${ASC_KEY_ID}.p8"
  export API_PRIVATE_KEYS_DIR="$TEMP_KEYS_DIR"
fi

echo "==> Archiving $SCHEME"
archive_cmd=(xcodebuild)

if [[ "$CLEAN_BUILD" == "1" ]]; then
  archive_cmd+=(clean)
fi

if [[ -n "$WORKSPACE_PATH" ]]; then
  archive_cmd+=(-workspace "$WORKSPACE_PATH")
else
  archive_cmd+=(-project "$PROJECT_PATH")
fi

archive_cmd+=(
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "$DESTINATION"
  -archivePath "$ARCHIVE_PATH"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  archive_cmd+=(-allowProvisioningUpdates)
fi

archive_cmd+=(archive)

"${archive_cmd[@]}"

echo "==> Exporting IPA"
export_cmd=(
  xcodebuild
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_DIR"
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  export_cmd+=(-allowProvisioningUpdates)
fi

"${export_cmd[@]}"

IPA_PATH="$(find "$EXPORT_DIR" -maxdepth 1 -name "*.ipa" -print -quit)"
if [[ -z "$IPA_PATH" ]]; then
  echo "No IPA found in $EXPORT_DIR" >&2
  exit 1
fi

echo "==> Uploading to TestFlight"
xcrun altool \
  --upload-app \
  --type ios \
  --file "$IPA_PATH" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "Done. Uploaded: $IPA_PATH"
