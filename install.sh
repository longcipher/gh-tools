#!/usr/bin/env bash
set -euo pipefail

# Install gh_issues.nu as a global gh-issues command.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="$SCRIPT_DIR/gh_issues.nu"

if [[ ! -f "$SOURCE_FILE" ]]; then
  echo "Error: cannot find $SOURCE_FILE"
  exit 1
fi

PREFIX=""
if [[ "${1:-}" == "--prefix" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Error: --prefix requires a directory path"
    exit 1
  fi
  PREFIX="$2"
fi

if [[ -z "$PREFIX" ]]; then
  if [[ -w "/usr/local/bin" ]]; then
    PREFIX="/usr/local/bin"
  else
    PREFIX="$HOME/.local/bin"
  fi
fi

mkdir -p "$PREFIX"
chmod +x "$SOURCE_FILE"
ln -sf "$SOURCE_FILE" "$PREFIX/gh-issues"

echo "Installed: $PREFIX/gh-issues -> $SOURCE_FILE"
echo "If '$PREFIX' is not in PATH, add this line to ~/.zshrc:"
echo "  export PATH=\"$PREFIX:\$PATH\""
echo ""
echo "Usage:"
echo "  gh-issues owner/repo --state all --limit 50"
