$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fw = Split-Path $csc
$wpf = Join-Path $fw 'WPF'
$out = Join-Path $dir 'Test-GUI.exe'
& $csc /nologo /target:exe /platform:anycpu "/out:$out" `
  "/r:$wpf\PresentationFramework.dll" "/r:$wpf\PresentationCore.dll" "/r:$wpf\WindowsBase.dll" `
  "/r:$fw\System.Xaml.dll" "/r:$fw\System.Management.dll" `
  "/resource:$(Join-Path $dir 'ui.xaml'),ui.xaml" (Join-Path $dir 'DeviceSwitch.cs')
if ($LASTEXITCODE -eq 0) { 'TEST BUILD OK' } else { 'TEST BUILD FAILED' }
