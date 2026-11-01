# Compile DeviceSwitch.ps1 -> DeviceSwitch.exe
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module ps2exe
Invoke-ps2exe `
    -inputFile  (Join-Path $dir 'DeviceSwitch.ps1') `
    -outputFile (Join-Path $dir 'DeviceSwitch.exe') `
    -iconFile   (Join-Path $dir 'icon.ico') `
    -noConsole -requireAdmin `
    -title 'DeviceSwitch' -description 'Windows device one-click toggle tool' `
    -company 'DeviceSwitch' -product 'DeviceSwitch' `
    -version '1.0.0.0' -copyright '2026'
if (Test-Path (Join-Path $dir 'DeviceSwitch.exe')) {
    $f = Get-Item (Join-Path $dir 'DeviceSwitch.exe')
    "BUILD OK: $($f.FullName) ($([Math]::Round($f.Length/1KB)) KB)"
} else {
    'BUILD FAILED'
}
