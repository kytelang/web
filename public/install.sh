#!/bin/sh
# Kyte installer for macOS and Linux.
#
#   curl -fsSL https://kytelang.org/install.sh | sh
#
# It downloads the release bundle that matches your operating system and CPU,
# creates ~/.kyte in your home directory, and extracts the toolchain there
# (~/.kyte/bin holds the `kyte` compiler and the `kynalyzer` language server).
#
# Environment overrides:
#   KYTE_VERSION       a release tag such as v0.1.0 (default: the latest release)
#   KYTE_REPO          owner/name of the GitHub repo (default: kytelang/kyte)
#   KYTE_HOME          install location (default: $HOME/.kyte)
#   KYTE_NO_MODIFY_PATH set to 1 to skip editing your shell profile
set -eu

REPO="${KYTE_REPO:-kytelang/kyte}"
KYTE_HOME="${KYTE_HOME:-$HOME/.kyte}"

say() { printf '%s\n' "$*"; }
err() { printf 'kyte-install: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || err "this installer needs '$1' on your PATH"; }

need uname
need tar
need mkdir
# One of curl or wget is enough to fetch the archive.
if command -v curl >/dev/null 2>&1; then DL="curl"; elif command -v wget >/dev/null 2>&1; then DL="wget"; else
  err "this installer needs either 'curl' or 'wget'"
fi

fetch() { # fetch <url> <output-file>
  if [ "$DL" = "curl" ]; then
    curl -fSL --proto '=https' --tlsv1.2 -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}
fetch_stdout() { # fetch_stdout <url>  (prints body, empty on 404)
  if [ "$DL" = "curl" ]; then
    curl -fsSL --proto '=https' --tlsv1.2 "$1" 2>/dev/null || true
  else
    wget -q -O - "$1" 2>/dev/null || true
  fi
}

# ---- refuse to run under sudo --------------------------------------------
# This installs into your OWN home ($HOME/.kyte) and edits your shell profile. Running it with sudo
# makes ~/.kyte root-owned and cannot write your ~/.zshrc ("Permission denied"). A genuine root shell
# with no sudo (e.g. a container) is fine; set KYTE_ALLOW_ROOT=1 to override this check.
if [ -n "${SUDO_USER:-}" ] && [ "${KYTE_ALLOW_ROOT:-0}" != "1" ]; then
  err "do not run this installer with sudo -- it installs into your home directory. Re-run without sudo:
  curl -fsSL https://kytelang.github.io/kyte-web/install.sh | sh"
fi

# ---- detect operating system and CPU -------------------------------------
os_raw=$(uname -s)
case "$os_raw" in
  Darwin) OS="macos" ;;
  Linux)  OS="linux" ;;
  *) err "unsupported operating system '$os_raw' (this installer covers macOS and Linux; on Windows use install.ps1)" ;;
esac

arch_raw=$(uname -m)
case "$arch_raw" in
  arm64|aarch64) ARCH="aarch64" ;;
  x86_64|amd64)  ARCH="x86_64" ;;
  *) err "unsupported CPU architecture '$arch_raw'" ;;
esac

# Only the combinations we actually publish.
if [ "$OS" = "macos" ] && [ "$ARCH" = "x86_64" ]; then
  err "Intel macOS is not shipped yet; only Apple Silicon (arm64) builds are published"
fi

# ---- resolve the release tag ---------------------------------------------
VERSION="${KYTE_VERSION:-}"
if [ -z "$VERSION" ]; then
  say "Looking up the latest Kyte release..."
  body=$(fetch_stdout "https://api.github.com/repos/$REPO/releases/latest")
  VERSION=$(printf '%s' "$body" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -n "$VERSION" ] || err "could not determine the latest release tag; set KYTE_VERSION=vX.Y.Z and retry"
fi

ASSET="kyte-$VERSION-$OS-$ARCH.tar.gz"
BASE="https://github.com/$REPO/releases/download/$VERSION"

say "Installing Kyte $VERSION ($OS-$ARCH) into $KYTE_HOME"

# ---- download into a temp directory --------------------------------------
TMP=$(mktemp -d 2>/dev/null || mktemp -d -t kyte-install)
trap 'rm -rf "$TMP"' EXIT INT TERM

say "Downloading $ASSET ..."
fetch "$BASE/$ASSET" "$TMP/$ASSET" || err "download failed: $BASE/$ASSET"

# ---- verify the checksum if the .sha256 sidecar is published -------------
sums=$(fetch_stdout "$BASE/$ASSET.sha256")
if [ -n "$sums" ]; then
  say "Verifying checksum ..."
  printf '%s\n' "$sums" > "$TMP/$ASSET.sha256"
  ( cd "$TMP" && {
      if command -v sha256sum >/dev/null 2>&1; then sha256sum -c "$ASSET.sha256";
      else shasum -a 256 -c "$ASSET.sha256"; fi
    } >/dev/null 2>&1 ) || err "checksum verification failed for $ASSET"
