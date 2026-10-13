<#
  Installs Inventor's Journal for the current Windows user.

  - Copies the app to %LOCALAPPDATA%\InventorsJournal\app
  - Creates "Inventor's Journal" shortcuts (with the journal icon) on the
    Desktop and in the Start menu.
  - The shortcut opens the journal in its own window using Microsoft Edge
    (built into Windows 10/11) in "app mode", so it looks like a normal
    program rather than a browser tab.
  - The shortcut and the journal window share their own taskbar identity,
    so pinning either one to the taskbar keeps the journal icon.

  Your entries are kept in %LOCALAPPDATA%\InventorsJournal\data and are NOT
  touched when you re-run this installer to update the app.
#>
$ErrorActionPreference = 'Stop'

$source      = Join-Path $PSScriptRoot 'app'
$launcherSrc = Join-Path $PSScriptRoot 'launcher'
$root        = Join-Path $env:LOCALAPPDATA 'InventorsJournal'
$appDir      = Join-Path $root 'app'
$launcherDir = Join-Path $root 'launcher'
$dataDir     = Join-Path $root 'data'
$name        = "Inventor's Journal"
$appId       = 'InventorsJournal.Journal'   # taskbar identity shared by shortcut and window

if (-not (Test-Path (Join-Path $source 'index.html')) -or -not (Test-Path (Join-Path $launcherSrc 'Launch-Journal.ps1'))) {
    throw "Could not find the 'app' and 'launcher' folders next to this script ($PSScriptRoot)."
}

New-Item -ItemType Directory -Force -Path $appDir, $launcherDir, $dataDir | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $appDir -Recurse -Force
Copy-Item -Path (Join-Path $launcherSrc '*') -Destination $launcherDir -Recurse -Force

$index   = Join-Path $appDir 'index.html'
$icon    = Join-Path $appDir 'icon.ico'
$fileUrl = ([System.Uri]$index).AbsoluteUri

# Find a Chromium browser that supports --app (Edge ships with Windows).
$candidates = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
) | Where-Object { $_ -and (Test-Path $_) }
$browser = $candidates | Select-Object -First 1

$launcherVbs = Join-Path $launcherDir 'Launch-Journal.vbs'
$wscript     = Join-Path $env:WINDIR 'System32\wscript.exe'
$launchCmd   = "`"$wscript`" `"$launcherVbs`""

# Settings for the launcher. A dedicated browser profile (--user-data-dir)
# keeps the journal's saved entries in one predictable place, separate from
# your everyday browsing.
[ordered]@{
    Browser         = $browser
    Arguments       = "--app=`"$fileUrl`" --user-data-dir=`"$dataDir`" --no-first-run --window-size=1200,850"
    Index           = $index
    Title           = $name
    AppId           = $appId
    DisplayName     = $name
    IconResource    = "$icon,0"
    RelaunchCommand = $launchCmd
} | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $launcherDir 'launch.json')

Add-Type -TypeDefinition (Get-Content -Raw (Join-Path $launcherDir 'Taskbar.cs'))

$shell = New-Object -ComObject WScript.Shell
$targets = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"),
    (Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk")
)
foreach ($lnkPath in $targets) {
    $lnk = $shell.CreateShortcut($lnkPath)
    $lnk.TargetPath       = $wscript
    $lnk.Arguments        = "`"$launcherVbs`""
    $lnk.WorkingDirectory = $appDir
    $lnk.IconLocation     = "$icon,0"
    $lnk.Description      = 'Open your Inventor''s Journal'
    $lnk.Save()
    [InventorsJournal.Taskbar]::SetShortcutAppId($lnkPath, $appId)
    Write-Host "Created shortcut: $lnkPath"
}

if (-not $browser) {
    Write-Warning 'Microsoft Edge or Chrome was not found; the journal will open in your default browser.'
}
Write-Host ''
Write-Host "Done! Double-click '$name' on your desktop to start writing." -ForegroundColor Green
Write-Host 'Tip: right-click the shortcut and choose "Pin to taskbar" (Windows 10) or "Show more options > Pin to taskbar" (Windows 11).'
Write-Host 'If you pinned the journal before and it shows the Edge icon, unpin that one first (right-click it > Unpin from taskbar).'
