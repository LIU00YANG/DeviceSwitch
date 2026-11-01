# Build DeviceSwitch-Setup.exe (embeds DeviceSwitch.exe + Uninstall.exe)
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module ps2exe
$utf8bom = New-Object System.Text.UTF8Encoding($true)

# 1. Uninstall.ps1 -> Uninstall.exe (ensure UTF-8 BOM for Chinese text)
$unPs1 = Join-Path $dir 'Uninstall.ps1'
$unTxt = [System.IO.File]::ReadAllText($unPs1, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($unPs1, $unTxt, $utf8bom)
Invoke-ps2exe -inputFile $unPs1 -outputFile (Join-Path $dir 'Uninstall.exe') `
    -iconFile (Join-Path $dir 'icon.ico') -noConsole -requireAdmin `
    -title 'DeviceSwitch Uninstall' -product 'DeviceSwitch' -version '1.0.0.0' -copyright '2026'
if (-not (Test-Path (Join-Path $dir 'Uninstall.exe'))) { 'UNINSTALL BUILD FAILED'; exit 1 }
'Uninstall.exe OK'

# 2. Read payloads as base64
$appB64  = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $dir 'DeviceSwitch.exe')))
$uninB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Join-Path $dir 'Uninstall.exe')))

# 3. Generate Installer-Generated.ps1 from template
$tpl = [System.IO.File]::ReadAllText((Join-Path $dir 'Installer-Template.ps1'), [System.Text.Encoding]::UTF8)
$gen = $tpl.Replace('__APP_B64__', $appB64).Replace('__UNINS_B64__', $uninB64)
if ($gen -match '__APP_B64__|__UNINS_B64__') { 'PLACEHOLDER REPLACE FAILED'; exit 1 }
$genPath = Join-Path $dir 'Installer-Generated.ps1'
[System.IO.File]::WriteAllText($genPath, $gen, $utf8bom)
'Installer-Generated.ps1 OK'

# 4. Compile setup
Invoke-ps2exe -inputFile $genPath -outputFile (Join-Path $dir 'DeviceSwitch-Setup.exe') `
    -iconFile (Join-Path $dir 'icon.ico') -noConsole -requireAdmin `
    -title 'DeviceSwitch Setup' -description 'DeviceSwitch installer' `
    -product 'DeviceSwitch' -version '1.0.0.0' -copyright '2026'
if (Test-Path (Join-Path $dir 'DeviceSwitch-Setup.exe')) {
    $f = Get-Item (Join-Path $dir 'DeviceSwitch-Setup.exe')
    "SETUP BUILD OK: $($f.FullName) ($([Math]::Round($f.Length/1KB)) KB)"
} else {
    'SETUP BUILD FAILED'
}
