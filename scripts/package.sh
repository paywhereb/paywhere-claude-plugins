#!/usr/bin/env bash
# Package the paywhere-smb plugin directory as a side-loadable archive.
#
# Produces two artifacts in dist/:
#   paywhere-smb-<version>.plugin   — what Cowork calls a "plugin file" for side-loading.
#   paywhere-smb-<version>.zip      — identical contents under the .zip extension for
#                                      Claude Code's `--plugin-dir <archive>` / `--plugin-url`.
#
# Both archives contain the contents of paywhere-smb/ at the archive root (no top-level prefix).
# This matches the Claude Code plugin-archive convention (see code.claude.com/docs/en/plugins).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$REPO_ROOT/paywhere-smb"
DIST_DIR="$REPO_ROOT/dist"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "error: manifest not found at $MANIFEST" >&2
  exit 1
fi

# Pull version from the manifest. Falls back to "dev" if jq isn't available or the field is missing.
if command -v jq >/dev/null 2>&1; then
  VERSION="$(jq -r '.version // "dev"' "$MANIFEST")"
else
  VERSION="$(grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$MANIFEST" | sed -E 's/.*"([^"]+)"$/\1/')"
  VERSION="${VERSION:-dev}"
fi

mkdir -p "$DIST_DIR"

ZIP_OUT="$DIST_DIR/paywhere-smb-$VERSION.zip"
PLUGIN_OUT="$DIST_DIR/paywhere-smb-$VERSION.plugin"

rm -f "$ZIP_OUT" "$PLUGIN_OUT"

# Zip the contents of paywhere-smb/ at the archive root so the resulting archive
# can be loaded directly with `claude --plugin-dir <archive>`.
(
  cd "$PLUGIN_DIR"
  zip -rq "$ZIP_OUT" . \
    -x '*.DS_Store' \
    -x '__MACOSX/*' \
    -x '*.swp'
)

# Mirror the same archive under .plugin extension for Cowork's side-load flow.
cp "$ZIP_OUT" "$PLUGIN_OUT"

echo "Packaged paywhere-smb v$VERSION:"
echo "  $ZIP_OUT     ($(stat -c%s "$ZIP_OUT" 2>/dev/null || stat -f%z "$ZIP_OUT") bytes)"
echo "  $PLUGIN_OUT  ($(stat -c%s "$PLUGIN_OUT" 2>/dev/null || stat -f%z "$PLUGIN_OUT") bytes)"
