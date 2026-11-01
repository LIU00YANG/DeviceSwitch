// DeviceSwitch 卸载程序 (原生 C#)
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows;
using Microsoft.Win32;

[assembly: AssemblyTitle("DeviceSwitch Uninstall")]
[assembly: AssemblyProduct("DeviceSwitch")]
[assembly: AssemblyCopyright("2026")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public static class Uninstall {
    static void TryDelete(string path) {
        try { if (File.Exists(path)) File.Delete(path); } catch { }
    }

    [STAThread]
    public static int Main() {
        string exePath = Process.GetCurrentProcess().MainModule.FileName;
        string appDir = Path.GetDirectoryName(exePath);

        var r = MessageBox.Show(
            "确定要卸载「设备开关 DeviceSwitch」吗？\n\n将删除程序文件、快捷方式和注册信息。",
            "卸载 设备开关", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (r != MessageBoxResult.Yes) return 0;

        // 快捷方式
        string sm = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
            @"Programs\设备开关.lnk");
        string desk = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory),
            "设备开关.lnk");
        TryDelete(sm);
        TryDelete(desk);

        // 注册表卸载项
        try {
            Registry.LocalMachine.DeleteSubKeyTree(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DeviceSwitch", false);
        } catch { }

        // 自删除: 延迟命令删安装目录 (运行中的 exe 无法删除自身)
        Process.Start(new ProcessStartInfo("cmd.exe",
            "/c timeout /t 2 /nobreak >nul & rd /s /q \"" + appDir + "\"") {
            CreateNoWindow = true, WindowStyle = ProcessWindowStyle.Hidden, UseShellExecute = false
        });

        MessageBox.Show("设备开关已卸载。", "完成", MessageBoxButton.OK, MessageBoxImage.Information);
        return 0;
    }
}
