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
    $wixBase = Get-ChildItem "C:\ProgramData\chocolatey\lib\wixtoolset*" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $wixBase) { throw "WiX Toolset nicht gefunden!" }
$wixBin = Join-Path $wixBase "bin"
$heat   = Join-Path $wixBin "heat.exe"
$candle = Join-Path $wixBin "candle.exe"
$light  = Join-Path $wixBin "light.exe"
Write-Host "WiX gefunden: $wixBin"

# --- Icon ermitteln oder aus PNGs generieren ---
$iconDest = "$OutDir\nextcloud.ico"

function New-IcoFromPngs {
    param([string[]]$PngFiles, [string]$OutputPath)
    Add-Type -AssemblyName System.Drawing
    $images = @()
    foreach ($f in $PngFiles) {
        try {
            $img = [System.Drawing.Image]::FromFile($f)
            $images += $img
            Write-Host "  ICO layer: $([System.IO.Path]::GetFileName($f)) ($($img.Width)x$($img.Height))"
        } catch { Write-Warning "  Fehler beim Laden: $f" }
    }
    if ($images.Count -eq 0) { return $false }

    $imageData = @()
    foreach ($img in $images) {
        $ms2 = New-Object System.IO.MemoryStream
        $img.Save($ms2, [System.Drawing.Imaging.ImageFormat]::Png)
        $imageData += ,$ms2.ToArray()
        $ms2.Dispose()
    }

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$images.Count)

    $offset = [uint32](6 + $images.Count * 16)
    for ($i = 0; $i -lt $images.Count; $i++) {
        $w = if ($images[$i].Width  -ge 256) { [byte]0 } else { [byte]$images[$i].Width }
        $h = if ($images[$i].Height -ge 256) { [byte]0 } else { [byte]$images[$i].Height }
        $bw.Write($w); $bw.Write($h)
        $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$imageData[$i].Length)
        $bw.Write($offset)
        $offset += [uint32]$imageData[$i].Length
    }
    foreach ($d in $imageData) { $bw.Write($d) }

    [System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())
    foreach ($img in $images) { $img.Dispose() }
    $bw.Dispose(); $ms.Dispose()
    return $true
}

$iconFound = $false

# 1. Fertiges .ico suchen (falls CMake es doch gebaut hat)
foreach ($src in @(
    "C:\build\nextcloud-src\src\gui\nextcloud.ico",
    "C:\build\nextcloud-src\theme\nextcloud.ico",
    (Get-ChildItem "C:\build\nextcloud-src" -Filter "nextcloud.ico" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName),
    "$BinDir\nextcloud.ico"
)) {
    if ($src -and (Test-Path $src)) {
        Copy-Item $src $iconDest -Force
        Write-Host "Icon (.ico) gefunden: $src"
        $iconFound = $true
        break
    }
}

# 2. Aus PNGs generieren (rsvg-convert legt diese während des CMake-Builds an)
if (-not $iconFound) {
    Write-Host "Kein .ico gefunden – generiere aus PNGs..."
    $pngDirs = @(
        "C:\build\nextcloud-src\theme\colored",
        "C:\build\nextcloud-build\src\gui",
        "C:\build\nextcloud-build"
    )
    $pngFiles = @()
    foreach ($dir in $pngDirs) {
        foreach ($size in @(256, 128, 64, 48, 32, 16)) {
            $candidate = "$dir\${size}-Nextcloud-icon.png"
            if (Test-Path $candidate) { $pngFiles += $candidate }
        }
        if ($pngFiles.Count -ge 2) { break }
    }
    if ($pngFiles.Count -gt 0) {
        $iconFound = New-IcoFromPngs -PngFiles $pngFiles -OutputPath $iconDest
        if ($iconFound) { Write-Host "Icon aus $($pngFiles.Count) PNGs generiert: $iconDest" }
    }
}

if (-not $iconFound) { Write-Warning "Kein Icon gefunden – MSI-Icon wird weggelassen" }

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
# KEIN -ke: keine leeren Verzeichnis-Komponenten (verursachen GUID-Probleme beim Deinstall)
$filesWxs = "$OutDir\files.wxs"
Write-Host "Harveste $BinDir ..."
& $heat dir $BinDir `
    -cg MainFiles `
    -dr INSTALLDIR `
    -ag `
    -sfrag `
    -srd `
    -sreg `
    -var "var.SourceDir" `
    -out $filesWxs
if ($LASTEXITCODE -ne 0) { throw "heat.exe fehlgeschlagen (Exit $LASTEXITCODE)" }

# Post-processing: Directory-keyed Components brauchen explizite GUIDs
[xml]$xml = [System.IO.File]::ReadAllText($filesWxs)
$nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$nsMgr.AddNamespace("wix", "http://schemas.microsoft.com/wix/2006/wi")
$dirComponents = $xml.SelectNodes("//wix:Component[wix:CreateFolder]", $nsMgr)
foreach ($node in $dirComponents) {
    if ($node.GetAttribute("Guid") -eq "*") {
        $node.SetAttribute("Guid", "{$([System.Guid]::NewGuid().ToString().ToUpper())}")
    }
}
$xml.Save($filesWxs)
Write-Host "Directory-keyed Components gefixt: $($dirComponents.Count)"

