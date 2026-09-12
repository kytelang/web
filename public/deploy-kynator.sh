#!/usr/bin/env bash
# Deploy Kynator, the Kyte-native orchestrator, from a GitHub release onto a systemd Linux host.
#
#   curl -fsSL https://kytelang.org/deploy-kynator.sh | sudo bash -s -- --enable --start
#
# It downloads the release bundle for this machine's CPU, installs the four daemons
# (artifactd, kynatord, kynatorctl, service), creates the service user and data
# directories, seeds config templates, and writes the three systemd units. Kynator
# is a Linux production concern (the fd-handoff data plane is POSIX-only), so this
# script is Linux + systemd only.
#
# Flags:
#   --enable   systemctl enable the units (start on boot)
#   --start    systemctl start the units now
#
# Environment overrides:
#   KYNATOR_VERSION  release tag such as v0.1.0 (default: the latest release)
#   KYNATOR_REPO     owner/name of the GitHub repo (default: kytelang/kyte-orchestrator)
#   BIN_DIR   /opt/kyte-orchestrator/bin      binaries are installed here
#   CONF_DIR  /etc/kyte-orchestrator          kynatord.json / service.json / artifactd.env
#   DATA_DIR  /var/lib/kyte-orchestrator      blobs, config.snap, discovery/metrics files
#   SVC_USER  kyte                            unprivileged user for artifactd + service
set -euo pipefail

REPO="${KYNATOR_REPO:-kytelang/kyte-orchestrator}"
BIN_DIR="${BIN_DIR:-/opt/kyte-orchestrator/bin}"
CONF_DIR="${CONF_DIR:-/etc/kyte-orchestrator}"
DATA_DIR="${DATA_DIR:-/var/lib/kyte-orchestrator}"
SVC_USER="${SVC_USER:-kyte}"
DO_ENABLE=0; DO_START=0

for arg in "$@"; do
  case "$arg" in
    --enable) DO_ENABLE=1 ;;
    --start)  DO_START=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

err() { printf 'deploy-kynator: %s\n' "$*" >&2; exit 1; }

# ---- host checks ---------------------------------------------------------
[ "$(uname -s)" = "Linux" ] || err "Kynator ships for Linux only (the fd-handoff data plane is POSIX-only)"
[ "$(id -u)" -eq 0 ] || err "run as root (e.g. pipe into 'sudo bash')"
command -v systemctl >/dev/null 2>&1 || err "systemctl not found; this deployer targets systemd Linux"
if command -v curl >/dev/null 2>&1; then DL=curl; elif command -v wget >/dev/null 2>&1; then DL=wget; else
  err "need either 'curl' or 'wget'"
fi
command -v tar >/dev/null 2>&1 || err "need 'tar'"

fetch()        { if [ "$DL" = curl ]; then curl -fSL --proto '=https' --tlsv1.2 -o "$2" "$1"; else wget -q -O "$2" "$1"; fi; }
fetch_stdout() { if [ "$DL" = curl ]; then curl -fsSL --proto '=https' --tlsv1.2 "$1" 2>/dev/null || true; else wget -q -O - "$1" 2>/dev/null || true; fi; }

# ---- detect CPU ----------------------------------------------------------
case "$(uname -m)" in
  x86_64|amd64)  ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) err "unsupported CPU architecture '$(uname -m)' (Kynator ships linux x86_64 and arm64)" ;;
esac

