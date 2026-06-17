# F2F (File to Folder) — right-click "Copy to folder" / "Move to folder".
# Pure PowerShell + native shell dialogs. No compiled code and no named kernel objects,
# so antivirus has nothing to flag. Windows launches this once per selected item; the
# items are gathered through small temp files, one picker is shown, then all are handled.

$log = Join-Path $env:TEMP 'F2F.log'
function Log($m) { try { Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + "  $m") -Encoding UTF8 } catch { } }

$mode     = if ($args.Count -ge 1) { [string]$args[0] } else { 'Copy' }
$incoming = if ($args.Count -ge 2) { @($args[1..($args.Count - 1)]) | Where-Object { $_ } } else { @() }

$queue = Join-Path $env:TEMP 'F2F_queue'
if (-not (Test-Path -LiteralPath $queue)) { New-Item -ItemType Directory -Path $queue -Force | Out-Null }
$lock = Join-Path $queue ($mode + '.lock')

function Show-Info($msg) { try { (New-Object -ComObject WScript.Shell).Popup($msg, 0, 'F2F', 0x40) | Out-Null } catch { } }

# Native shell folder picker — opens in front, has a "Make New Folder" button (0x40).
function Pick-Folder($prompt) {
    $sel = (New-Object -ComObject Shell.Application).BrowseForFolder(0, $prompt, 0x40)
    if ($null -eq $sel) { return $null }
    $path = $null
    try { $path = $sel.Self.Path } catch { $path = $null }
    if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path)) { return $null }
    return $path
}

# Read + remove all queued item files for this mode; return the unique paths.
function Collect-Items {
    $items = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath $queue -Filter ($mode + '_*.txt') -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            foreach ($line in (Get-Content -LiteralPath $_.FullName -Encoding UTF8)) { if ($line) { $items.Add($line) } }
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        } catch { }
    }
    return @($items | Select-Object -Unique)
}

# Move that also overwrites an existing file OR folder at the destination.
function Move-One($p, $dest) {
    $srcFull = (Resolve-Path -LiteralPath $p).Path
    $target  = Join-Path $dest (Split-Path -Path $p -Leaf)
    if ($srcFull -ieq $target) { return }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop }
    Move-Item -LiteralPath $p -Destination $dest -Force -ErrorAction Stop
}

$lockStream = $null
try {
    # 1) record my files in a uniquely-named queue file
    if ($incoming.Count -gt 0) {
        $mine = Join-Path $queue ($mode + '_' + [guid]::NewGuid().ToString('N') + '.txt')
        Set-Content -LiteralPath $mine -Value $incoming -Encoding UTF8
    }

    # 2) elect a single leader by atomically creating a lock file (no named mutex)
    $amLeader = $false
    for ($i = 0; $i -lt 2 -and -not $amLeader; $i++) {
        try {
            $lockStream = [System.IO.File]::Open($lock, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
            $amLeader = $true
        } catch {
            # lock exists: if it's orphaned (no live leader holding it), delete it and retry
            try { Remove-Item -LiteralPath $lock -Force -ErrorAction Stop } catch { break }
        }
    }
    if (-not $amLeader) { return }   # another launch is leading this click

    try {
        Start-Sleep -Milliseconds 600          # let sibling launches drop their files
        $all = Collect-Items
        if ($all.Count -eq 0) { Log 'leader found no items'; return }

        $dest = Pick-Folder "Choose where to $($mode.ToLower()) your selected item(s). Use 'Make New Folder' to create one."
        if (-not $dest) { Collect-Items | Out-Null; return }

        $totalOk = 0
        $failed  = New-Object System.Collections.Generic.List[string]
        do {
            foreach ($p in $all) {
                try {
                    if (-not (Test-Path -LiteralPath $p)) { throw 'source not found' }
                    if ($mode -eq 'Move') { Move-One $p $dest }
                    else { Copy-Item -LiteralPath $p -Destination $dest -Recurse -Force -ErrorAction Stop }
                    $totalOk++
                } catch { $failed.Add((Split-Path $p -Leaf)); Log ("FAILED $p -> " + $_.Exception.Message) }
            }
            $all = Collect-Items                 # sweep up stragglers, same destination
        } while ($all.Count -gt 0)

        $verb = if ($mode -eq 'Move') { 'Moved' } else { 'Copied' }
        if ($failed.Count -eq 0) { Show-Info "$verb $totalOk item(s) to:`n$dest" }
        else { Show-Info "$verb $totalOk item(s) to:`n$dest`n`nCouldn't handle: $([string]::Join(', ', $failed))" }
    }
    finally {
        if ($lockStream) { try { $lockStream.Close() } catch { } }
        try { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue } catch { }
    }
}
catch {
    Log ('ERROR: ' + $_.Exception.Message + ' @ ' + ($_.ScriptStackTrace -replace "[\r\n]+", ' | '))
    Show-Info ("Something went wrong:`n" + $_.Exception.Message)
}
