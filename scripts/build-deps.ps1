Write-Host "Building dependencies for ARM64..."

$env:PATH = "C:\Qt\6.11.1\msvc2022_arm64\bin;C:\Qt\Tools\CMake\bin;C:\Qt\Tools\Ninja;" + $env:PATH
$env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notlike '*Strawberry*' }) -join ';'
$env:LIB = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\arm64;" +
           "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\ucrt\arm64;" +
           "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.51.36231\lib\arm64"
$env:INCLUDE = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.51.36231\include;" +
               "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\ucrt;" +
               "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\um;" +
               "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\shared;" +
               "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\winrt;" +
               "C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0\cppwinrt"

mkdir -Force C:\build\deps-arm64

# ECM
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git C:\build\ecm-src
mkdir C:\build\ecm-build; Set-Location C:\build\ecm-build
cmake C:\build\ecm-src -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\ecm -DBUILD_TESTING=OFF
cmake --build . --parallel
cmake --install .

# QtKeychain
git clone https://github.com/frankosterfeld/qtkeychain.git C:\build\qtkeychain-src
mkdir C:\build\qtkeychain-build; Set-Location C:\build\qtkeychain-build
& "C:\Qt\6.11.1\msvc2022_arm64\bin\qt-cmake.bat" C:\build\qtkeychain-src -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\qtkeychain -DOPENSSL_ROOT_DIR=C:\build\openssl-arm64
cmake --build . --parallel
cmake --install . --config Release --prefix C:\build\deps-arm64\qtkeychain

# KF6Archive
git clone https://invent.kde.org/frameworks/karchive.git C:\build\karchive-src
mkdir C:\build\karchive-build; Set-Location C:\build\karchive-build

# vcpkg for sqlite3 and compression libs
git clone https://github.com/microsoft/vcpkg.git C:\build\vcpkg
C:\build\vcpkg\bootstrap-vcpkg.bat
C:\build\vcpkg\vcpkg.exe install sqlite3:arm64-windows zlib:arm64-windows bzip2:arm64-windows liblzma:arm64-windows zstd:arm64-windows

& "C:\Qt\6.11.1\msvc2022_arm64\bin\qt-cmake.bat" C:\build\karchive-src -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\kf6archive -DBUILD_TESTING=OFF "-DECM_DIR=C:\build\deps-arm64\ecm\share\ECM\cmake" "-DCMAKE_TOOLCHAIN_FILE=C:\build\vcpkg\scripts\buildsystems\vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=arm64-windows -DOPENSSL_ROOT_DIR=C:\build\openssl-arm64
cmake --build . --parallel
cmake --install . --prefix C:\build\deps-arm64\kf6archive

# KDSingleApplication
git clone https://github.com/KDAB/KDSingleApplication.git C:\build\kdsingleapp-src
mkdir C:\build\kdsingleapp-build; Set-Location C:\build\kdsingleapp-build
& "C:\Qt\6.11.1\msvc2022_arm64\bin\qt-cmake.bat" C:\build\kdsingleapp-src -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=C:\build\deps-arm64\kdsingleapp -DKDSingleApplication_QT6=ON
cmake --build . --parallel
cmake --install . --config Release --prefix C:\build\deps-arm64\kdsingleapp

Write-Host "All dependencies built successfully."