# ---- resolve the release tag ---------------------------------------------
VERSION="${KYNATOR_VERSION:-}"
if [ -z "$VERSION" ]; then
  echo "Looking up the latest Kynator release..."
  body=$(fetch_stdout "https://api.github.com/repos/$REPO/releases/latest")
  VERSION=$(printf '%s' "$body" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  [ -n "$VERSION" ] || err "could not determine the latest release tag; set KYNATOR_VERSION=vX.Y.Z and retry"
fi

ASSET="kyte-orchestrator-$VERSION-linux-$ARCH.tar.gz"
BASE="https://github.com/$REPO/releases/download/$VERSION"

echo "Deploying Kynator $VERSION (linux-$ARCH) from $REPO"

# ---- download + verify + extract -----------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM

echo "Downloading $ASSET ..."
fetch "$BASE/$ASSET" "$TMP/$ASSET" || err "download failed: $BASE/$ASSET"

sums=$(fetch_stdout "$BASE/$ASSET.sha256")
if [ -n "$sums" ]; then
  echo "Verifying checksum ..."
  printf '%s\n' "$sums" > "$TMP/$ASSET.sha256"
  ( cd "$TMP" && { command -v sha256sum >/dev/null 2>&1 && sha256sum -c "$ASSET.sha256" || shasum -a 256 -c "$ASSET.sha256"; } >/dev/null 2>&1 ) \
    || err "checksum verification failed for $ASSET"
fi

echo "Extracting ..."
mkdir -p "$TMP/bin"
tar -xzf "$TMP/$ASSET" -C "$TMP/bin"

# ---- service user + directories ------------------------------------------
echo "==> Creating service user '$SVC_USER' (if absent) and directories"
id -u "$SVC_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$SVC_USER"
install -d -m 0755 "$BIN_DIR" "$CONF_DIR"
install -d -m 0750 -o "$SVC_USER" -g "$SVC_USER" "$DATA_DIR" "$DATA_DIR/artifacts" "$DATA_DIR/manifests"

# ---- install binaries ----------------------------------------------------
echo "==> Installing binaries into $BIN_DIR"
for b in service kynatord kynatorctl artifactd; do
  [ -x "$TMP/bin/$b" ] || err "release archive is missing '$b'"
  install -m 0755 "$TMP/bin/$b" "$BIN_DIR/$b"
done

# ---- seed config templates (never overwrite an existing file) ------------
echo "==> Seeding config templates (only if absent)"
[ -f "$CONF_DIR/kynatord.json" ] || printf '{\n  "manifestsDir": "%s/manifests",\n  "reconcileMs": 2000,\n  "nodeId": "node-1",\n  "discoveryFile": "%s/discovery.txt",\n  "metricsFile": "%s/metrics.prom",\n  "store": { "enabled": true, "addr": "127.0.0.1:8135", "token": "", "tls": false }\n}\n' "$DATA_DIR" "$DATA_DIR" "$DATA_DIR" > "$CONF_DIR/kynatord.json"
[ -f "$CONF_DIR/service.json" ] || printf '{\n  "listenHost": "0.0.0.0", "listenPort": 8090, "strategy": "roundrobin",\n  "health": { "enabled": true, "path": "/healthz", "intervalMs": 2000, "timeoutMs": 1000, "rise": 2, "fall": 3 },\n  "backends": []\n}\n' > "$CONF_DIR/service.json"
[ -f "$CONF_DIR/artifactd.env" ] || { printf '# KYTE_ARTIFACT_TOKEN=change-me-deploy-token\n' > "$CONF_DIR/artifactd.env"; chmod 0640 "$CONF_DIR/artifactd.env"; chgrp "$SVC_USER" "$CONF_DIR/artifactd.env"; }

# ---- systemd units -------------------------------------------------------
echo "==> Installing systemd units"
cat > /etc/systemd/system/kyte-artifactd.service <<UNIT
[Unit]
Description=Kynator artifactd (content-addressed blob store + config store)
Documentation=https://github.com/$REPO
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SVC_USER
Group=$SVC_USER
Environment=KYTE_ARTIFACT_ROOT=$DATA_DIR/artifacts
Environment=KYTE_PORT=8135
EnvironmentFile=-$CONF_DIR/artifactd.env
ExecStart=$BIN_DIR/artifactd
WorkingDirectory=$DATA_DIR
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/kyte-kynatord.service <<UNIT
[Unit]
Description=Kynator kynatord (control plane: reconcile, supervise replicas, HA lease, discovery)
Documentation=https://github.com/$REPO
After=network-online.target kyte-artifactd.service
Wants=network-online.target

[Service]
Type=simple
# kynatord spawns and supervises replicas and applies cgroup / netns isolation, which needs privilege.
User=root
Group=root
ExecStart=$BIN_DIR/kynatord $CONF_DIR/kynatord.json
WorkingDirectory=$DATA_DIR
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/systemd/system/kyte-service.service <<UNIT
[Unit]
Description=Kynator service (data-plane gateway: L7 proxy / load balancer, fd-handoff)
Documentation=https://github.com/$REPO
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$SVC_USER
Group=$SVC_USER
ExecStart=$BIN_DIR/service $CONF_DIR/service.json
WorkingDirectory=$DATA_DIR
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

if [ "$DO_ENABLE" = 1 ]; then
  echo "==> Enabling units (start on boot)"
  systemctl enable kyte-artifactd.service kyte-kynatord.service kyte-service.service
fi
if [ "$DO_START" = 1 ]; then
  echo "==> Starting units"
  systemctl start kyte-artifactd.service kyte-kynatord.service kyte-service.service
fi

echo ""
echo "Kynator $VERSION is installed."
echo "  binaries : $BIN_DIR"
echo "  config   : $CONF_DIR/{kynatord.json,service.json,artifactd.env}"
echo "  data     : $DATA_DIR"
echo "Edit the config, then:  systemctl enable --now kyte-artifactd kyte-kynatord kyte-service"
echo "Check status with:      systemctl status kyte-kynatord"