# --- Product.wxs generieren ---
$productWxs = "$OutDir\Product.wxs"

$iconBlock = if ($iconFound) { @"
    <Icon Id="NextcloudIcon.ico" SourceFile="$iconDest" />
    <Property Id="ARPPRODUCTICON" Value="NextcloudIcon.ico" />
    <Property Id="ARPHELPLINK" Value="https://nextcloud.com/install/" />
"@ } else { "" }

$productContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi"
     xmlns:util="http://schemas.microsoft.com/wix/UtilExtension">
  <Product
    Id="*"
    Name="Nextcloud Desktop ARM64"
    Version="$msiVersion"
    Manufacturer="Nextcloud GmbH (inoffizieller ARM64-Build)"
    Language="1033"
    UpgradeCode="{$upgradeCode}">

    <Package
      Description="Nextcloud Desktop Client fuer Windows ARM64"
      Manufacturer="Nextcloud GmbH (inoffizieller ARM64-Build)"
      InstallerVersion="500"
      Platform="arm64"
      Compressed="yes" />

    <!-- Aeltere Versionen automatisch ersetzen, neuere blockieren -->
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
      <ComponentRef Id="C_CleanupInstallDir" />
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

      <!-- Sauberer Cleanup: entfernt INSTALLDIR rekursiv beim Deinstallieren -->
      <!-- util:RemoveFolderEx loescht auch Dateien die nach der Installation hinzugekommen sind -->
      <Component Id="C_CleanupInstallDir" Guid="*">
        <RegistryValue Root="HKCU"
          Key="Software\Nextcloud\Desktop-ARM64"
          Name="InstallDir"
          Type="string"
          Value="[INSTALLDIR]"
          KeyPath="yes" />
        <util:RemoveFolderEx On="uninstall" Property="INSTALLDIR" />
      </Component>
    </DirectoryRef>

    <!-- COM-Registrierung der Shell-Extensions (nötig für VFS-Sync und Explorer-Integration) -->
    <CustomAction Id="CA_RegisterCfApi"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /s &quot;[INSTALLDIR]CfApiShellExtensions.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />
    <CustomAction Id="CA_RegisterContextMenu"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /s &quot;[INSTALLDIR]NCContextMenu.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />
    <CustomAction Id="CA_RegisterOverlays"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /s &quot;[INSTALLDIR]NCOverlays.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />

    <CustomAction Id="CA_UnregisterCfApi"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /u /s &quot;[INSTALLDIR]CfApiShellExtensions.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />
    <CustomAction Id="CA_UnregisterContextMenu"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /u /s &quot;[INSTALLDIR]NCContextMenu.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />
    <CustomAction Id="CA_UnregisterOverlays"
      Directory="INSTALLDIR"
      ExeCommand="[System64Folder]regsvr32.exe /u /s &quot;[INSTALLDIR]NCOverlays.dll&quot;"
      Execute="deferred" Impersonate="no" Return="ignore" />

    <InstallExecuteSequence>
      <!-- Bei Installation: nach dem Kopieren der Dateien registrieren -->
      <Custom Action="CA_RegisterCfApi"        After="InstallFiles">NOT Installed</Custom>
      <Custom Action="CA_RegisterContextMenu"  After="CA_RegisterCfApi">NOT Installed</Custom>
      <Custom Action="CA_RegisterOverlays"     After="CA_RegisterContextMenu">NOT Installed</Custom>
      <!-- Bei Deinstallation: vor dem Löschen der Dateien deregistrieren -->
      <Custom Action="CA_UnregisterCfApi"       Before="RemoveFiles">Installed AND REMOVE~="ALL"</Custom>
      <Custom Action="CA_UnregisterContextMenu" Before="RemoveFiles">Installed AND REMOVE~="ALL"</Custom>
      <Custom Action="CA_UnregisterOverlays"    Before="RemoveFiles">Installed AND REMOVE~="ALL"</Custom>
    </InstallExecuteSequence>

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
    -ext WixUtilExtension `
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
    -ext WixUtilExtension `
    -cultures:en-us `
    -out $msiOut `
    "$OutDir\Product.wixobj" `
    "$OutDir\files.wixobj"
if ($LASTEXITCODE -ne 0) { throw "light.exe fehlgeschlagen (Exit $LASTEXITCODE)" }

$mb = [math]::Round((Get-Item $msiOut).Length / 1MB, 1)
Write-Host "MSI erstellt: $msiOut ($mb MB)"

Copy-Item $msiOut "$env:GITHUB_WORKSPACE\" -Force
Write-Host "MSI kopiert nach: $env:GITHUB_WORKSPACE"
