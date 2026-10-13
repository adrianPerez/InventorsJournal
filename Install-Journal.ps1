<#
  Installs Inventor's Journal for the current Windows user.

  - Copies the app to %LOCALAPPDATA%\InventorsJournal\app
  - Creates "Inventor's Journal" shortcuts (with the journal icon) on the
    Desktop and in the Start menu.
  - The shortcut opens the journal in its own window using Microsoft Edge
    (built into Windows 10/11) in "app mode", so it looks like a normal
    program rather than a browser tab.

  Your entries are kept in %LOCALAPPDATA%\InventorsJournal\data and are NOT
  touched when you re-run this installer to update the app.
#>
$ErrorActionPreference = 'Stop'

$source  = Join-Path $PSScriptRoot 'app'
$root    = Join-Path $env:LOCALAPPDATA 'InventorsJournal'
$appDir  = Join-Path $root 'app'
$dataDir = Join-Path $root 'data'
$name    = "Inventor's Journal"

if (-not (Test-Path (Join-Path $source 'index.html'))) {
    throw "Could not find the 'app' folder next to this script ($source)."
}

New-Item -ItemType Directory -Force -Path $appDir, $dataDir | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $appDir -Recurse -Force

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

$shell = New-Object -ComObject WScript.Shell
$targets = @(
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"),
    (Join-Path ([Environment]::GetFolderPath('Programs')) "$name.lnk")
)
foreach ($lnkPath in $targets) {
    $lnk = $shell.CreateShortcut($lnkPath)
    if ($browser) {
        $lnk.TargetPath = $browser
        # A dedicated profile keeps the journal's saved entries in one
        # predictable place, separate from your everyday browsing.
        $lnk.Arguments  = "--app=`"$fileUrl`" --user-data-dir=`"$dataDir`" --no-first-run --window-size=1200,850"
    } else {
        $lnk.TargetPath = $index   # fall back to the default browser
    }
    $lnk.WorkingDirectory = $appDir
    $lnk.IconLocation     = "$icon,0"
    $lnk.Description      = 'Open your Inventor''s Journal'
    $lnk.Save()
    Write-Host "Created shortcut: $lnkPath"
}

if (-not $browser) {
    Write-Warning 'Microsoft Edge or Chrome was not found; the journal will open in your default browser.'
}
Write-Host ''
Write-Host "Done! Double-click '$name' on your desktop to start writing." -ForegroundColor Green
Write-Host 'Tip: right-click the shortcut and choose "Pin to taskbar" (Windows 10) or "Show more options > Pin to taskbar" (Windows 11).'