else
  say "No checksum published for this asset; skipping verification."
fi

# ---- extract and install into ~/.kyte ------------------------------------
say "Extracting ..."
tar -xzf "$TMP/$ASSET" -C "$TMP"
# The tarball contains a single top-level directory: kyte-<version>-<os>-<arch>/
SRC="$TMP/kyte-$VERSION-$OS-$ARCH"
[ -d "$SRC/bin" ] || err "unexpected archive layout: $SRC/bin not found"

mkdir -p "$KYTE_HOME/bin" "$KYTE_HOME/lib"
cp -R "$SRC/bin/." "$KYTE_HOME/bin/"
[ -d "$SRC/lib" ] && cp -R "$SRC/lib/." "$KYTE_HOME/lib/"
[ -d "$SRC/std" ] && { rm -rf "$KYTE_HOME/std"; cp -R "$SRC/std" "$KYTE_HOME/std"; }
[ -f "$SRC/VERSION" ] && cp "$SRC/VERSION" "$KYTE_HOME/VERSION"
chmod +x "$KYTE_HOME/bin/"* 2>/dev/null || true

# ---- Kynator daemons (Linux only) ----------------------------------------
# Kynator (the orchestrator) ships as a SEPARATE asset in the same release:
# kynator-<version>-linux-<arch>.tar.gz, whose tarball holds the four daemons at its root
# (service, kynatord, kynatorctl, artifactd). It is a Linux/POSIX-only concern, so it is fetched only
# on Linux and installed beside kyte in ~/.kyte/bin. A release without the bundle (older tags) is not
# an error: the toolchain install already succeeded, so a missing Kynator asset only prints a note.
if [ "$OS" = "linux" ]; then
  KYN_ASSET="kynator-$VERSION-linux-$ARCH.tar.gz"
  say "Downloading $KYN_ASSET ..."
  if fetch "$BASE/$KYN_ASSET" "$TMP/$KYN_ASSET" 2>/dev/null; then
    kyn_sums=$(fetch_stdout "$BASE/$KYN_ASSET.sha256")
    if [ -n "$kyn_sums" ]; then
      printf '%s\n' "$kyn_sums" > "$TMP/$KYN_ASSET.sha256"
      ( cd "$TMP" && {
          if command -v sha256sum >/dev/null 2>&1; then sha256sum -c "$KYN_ASSET.sha256";
          else shasum -a 256 -c "$KYN_ASSET.sha256"; fi
        } >/dev/null 2>&1 ) || err "checksum verification failed for $KYN_ASSET"
    fi
    kyndir="$TMP/kynator"
    mkdir -p "$kyndir"
    tar -xzf "$TMP/$KYN_ASSET" -C "$kyndir"
    cp -R "$kyndir/." "$KYTE_HOME/bin/"
    chmod +x "$KYTE_HOME/bin/"* 2>/dev/null || true
    say "Installed the Kynator daemons (service, kynatord, kynatorctl, artifactd)."
  else
    say "No Kynator bundle in this release ($KYN_ASSET); skipping (kyte itself is installed)."
  fi
fi

# ---- put ~/.kyte/bin on PATH ---------------------------------------------
BIN="$KYTE_HOME/bin"
added_profile=""
if [ "${KYTE_NO_MODIFY_PATH:-0}" != "1" ]; then
  line="export PATH=\"$BIN:\$PATH\""
  case "${SHELL:-}" in
    */zsh) profile="$HOME/.zshrc" ;;
    */bash) if [ -f "$HOME/.bashrc" ]; then profile="$HOME/.bashrc"; else profile="$HOME/.bash_profile"; fi ;;
    *) profile="$HOME/.profile" ;;
  esac
  if [ -n "${profile:-}" ]; then
    if ! grep -qs "# added by kyte installer" "$profile" 2>/dev/null; then
      # Non-fatal: the toolchain is already installed, so a profile that cannot be written should
      # print a manual-PATH hint (below) rather than abort the whole installer under `set -e`.
      if printf '\n# added by kyte installer\n%s\n' "$line" >> "$profile" 2>/dev/null; then
        added_profile="$profile"
      else
        say "Could not update $profile automatically; add the PATH line yourself (shown below)."
      fi
    fi
  fi
fi

say ""
say "Kyte $VERSION is installed in $KYTE_HOME."
if [ -n "$added_profile" ]; then
  say "Added $BIN to your PATH in $added_profile."
  say "Open a new terminal, or run:  export PATH=\"$BIN:\$PATH\""
else
  say "Add $BIN to your PATH:  export PATH=\"$BIN:\$PATH\""
fi
say "Then check it with:  kyte --version"
