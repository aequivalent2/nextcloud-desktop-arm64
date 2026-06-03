# generate-nsis.ps1
# Generates the NSIS installer script for Nextcloud ARM64
# Called from build.yml to avoid YAML parsing issues with PowerShell here-strings

$version    = $env:VERSION
$verClean   = $version -replace '^v',''
$BinDir     = "C:\build\nextcloud-arm64\bin"
$ScriptPath = "C:\build\nextcloud-installer.nsi"

$fileLines = (Get-ChildItem $BinDir -File | ForEach-Object {
    '  File "' + $_.FullName + '"'
}) -join "`r`n"

$subdirSections = ""
Get-ChildItem $BinDir -Directory | ForEach-Object {
    $subName  = $_.Name
    $subFiles = Get-ChildItem $_.FullName -File -Recurse
    if ($subFiles.Count -gt 0) {
        $subdirSections += '  SetOutPath "$INSTDIR\' + $subName + '"' + "`r`n"
        $subFiles | ForEach-Object {
            $subdirSections += '  File "' + $_.FullName + '"' + "`r`n"
        }
    }
}

$deleteLines = (Get-ChildItem $BinDir -File | ForEach-Object {
    '  Delete "$INSTDIR\' + $_.Name + '"'
}) -join "`r`n"

$nsi = @"
Unicode True
!define APPNAME    "Nextcloud"
!define APPVERSION "$verClean"
!define APPTAG     "$version"
!define APPEXE     "nextcloud.exe"
!define UNREG      "Software\Microsoft\Windows\CurrentVersion\Uninstall\NextcloudDesktopARM64"
!define INREG      "Software\Nextcloud\NextcloudDesktop-ARM64"

Name      "`${APPNAME} `${APPVERSION} ARM64"
OutFile   "C:\build\Nextcloud-`${APPTAG}-arm64-Setup.exe"
InstallDir "`$PROGRAMFILES64\Nextcloud"
InstallDirRegKey HKCU "`${INREG}" "InstallPath"
RequestExecutionLevel admin
SetCompressor /SOLID lzma

!include "MUI2.nsh"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "English"

Section "Nextcloud" SecMain
  SectionIn RO
  SetOutPath "`$INSTDIR"
$fileLines
$subdirSections
  WriteRegStr HKCU "`${INREG}" "InstallPath" "`$INSTDIR"
  WriteRegStr   HKLM "`${UNREG}" "DisplayName"     "`${APPNAME} `${APPVERSION} ARM64"
  WriteRegStr   HKLM "`${UNREG}" "DisplayVersion"  "`${APPVERSION}"
  WriteRegStr   HKLM "`${UNREG}" "InstallLocation" "`$INSTDIR"
  WriteRegStr   HKLM "`${UNREG}" "DisplayIcon"     "`$INSTDIR\`${APPEXE}"
  WriteRegStr   HKLM "`${UNREG}" "UninstallString" "`$INSTDIR\uninstall.exe"
  WriteRegDWORD HKLM "`${UNREG}" "NoModify" 1
  WriteRegDWORD HKLM "`${UNREG}" "NoRepair"  1
  WriteUninstaller "`$INSTDIR\uninstall.exe"
SectionEnd

Section "Startmenue" SecStartMenu
  CreateDirectory "`$SMPROGRAMS\Nextcloud"
  CreateShortcut  "`$SMPROGRAMS\Nextcloud\Nextcloud.lnk" "`$INSTDIR\`${APPEXE}"
  CreateShortcut  "`$SMPROGRAMS\Nextcloud\Deinstallieren.lnk" "`$INSTDIR\uninstall.exe"
SectionEnd

Section "Desktop" SecDesktop
  CreateShortcut "`$DESKTOP\Nextcloud.lnk" "`$INSTDIR\`${APPEXE}"
SectionEnd

Section "Autostart" SecAutostart
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Nextcloud" "`"`$INSTDIR\`${APPEXE}`""
SectionEnd

Section "Uninstall"
$deleteLines
  RMDir /r "`$INSTDIR\bearer"
  RMDir /r "`$INSTDIR\iconengines"
  RMDir /r "`$INSTDIR\imageformats"
  RMDir /r "`$INSTDIR\networkinformation"
  RMDir /r "`$INSTDIR\platforms"
  RMDir /r "`$INSTDIR\platformthemes"
  RMDir /r "`$INSTDIR\position"
  RMDir /r "`$INSTDIR\printsupport"
  RMDir /r "`$INSTDIR\qml"
  RMDir /r "`$INSTDIR\styles"
  RMDir /r "`$INSTDIR\tls"
  Delete "`$INSTDIR\uninstall.exe"
  RMDir  "`$INSTDIR"
  Delete "`$SMPROGRAMS\Nextcloud\Nextcloud.lnk"
  Delete "`$SMPROGRAMS\Nextcloud\Deinstallieren.lnk"
  RMDir  "`$SMPROGRAMS\Nextcloud"
  Delete "`$DESKTOP\Nextcloud.lnk"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Nextcloud"
  DeleteRegKey HKCU "`${INREG}"
  DeleteRegKey HKLM "`${UNREG}"
SectionEnd
"@

Set-Content -Path $ScriptPath -Value $nsi -Encoding UTF8
Write-Host "NSIS-Skript erstellt: $ScriptPath ($(($nsi -split "`n").Count) Zeilen)"
