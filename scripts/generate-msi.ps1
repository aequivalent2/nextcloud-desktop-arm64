# generate-msi.ps1
# Erstellt ein MSI-Installationspaket mit WiX Toolset v3
# Erfordert: WiX Toolset v3 (heat.exe, candle.exe, light.exe)

$version  = $env:VERSION
$verClean = $version -replace '^v', ''
$BinDir   = "C:\build\nextcloud-arm64\bin"
$OutDir   = "C:\build"

# MSI-Version: maximal 4 numerische Teile (0-65535 je)
$verParts = ($verClean -split '[-+]')[0] -split '\.'
while ($verParts.Count -lt 4) { $verParts += '0' }
$msiVersion = ($verParts[0..3] | ForEach-Object { [math]::Min([int]$_, 65535) }) -join '.'
Write-Host "MSI-Version: $msiVersion (aus $verClean)"

# UpgradeCode: MUSS konstant bleiben, damit Upgrade/Deinstall korrekt funktioniert
$upgradeCode = "3FA7C2B1-8D4E-4A5F-BC69-1A2B3C4D5E6F"

# --- WiX-Pfad ermitteln ---
$wixBase = Get-ChildItem "C:\Program Files (x86)\WiX Toolset*" -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $wixBase) {
    # Chocolatey legt WiX manchmal hier ab
    $wixBase = Get-ChildItem "C:\ProgramData\chocolatey\lib\wixtoolset*" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $wixBase) { throw "WiX Toolset nicht gefunden! Bitte 'choco install wixtoolset' pruefen." }
$wixBin = Join-Path $wixBase "bin"
$heat   = Join-Path $wixBin "heat.exe"
$candle = Join-Path $wixBin "candle.exe"
$light  = Join-Path $wixBin "light.exe"
Write-Host "WiX gefunden: $wixBin"

# --- Icon ermitteln (mehrere Fallbacks) ---
$iconDest = "$OutDir\nextcloud.ico"
$iconSources = @(
    "C:\build\nextcloud-src\src\gui\nextcloud.ico",
    "C:\build\nextcloud-src\theme\nextcloud.ico",
    (Get-ChildItem "C:\build\nextcloud-src" -Filter "nextcloud.ico" -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName),
    "$BinDir\nextcloud.ico"
)
$iconFound = $false
foreach ($src in $iconSources) {
    if ($src -and (Test-Path $src)) {
        Copy-Item $src $iconDest -Force
        Write-Host "Icon gefunden: $src"
        $iconFound = $true
        break
    }
}
if (-not $iconFound) {
    Write-Warning "Kein .ico gefunden – MSI-Icon wird weggelassen"
}

# Stelle sicher, dass Icon auch im BinDir liegt (fuer Add/Remove Programs DisplayIcon)
if ($iconFound -and -not (Test-Path "$BinDir\nextcloud.ico")) {
    Copy-Item $iconDest "$BinDir\nextcloud.ico" -Force
}

# --- Lizenz als RTF ---
$licRtf = "$OutDir\license.rtf"
$licSrc = "C:\build\nextcloud-src\COPYING"
if (Test-Path $licSrc) {
    $licText = (Get-Content $licSrc -Raw) -replace '\\', '\\\\' -replace '\r?\n', '\par '
    Set-Content $licRtf "{\rtf1\ansi\deff0 $licText}" -Encoding ASCII
} else {
    Set-Content $licRtf '{\rtf1\ansi Nextcloud Desktop Client - GPL v2 or later}' -Encoding ASCII
}

# --- heat: Verzeichnis ernten ---
$filesWxs = "$OutDir\files.wxs"
Write-Host "Harveste $BinDir ..."
& $heat dir $BinDir `
    -cg MainFiles `
    -dr INSTALLDIR `
    -ke `
    -sfrag `
    -srd `
    -sreg `
    -var "var.SourceDir" `
    -out $filesWxs
if ($LASTEXITCODE -ne 0) { throw "heat.exe fehlgeschlagen (Exit $LASTEXITCODE)" }

# --- Product.wxs generieren ---
$productWxs = "$OutDir\Product.wxs"

