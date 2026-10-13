# Opens Inventor's Journal, then gives its window the journal's own taskbar
# identity so that pinning it keeps the journal icon (see Taskbar.cs).
# Settings are written to launch.json by Install-Journal.ps1.
$ErrorActionPreference = 'Stop'
$cfg = Get-Content -Raw (Join-Path $PSScriptRoot 'launch.json') | ConvertFrom-Json

if (-not $cfg.Browser) {
    Start-Process $cfg.Index   # no Edge/Chrome: default browser, nothing to tag
    return
}
Start-Process -FilePath $cfg.Browser -ArgumentList $cfg.Arguments

try {
    Add-Type -TypeDefinition (Get-Content -Raw (Join-Path $PSScriptRoot 'Taskbar.cs'))
    # Wait for the window to appear (up to 30 s), then keep watching briefly
    # in case Edge opens it a moment later than the title first shows.
    $deadline = (Get-Date).AddSeconds(30)
    $stopAt = $null
    while ((Get-Date) -lt $deadline -and (-not $stopAt -or (Get-Date) -lt $stopAt)) {
        $n = [InventorsJournal.Taskbar]::TagWindows($cfg.Title, $cfg.AppId, $cfg.RelaunchCommand, $cfg.DisplayName, $cfg.IconResource)
        if ($n -gt 0 -and -not $stopAt) { $stopAt = (Get-Date).AddSeconds(3) }
        Start-Sleep -Milliseconds 250
    }
} catch {
    # The journal is already open; only the taskbar icon is affected.
}
