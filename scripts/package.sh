#!/usr/bin/env bash
# Package a plugin directory as a side-loadable archive.
#
# Usage:
#   ./scripts/package.sh <plugin-name>
#
# Examples:
#   ./scripts/package.sh paywhere-smb
#   ./scripts/package.sh paywhere-eng-workflow
#
# Produces two artifacts in dist/:
#   <plugin>-<version>.plugin   — what Cowork calls a "plugin file" for side-loading.
#   <plugin>-<version>.zip      — identical contents under the .zip extension for
#                                   Claude Code's `--plugin-dir <archive>` / `--plugin-url`.
#
# Both archives contain the contents of <plugin>/ at the archive root (no top-level prefix).
# This matches the Claude Code plugin-archive convention (see code.claude.com/docs/en/plugins).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "usage: $(basename "$0") <plugin-name>" >&2
  echo "       known plugins:" >&2
  for d in "$REPO_ROOT"/*/; do
    name="$(basename "$d")"
    if [[ -f "$d.claude-plugin/plugin.json" ]]; then
      echo "         $name" >&2
    fi
  done
  exit 2
fi

PLUGIN_NAME="$1"
PLUGIN_DIR="$REPO_ROOT/$PLUGIN_NAME"
DIST_DIR="$REPO_ROOT/dist"
MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -d "$PLUGIN_DIR" ]]; then
  echo "error: plugin directory not found: $PLUGIN_DIR" >&2
  echo "       known plugins:" >&2
  for d in "$REPO_ROOT"/*/; do
    name="$(basename "$d")"
    if [[ -f "$d.claude-plugin/plugin.json" ]]; then
      echo "         $name" >&2
    fi
  done
  exit 1
fi

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

ZIP_OUT="$DIST_DIR/$PLUGIN_NAME-$VERSION.zip"
PLUGIN_OUT="$DIST_DIR/$PLUGIN_NAME-$VERSION.plugin"

rm -f "$ZIP_OUT" "$PLUGIN_OUT"

# Zip the contents of <plugin>/ at the archive root so the resulting archive
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

echo "Packaged $PLUGIN_NAME v$VERSION:"
echo "  $ZIP_OUT     ($(stat -c%s "$ZIP_OUT" 2>/dev/null || stat -f%z "$ZIP_OUT") bytes)"
echo "  $PLUGIN_OUT  ($(stat -c%s "$PLUGIN_OUT" 2>/dev/null || stat -f%z "$PLUGIN_OUT") bytes)"
