# F2F installer — adds "Copy to folder" and "Move to folder" to the MAIN right-click menu,
# for both files and folders. No admin needed (writes to your own user registry). Safe to re-run.

$script = Join-Path $PSScriptRoot 'F2F.ps1'
$ico    = Join-Path $PSScriptRoot 'F2F.ico'
$ps     = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

if (-not (Test-Path $script)) {
    Write-Host "Can't find F2F.ps1 next to this installer. Keep both files in the same folder." -ForegroundColor Red
    return
}

$hkcu = [Microsoft.Win32.Registry]::CurrentUser

# Clean out older versions and any "Send to" leftovers, so re-running is always tidy.
foreach ($parent in 'Software\Classes\*\shell', 'Software\Classes\Directory\shell') {
    foreach ($old in 'F2FCopy', 'F2FMove', 'QuickMoveCopy', 'QuickMoveMove') {
        try { $hkcu.DeleteSubKeyTree("$parent\$old", $false) | Out-Null } catch { }
    }
}
$sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
foreach ($n in 'Copy to folder', 'Move to folder') {
    $lnk = Join-Path $sendTo "$n.lnk"; if (Test-Path $lnk) { Remove-Item $lnk -Force }
}

function Set-Verb($parent, $key, $label, $mode) {
    $verb = $hkcu.CreateSubKey("$parent\$key")
    $verb.SetValue('', $label)                      # the text shown in the menu
    if (Test-Path $ico) { $verb.SetValue('Icon', $ico) }   # custom icon, if present
    $cmd  = $verb.CreateSubKey('command')
    $line = '"{0}" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -STA -File "{1}" {2} "%1"' -f $ps, $script, $mode
    $cmd.SetValue('', $line)
    $cmd.Close(); $verb.Close()
    Write-Host "Added to right-click menu:  $label"
}

foreach ($parent in 'Software\Classes\*\shell', 'Software\Classes\Directory\shell') {
    Set-Verb $parent 'F2FCopy' 'Copy to folder' 'Copy'
    Set-Verb $parent 'F2FMove' 'Move to folder' 'Move'
}

Write-Host ""
if (Test-Path $ico) { Write-Host "Custom icon applied." -ForegroundColor Green }
else { Write-Host "(No F2F.ico found yet - menu items will use the default icon.)" -ForegroundColor Yellow }
Write-Host "Done! Right-click any file or folder -> 'Copy to folder' / 'Move to folder'." -ForegroundColor Green
