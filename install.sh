#!/usr/bin/env bash
# Installer for e-kotov/jcode macOS arm64 and Linux x86_64 builds.
# Stripped from upstream scripts/install.sh: no telemetry, no jcode.sh
# mirrors, no shell rc edits, no notification helper, no hotkey LaunchAgent.
set -euo pipefail

REPO="e-kotov/jcode"
tmpdir=""

info() { printf '\033[1;34m%s\033[0m\n' "$*"; }
err()  { printf '\033[1;31merror: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() { [ -z "$tmpdir" ] || rm -rf "$tmpdir"; }
trap cleanup EXIT

valid_release_tag() {
  printf '%s' "$1" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$'
}

case "$(uname -s):$(uname -m)" in
  Darwin:arm64) ARTIFACT="jcode-macos-aarch64" ;;
  Linux:x86_64) ARTIFACT="jcode-linux-x86_64" ;;
  *) err "This build supports macOS arm64 and Linux x86_64 only" ;;
esac

INSTALL_DIR="${JCODE_INSTALL_DIR:-$HOME/.local/bin}"

# GitHub's /releases/latest redirect avoids the rate-limited API.
VERSION="${JCODE_VERSION:-}"
if [ -z "$VERSION" ]; then
  LATEST_RELEASE_URL=$(curl -fsSIL --retry 2 --connect-timeout 10 \
    -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)
  case "$LATEST_RELEASE_URL" in
    */releases/tag/*) VERSION="${LATEST_RELEASE_URL##*/}" ;;
  esac
fi
valid_release_tag "$VERSION" || err "Failed to determine latest version"

RELEASE_BASE="https://github.com/$REPO/releases/download/$VERSION"
builds_dir="$HOME/.jcode/builds"
stable_dir="$builds_dir/stable"
version_dir="$builds_dir/versions"
launcher_path="$INSTALL_DIR/jcode"

EXISTING=""
if [ -x "$launcher_path" ]; then
  EXISTING=$("$launcher_path" --version 2>/dev/null | head -1 || echo "unknown")
fi
if [ -n "$EXISTING" ]; then
  if echo "$EXISTING" | grep -qF "${VERSION#v}"; then
    info "jcode $VERSION is already installed — reinstalling"
  else
    info "Updating jcode $EXISTING → $VERSION"
  fi
else
  info "Installing jcode $VERSION"
fi
info "  launcher: $launcher_path"

tmpdir=$(mktemp -d)
curl -fsSL --retry 2 --connect-timeout 10 "$RELEASE_BASE/$ARTIFACT.tar.gz" -o "$tmpdir/jcode.tar.gz" \
  || err "Failed to download $ARTIFACT.tar.gz for $VERSION"

EXPECTED_SHA256=$(curl -fsSL --retry 2 --connect-timeout 10 "$RELEASE_BASE/SHA256SUMS" 2>/dev/null |
  awk -v asset="$ARTIFACT.tar.gz" '$2 == asset || $2 == "*" asset { print tolower($1); exit }' || true)
printf '%s' "$EXPECTED_SHA256" | grep -Eq '^[0-9a-f]{64}$' \
  || err "Could not find a SHA-256 checksum for $ARTIFACT.tar.gz in $VERSION"
ACTUAL_SHA256=$(shasum -a 256 "$tmpdir/jcode.tar.gz" | awk '{print tolower($1)}')
[ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || err "SHA-256 verification failed for $ARTIFACT.tar.gz"
info "Verified SHA-256: $ARTIFACT.tar.gz"

version="${VERSION#v}"
dest_version_dir="$version_dir/$version"
mkdir -p "$INSTALL_DIR" "$stable_dir" "$dest_version_dir"

tar xzf "$tmpdir/jcode.tar.gz" -C "$dest_version_dir"
[ -f "$dest_version_dir/$ARTIFACT" ] || err "Downloaded archive did not contain expected binary: $ARTIFACT"
mv -f "$dest_version_dir/$ARTIFACT" "$dest_version_dir/jcode"
chmod +x "$dest_version_dir/jcode"
if [ "$(uname -s)" = "Darwin" ]; then
  xattr -d com.apple.quarantine "$dest_version_dir/jcode" 2>/dev/null || true
fi

# Same layout the built-in updater writes: versions/<v> -> stable -> launcher.
ln -sfn "$dest_version_dir/jcode" "$stable_dir/jcode"
printf '%s\n' "$version" > "$builds_dir/stable-version"
ln -sfn "$stable_dir/jcode" "$launcher_path"

# Hand a running background server over to the new binary (best-effort).
if [ "${JCODE_SKIP_SERVER_RELOAD:-}" != "1" ]; then
  if "$launcher_path" server reload </dev/null >/dev/null 2>&1; then
    info "Reloaded the running jcode server onto $VERSION (if one was active)."
  fi
fi

echo ""
info "✅ jcode $VERSION installed."
case ":$PATH:" in
  *":$INSTALL_DIR:"*) info "Run 'jcode' to get started." ;;
  *)
    echo "  $INSTALL_DIR is not on your PATH. Add it yourself, e.g.:"
    # shellcheck disable=SC2016  # print $PATH literally
    printf '    export PATH="%s:$PATH"\n' "$INSTALL_DIR"
    ;;
esac
