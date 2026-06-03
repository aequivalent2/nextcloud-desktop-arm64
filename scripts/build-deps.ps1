Write-Host "Building dependencies for ARM64..."

# Qt-Pfad aus Umgebungsvariable (wird vom Workflow gesetzt)
# Fallback: dynamisch in C:\Qt suchen
if ($env:QT_ARM64_DIR -and (Test-Path $env:QT_ARM64_DIR)) {
    $QtDir = $env:QT_ARM64_DIR
    Write-Host "Qt ARM64 aus Umgebungsvariable: $QtDir"
} else {
    # Dynamisch suchen - unabhaengig von der Qt-Version
    $QtInstallRoot = "C:\Qt"
    $QtDir = Get-ChildItem $QtInstallRoot -Recurse -Directory `
        | Where-Object { $_.Name -like "*arm64*" -and (Test-Path "$($_.FullName)\lib\cmake\Qt6") } `
        | Select-Object -First 1 -ExpandProperty FullName
    if (-not $QtDir) {
        throw "Qt ARM64-Verzeichnis nicht gefunden unter $QtInstallRoot"
    }
    Write-Host "Qt ARM64 dynamisch gefunden: $QtDir"
}

$QtToolchain = "$QtDir\lib\cmake\Qt6\qt.toolchain.cmake"
if (-not (Test-Path $QtToolchain)) {
    throw "qt.toolchain.cmake nicht gefunden: $QtToolchain"
}
Write-Host "Qt Toolchain: $QtToolchain"

# Host-Qt ermitteln (x64, von --autodesktop installiert)
# Liegt eine Ebene hoeher als das ARM64-Verzeichnis
$QtVersionDir = Split-Path $QtDir -Parent
$QtHostDir = Get-ChildItem $QtVersionDir -Directory `
    | Where-Object { $_.Name -like "*msvc*" -and $_.Name -notlike "*arm*" } `
    | Select-Object -First 1 -ExpandProperty FullName
if (-not $QtHostDir) {
    throw "Qt Host (x64) Verzeichnis nicht gefunden unter $QtVersionDir"
}
Write-Host "Qt Host (x64) Verzeichnis: $QtHostDir"

# Strawberry Perl C-Bins aus PATH entfernen (Konflikt mit MSVC)
$env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notlike '*Strawberry\c*' }) -join ';'

New-Item -ItemType Directory -Force C:\build\deps-arm64 | Out-Null

# ── ECM (host-native, KEIN Qt-Toolchain) ────────────────────────────
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git C:\build\ecm-src --depth 1
New-Item -ItemType Directory -Force C:\build\ecm-build | Out-Null
Set-Location C:\build\ecm-build
cmake C:\build\ecm-src `
  -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\ecm `
  -DBUILD_TESTING=OFF `
  -DBUILD_HTML_DOCS=OFF `
  -DBUILD_MAN_DOCS=OFF `
  -DBUILD_QTHELP_DOCS=OFF
cmake --build . --parallel 4
cmake --install .

# ── QtKeychain ─────────────────────────────────────────────
git clone https://github.com/frankosterfeld/qtkeychain.git C:\build\qtkeychain-src --depth 1
New-Item -ItemType Directory -Force C:\build\qtkeychain-build | Out-Null
Set-Location C:\build\qtkeychain-build
cmake C:\build\qtkeychain-src `
  -G Ninja `
  "-DCMAKE_TOOLCHAIN_FILE=$QtToolchain" `
  "-DQT_HOST_PATH=$QtHostDir" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\qtkeychain `
  -DOPENSSL_ROOT_DIR=C:\build\openssl-arm64 `
  -DBUILD_TRANSLATIONS=OFF
cmake --build . --parallel 4
cmake --install . --config Release

# ── KF6Archive ─────────────────────────────────────────────
git clone https://invent.kde.org/frameworks/karchive.git C:\build\karchive-src --depth 1
New-Item -ItemType Directory -Force C:\build\karchive-build | Out-Null
Set-Location C:\build\karchive-build

C:\build\vcpkg\vcpkg.exe install zlib:arm64-windows bzip2:arm64-windows liblzma:arm64-windows zstd:arm64-windows --no-print-usage

cmake C:\build\karchive-src `
  -G Ninja `
  "-DCMAKE_TOOLCHAIN_FILE=$QtToolchain" `
  "-DQT_HOST_PATH=$QtHostDir" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\kf6archive `
  -DBUILD_TESTING=OFF `
  "-DECM_DIR=C:\build\deps-arm64\ecm\share\ECM\cmake" `
  "-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE=C:\build\vcpkg\scripts\buildsystems\vcpkg.cmake" `
  -DVCPKG_TARGET_TRIPLET=arm64-windows
cmake --build . --parallel 4
cmake --install .

# ── KDSingleApplication ─────────────────────────────────────────
git clone https://github.com/KDAB/KDSingleApplication.git C:\build\kdsingleapp-src --depth 1
New-Item -ItemType Directory -Force C:\build\kdsingleapp-build | Out-Null
Set-Location C:\build\kdsingleapp-build
cmake C:\build\kdsingleapp-src `
  -G Ninja `
  "-DCMAKE_TOOLCHAIN_FILE=$QtToolchain" `
  "-DQT_HOST_PATH=$QtHostDir" `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\kdsingleapp `
  -DKDSingleApplication_QT6=ON
cmake --build . --parallel 4
cmake --install . --config Release

Write-Host "All dependencies built successfully."
