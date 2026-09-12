#!/usr/bin/env bash
# Install this repo into the live Omarchy plugins directory.
#
# The repo is authoritative; the installed copy is a disposable build artifact.
# Rsync rather than symlink: omarchy-plugin-validate refuses a plugin folder
# that contains symlinks, and would see a symlinked plugin dir as one.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="$(jq -r '.id' "$REPO_DIR/manifest.json")"
DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

usage() {
  cat <<USAGE
Usage: ./deploy.sh [--validate-only] [--no-restart]

Syncs the repo into $DEST, then restarts the Omarchy shell so the plugin
reloads. Run with --validate-only to check the manifest without installing.
USAGE
}

VALIDATE_ONLY=0
RESTART=1
while (($# > 0)); do
  case "$1" in
  --validate-only) VALIDATE_ONLY=1; shift ;;
  --no-restart) RESTART=0; shift ;;
  -h | --help) usage; exit 0 ;;
  *) echo "deploy: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate against the same schema the running shell enforces. Catching a bad
# manifest here beats watching the shell silently skip the plugin.
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$REPO_DIR"
  echo "deploy: manifest valid ($PLUGIN_ID)"
else
  echo "deploy: omarchy-plugin-validate not found, skipping schema check" >&2
fi

((VALIDATE_ONLY)) && exit 0

mkdir -p "$DEST"
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.github/' \
  --exclude '.gitignore' \
  --exclude 'deploy.sh' \
  --exclude 'docs/' \
  --exclude '.probe/' \
  "$REPO_DIR/" "$DEST/"

echo "deploy: installed to $DEST"

if ((RESTART)); then
  if command -v omarchy-restart-shell >/dev/null 2>&1; then
    echo "deploy: restarting omarchy shell"
    omarchy-restart-shell || echo "deploy: restart reported failure; check that the shell came back" >&2
  else
    echo "deploy: omarchy-restart-shell not found; restart the shell manually" >&2
  fi
fi

cat <<NEXT

To select Celeste as the active bar:
  jq '.bar.id = "$PLUGIN_ID"' ~/.config/omarchy/shell.json > /tmp/shell.json \\
    && mv /tmp/shell.json ~/.config/omarchy/shell.json

To go back to the built-in bar:
  jq 'del(.bar.id)' ~/.config/omarchy/shell.json > /tmp/shell.json \\
    && mv /tmp/shell.json ~/.config/omarchy/shell.json
NEXT
