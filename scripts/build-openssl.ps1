param([string]$Version = "openssl-3.3")

Write-Host "Building OpenSSL $Version for ARM64..."

git clone https://github.com/openssl/openssl.git -b $Version C:\build\openssl-src
Set-Location C:\build\openssl-src

$env:PATH = ($env:PATH -split ';' | Where-Object { $_ -notlike '*Strawberry*' }) -join ';'
$env:PATH = "C:\Strawberry\perl\bin;" + $env:PATH

perl Configure VC-WIN64-ARM --prefix=C:\build\openssl-arm64
nmake install_dev

Write-Host "OpenSSL build complete."
