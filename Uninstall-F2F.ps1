# Removes the F2F "Copy to folder" / "Move to folder" right-click menu entries.

$hkcu = [Microsoft.Win32.Registry]::CurrentUser
foreach ($parent in 'Software\Classes\*\shell', 'Software\Classes\Directory\shell') {
    foreach ($key in 'F2FCopy', 'F2FMove', 'QuickMoveCopy', 'QuickMoveMove') {
        try { $hkcu.DeleteSubKeyTree("$parent\$key", $false) | Out-Null } catch { }
    }
}

# Also clean up the older "Send to" shortcuts, in case they're still around.
$sendTo = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
foreach ($n in 'Copy to folder', 'Move to folder') {
    $lnk = Join-Path $sendTo "$n.lnk"; if (Test-Path $lnk) { Remove-Item $lnk -Force }
}

Write-Host "F2F right-click entries removed." -ForegroundColor Green
