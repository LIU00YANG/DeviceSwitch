# DeviceSwitch 卸载程序
Add-Type -AssemblyName PresentationFramework

$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
$appDir  = Split-Path -Parent $exePath

$r = [System.Windows.MessageBox]::Show(
    "确定要卸载「设备开关 DeviceSwitch」吗？`n`n将删除程序文件、快捷方式和注册信息。",
    '卸载 设备开关', 'YesNo', 'Question')
if ($r -ne 'Yes') { exit }

# 删除快捷方式
$sm   = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\设备开关.lnk'
$desk = Join-Path $env:PUBLIC 'Desktop\设备开关.lnk'
Remove-Item $sm   -Force -ErrorAction SilentlyContinue
Remove-Item $desk -Force -ErrorAction SilentlyContinue

# 删除注册表卸载项
Remove-Item 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DeviceSwitch' -Recurse -Force -ErrorAction SilentlyContinue

# 自删除: 启动延迟命令删除安装目录 (正在运行的 exe 不能删自己)
Start-Process cmd.exe -ArgumentList "/c timeout /t 2 /nobreak >nul & rd /s /q `"$appDir`"" -WindowStyle Hidden

[System.Windows.MessageBox]::Show('设备开关已卸载。', '完成', 'OK', 'Information') | Out-Null
exit
