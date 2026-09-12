# Kyte installer for Windows (PowerShell).
#
#   powershell -c "irm https://kytelang.org/install.ps1 | iex"
#
# It downloads the release bundle that matches your CPU, creates a .kyte folder
# in your user profile ($env:USERPROFILE\.kyte), and extracts the toolchain
# there (.kyte\bin holds kyte.exe and the kynalyzer language server).
#
# Environment overrides:
#   $env:KYTE_VERSION        a release tag such as v0.1.0 (default: latest release)
#   $env:KYTE_REPO           owner/name of the GitHub repo (default: kytelang/kyte)
#   $env:KYTE_HOME           install location (default: $env:USERPROFILE\.kyte)
#   $env:KYTE_NO_MODIFY_PATH set to 1 to skip updating your user PATH

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocol]::Tls12

function Fail($msg) { Write-Error "kyte-install: $msg"; exit 1 }

$repo     = if ($env:KYTE_REPO) { $env:KYTE_REPO } else { "kytelang/kyte" }
$kyteHome = if ($env:KYTE_HOME) { $env:KYTE_HOME } else { Join-Path $env:USERPROFILE ".kyte" }

# ---- detect CPU architecture --------------------------------------------
$archRaw = $env:PROCESSOR_ARCHITECTURE
switch ($archRaw) {
  "AMD64" { $arch = "x86_64" }
  "ARM64" { Fail "Windows on ARM64 is not shipped yet; only x86_64 builds are published" }
  default { Fail "unsupported CPU architecture '$archRaw'" }
}
$os = "windows"

# ---- resolve the release tag --------------------------------------------
$version = $env:KYTE_VERSION
if (-not $version) {
  Write-Host "Looking up the latest Kyte release..."
  try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ "User-Agent" = "kyte-install" }
    $version = $rel.tag_name
  } catch {
    Fail "could not determine the latest release tag; set `$env:KYTE_VERSION='vX.Y.Z' and retry"
  }
}
if (-not $version) { Fail "empty release tag; set `$env:KYTE_VERSION='vX.Y.Z' and retry" }

$asset = "kyte-$version-$os-$arch.zip"
$base  = "https://github.com/$repo/releases/download/$version"

Write-Host "Installing Kyte $version ($os-$arch) into $kyteHome"

# ---- download into a temp directory -------------------------------------
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("kyte-install-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
  $zipPath = Join-Path $tmp $asset
  Write-Host "Downloading $asset ..."
  try {
    Invoke-WebRequest -Uri "$base/$asset" -OutFile $zipPath -UseBasicParsing -Headers @{ "User-Agent" = "kyte-install" }
  } catch {
    Fail "download failed: $base/$asset"
  }

  # ---- verify the checksum if the .sha256 sidecar is published ----------
  try {
    $sums = (Invoke-WebRequest -Uri "$base/$asset.sha256" -UseBasicParsing -Headers @{ "User-Agent" = "kyte-install" }).Content
  } catch { $sums = $null }
  if ($sums) {
    Write-Host "Verifying checksum ..."
    $expected = ($sums -split '\s+')[0].ToLower()
    $actual = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLower()
    if ($expected -ne $actual) { Fail "checksum verification failed for $asset" }
  } else {
    Write-Host "No checksum published for this asset; skipping verification."
  }

  # ---- extract and install into %USERPROFILE%\.kyte --------------------
  Write-Host "Extracting ..."
  Expand-Archive -Path $zipPath -DestinationPath $tmp -Force
  # The zip contains a single top-level directory: kyte-<version>-<os>-<arch>\
  $src = Join-Path $tmp "kyte-$version-$os-$arch"
  if (-not (Test-Path (Join-Path $src "bin"))) { Fail "unexpected archive layout: $src\bin not found" }

  New-Item -ItemType Directory -Force -Path (Join-Path $kyteHome "bin"), (Join-Path $kyteHome "lib") | Out-Null
  Copy-Item -Recurse -Force (Join-Path $src "bin\*") (Join-Path $kyteHome "bin")
  if (Test-Path (Join-Path $src "lib")) { Copy-Item -Recurse -Force (Join-Path $src "lib\*") (Join-Path $kyteHome "lib") }
  if (Test-Path (Join-Path $src "std")) {
    $dstStd = Join-Path $kyteHome "std"
    if (Test-Path $dstStd) { Remove-Item -Recurse -Force $dstStd }
    Copy-Item -Recurse -Force (Join-Path $src "std") $dstStd
  }
  if (Test-Path (Join-Path $src "VERSION")) { Copy-Item -Force (Join-Path $src "VERSION") (Join-Path $kyteHome "VERSION") }
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# ---- put .kyte\bin on the user PATH -------------------------------------
$bin = Join-Path $kyteHome "bin"
if ($env:KYTE_NO_MODIFY_PATH -ne "1") {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $userPath) { $userPath = "" }
  $parts = $userPath -split ';' | Where-Object { $_ -ne "" }
  if ($parts -notcontains $bin) {
    $newPath = if ($userPath -eq "") { $bin } else { "$userPath;$bin" }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$bin"
    Write-Host "Added $bin to your user PATH."
  }
}

Write-Host ""
Write-Host "Kyte $version is installed in $kyteHome."
Write-Host "Open a new terminal, then check it with:  kyte --version"