$iconBlock = if ($iconFound) { @"
    <Icon Id="NextcloudIcon.ico" SourceFile="$iconDest" />
    <Property Id="ARPPRODUCTICON" Value="NextcloudIcon.ico" />
    <Property Id="ARPHELPLINK" Value="https://nextcloud.com/install/" />
"@ } else { "" }

$productContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product
    Id="*"
    Name="Nextcloud Desktop ARM64"
    Version="$msiVersion"
    Manufacturer="Nextcloud GmbH (inoffizieller ARM64-Build)"
    Language="1031"
    UpgradeCode="{$upgradeCode}">

    <Package
      Description="Nextcloud Desktop Client fuer Windows ARM64"
      Manufacturer="Nextcloud GmbH (inoffizieller ARM64-Build)"
      InstallerVersion="500"
      Platform="arm64"
      Compressed="yes" />

    <!-- Aeltere Versionen automatisch ersetzen -->
    <MajorUpgrade
      DowngradeErrorMessage="Eine neuere Version von Nextcloud Desktop ist bereits installiert."
      Schedule="afterInstallInitialize" />

    <MediaTemplate EmbedCab="yes" />

$iconBlock

    <!-- Feature-Baum -->
    <Feature Id="Main" Title="Nextcloud Desktop" Level="1">
      <ComponentGroupRef Id="MainFiles" />
      <ComponentRef Id="C_StartMenuShortcut" />
      <ComponentRef Id="C_DesktopShortcut" />
      <ComponentRef Id="C_Autostart" />
    </Feature>

    <!-- Verzeichnisstruktur -->
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFiles64Folder">
        <Directory Id="INSTALLDIR" Name="Nextcloud" />
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="AppProgramsFolder" Name="Nextcloud" />
      </Directory>
      <Directory Id="DesktopFolder" />
    </Directory>

    <!-- Startmenue-Shortcuts -->
    <DirectoryRef Id="AppProgramsFolder">
      <Component Id="C_StartMenuShortcut" Guid="*">
        <Shortcut Id="SC_StartMenu"
          Name="Nextcloud"
          Description="Nextcloud Desktop Client"
          Target="[INSTALLDIR]nextcloud.exe"
          WorkingDirectory="INSTALLDIR"$(if ($iconFound) { ' Icon="NextcloudIcon.ico"' } else { '' }) />
        <Shortcut Id="SC_Uninstall"
          Name="Nextcloud deinstallieren"
          Target="[System64Folder]msiexec.exe"
          Arguments="/x [ProductCode]" />
        <RemoveFolder Id="RF_AppProgramsFolder" Directory="AppProgramsFolder" On="uninstall" />
        <RegistryValue Root="HKCU"
          Key="Software\Nextcloud\Desktop-ARM64"
          Name="StartMenuInstalled"
          Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <!-- Desktop-Shortcut -->
    <DirectoryRef Id="DesktopFolder">
      <Component Id="C_DesktopShortcut" Guid="*">
        <Shortcut Id="SC_Desktop"
          Name="Nextcloud"
          Description="Nextcloud Desktop Client"
          Target="[INSTALLDIR]nextcloud.exe"
          WorkingDirectory="INSTALLDIR"$(if ($iconFound) { ' Icon="NextcloudIcon.ico"' } else { '' }) />
        <RegistryValue Root="HKCU"
          Key="Software\Nextcloud\Desktop-ARM64"
          Name="DesktopInstalled"
          Type="integer" Value="1" KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <!-- Autostart-Registryeintrag -->
    <DirectoryRef Id="INSTALLDIR">
      <Component Id="C_Autostart" Guid="*">
        <RegistryValue Root="HKCU"
          Key="Software\Microsoft\Windows\CurrentVersion\Run"
          Name="Nextcloud"
          Type="string"
          Value="[INSTALLDIR]nextcloud.exe"
          KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <!-- UI: Minimal (nur Lizenz + Installieren) -->
    <WixVariable Id="WixUILicenseRtf" Value="$licRtf" />
    <UIRef Id="WixUI_Minimal" />

  </Product>
</Wix>
"@

Set-Content $productWxs $productContent -Encoding UTF8
Write-Host "Product.wxs geschrieben: $productWxs"

# --- candle: kompilieren ---
Write-Host "Kompiliere WXS..."
& $candle `
    -arch arm64 `
    -ext WixUIExtension `
    "-dSourceDir=$BinDir" `
    $productWxs `
    $filesWxs `
    -out "$OutDir\"
if ($LASTEXITCODE -ne 0) { throw "candle.exe fehlgeschlagen (Exit $LASTEXITCODE)" }

# --- light: linken → MSI ---
$msiOut = "$OutDir\Nextcloud-${version}-arm64.msi"
Write-Host "Linke zu MSI: $msiOut"
& $light `
    -ext WixUIExtension `
    -cultures:de-de `
    -loc "$wixBin\..\lib\WixUI_de-de.wxl" `
    -out $msiOut `
    "$OutDir\Product.wixobj" `
    "$OutDir\files.wixobj"
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Erster light-Aufruf (de-de) fehlgeschlagen, versuche en-us..."
    & $light `
        -ext WixUIExtension `
        -cultures:en-us `
        -out $msiOut `
        "$OutDir\Product.wixobj" `
        "$OutDir\files.wixobj"
    if ($LASTEXITCODE -ne 0) { throw "light.exe fehlgeschlagen (Exit $LASTEXITCODE)" }
}

$mb = [math]::Round((Get-Item $msiOut).Length / 1MB, 1)
Write-Host "MSI erstellt: $msiOut ($mb MB)"

# In GitHub Workspace kopieren (fuer Artifact-Upload)
Copy-Item $msiOut "$env:GITHUB_WORKSPACE\" -Force
Write-Host "MSI kopiert nach: $env:GITHUB_WORKSPACE"
