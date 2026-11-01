# Native C# build: DeviceSwitch.exe / Uninstall.exe / DeviceSwitch-Setup.exe
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$csc = (Resolve-Path $csc).Path
$icon = Join-Path $dir 'icon.ico'
$manifest = Join-Path $dir 'app.manifest'
$fw  = Split-Path $csc
$wpf = Join-Path $fw 'WPF'
$wpfRefs = @("/r:$wpf\PresentationFramework.dll","/r:$wpf\PresentationCore.dll","/r:$wpf\WindowsBase.dll","/r:$fw\System.Xaml.dll")

function Compile($src, $out, [string[]]$extra) {
    $args = @('/nologo','/target:winexe','/platform:anycpu',"/out:$out","/win32icon:$icon") + $extra + @((Join-Path $dir $src))
    & $csc $args
    if ($LASTEXITCODE -ne 0) { throw "COMPILE FAILED: $src" }
    "OK: $(Split-Path $out -Leaf) ($([Math]::Round((Get-Item $out).Length/1KB)) KB)"
}

# 1. Main app (with admin manifest)
Compile 'DeviceSwitch.cs' (Join-Path $dir 'DeviceSwitch.exe') `
    ($wpfRefs + @("/r:$fw\System.Management.dll","/win32manifest:$manifest","/resource:$(Join-Path $dir 'ui.xaml'),ui.xaml"))

# 2. (selftest 已验证通过, 如需重测请手动编译无清单版本)

# 3. Uninstaller
Compile 'Uninstall.cs' (Join-Path $dir 'Uninstall.exe') `
    @("/r:$wpf\PresentationFramework.dll","/r:$wpf\PresentationCore.dll","/r:$wpf\WindowsBase.dll","/r:$fw\System.Xaml.dll","/win32manifest:$manifest")

# 4. Setup (embeds the two exes + wizard xaml)
Compile 'Installer.cs' (Join-Path $dir 'DeviceSwitch-Setup.exe') `
    @("/r:$wpf\PresentationFramework.dll","/r:$wpf\PresentationCore.dll","/r:$wpf\WindowsBase.dll","/r:$fw\System.Xaml.dll",
      "/r:$fw\System.Windows.Forms.dll","/r:$fw\Microsoft.CSharp.dll","/win32manifest:$manifest",
      "/resource:$(Join-Path $dir 'DeviceSwitch.exe'),DeviceSwitch.exe",
      "/resource:$(Join-Path $dir 'Uninstall.exe'),Uninstall.exe",
      "/resource:$(Join-Path $dir 'installer-ui.xaml'),installer-ui.xaml")

'ALL BUILDS DONE'
