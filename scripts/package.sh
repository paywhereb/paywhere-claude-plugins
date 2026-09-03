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
#
# When the plugin's .mcp.json points the Paywhere connector at the hosted demo
# (PAYWHERE_DEMO_URL below), a third artifact is built as well:
#   <plugin>-<version>-poc.plugin — the same contents with that one URL swapped for
#                                   the PoC stack (PAYWHERE_POC_URL), so a PoC build
#                                   can be side-loaded into Cowork without editing
#                                   the committed manifest.
# Override the PoC target per invocation:
#   PAYWHERE_POC_URL=https://<name>.poc.dev.paywhere.com/mcp ./scripts/package.sh paywhere-smb

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The Paywhere MCP the committed .mcp.json points at, and the PoC stack the -poc
# variant substitutes for it (paywhere-mcp/poc/poc-mock.config: POC_NAME drives
# <name>.poc.dev.paywhere.com).
PAYWHERE_DEMO_URL="${PAYWHERE_DEMO_URL:-https://demo.dev.paywhere.com/mcp}"
PAYWHERE_POC_URL="${PAYWHERE_POC_URL:-https://paywhere-mock-mcp.poc.dev.paywhere.com/mcp}"

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

# PoC variant: only for plugins whose .mcp.json names the hosted demo Paywhere MCP.
MCP_JSON="$PLUGIN_DIR/.mcp.json"
POC_OUT="$DIST_DIR/$PLUGIN_NAME-$VERSION-poc.plugin"
rm -f "$POC_OUT"
if [[ -f "$MCP_JSON" ]] && grep -qF "\"$PAYWHERE_DEMO_URL\"" "$MCP_JSON"; then
  STAGE="$(mktemp -d)"
  trap 'rm -rf "$STAGE"' EXIT
  cp -a "$PLUGIN_DIR/." "$STAGE/"
  # Swap only the exact demo URL string; every other server entry is untouched.
  sed -i.bak "s#\"$PAYWHERE_DEMO_URL\"#\"$PAYWHERE_POC_URL\"#" "$STAGE/.mcp.json"
  rm -f "$STAGE/.mcp.json.bak"
  (
    cd "$STAGE"
    zip -rq "$POC_OUT" . \
      -x '*.DS_Store' \
      -x '__MACOSX/*' \
      -x '*.swp'
  )
  echo "  $POC_OUT  ($(stat -c%s "$POC_OUT" 2>/dev/null || stat -f%z "$POC_OUT") bytes)  Paywhere → $PAYWHERE_POC_URL"
fi
