# Removes the Inventor's Journal shortcuts and installed app.
# Your entries are kept unless you type YES when asked.
$name = "Inventor's Journal.lnk"
$root = Join-Path $env:LOCALAPPDATA 'InventorsJournal'
Remove-Item -ErrorAction SilentlyContinue `
    (Join-Path ([Environment]::GetFolderPath('Desktop')) $name), `
    (Join-Path ([Environment]::GetFolderPath('Programs')) $name)
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $root 'app')
Write-Host 'Shortcuts and app removed.'
$answer = Read-Host 'Also permanently delete ALL journal entries? Type YES to confirm, or press Enter to keep them'
if ($answer -ceq 'YES') {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $root
    Write-Host 'Entries deleted.'
} else {
    Write-Host "Entries kept in $root\data"
}
