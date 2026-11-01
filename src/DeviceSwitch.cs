// ============================================================
//  DeviceSwitch - Windows 设备一键开关 (原生 C# 版)
//  编译: csc.exe (Windows 自带 .NET Framework 4.x)
//  枚举: WMI Win32_PnPEntity | 启停: pnputil.exe (微软签名)
// ============================================================
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Management;
using System.Reflection;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Markup;
using System.Windows.Media;
using System.Xml;

[assembly: AssemblyTitle("DeviceSwitch")]
[assembly: AssemblyDescription("Windows device one-click toggle tool")]
[assembly: AssemblyCompany("DeviceSwitch")]
[assembly: AssemblyProduct("DeviceSwitch")]
[assembly: AssemblyCopyright("2026")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public class DeviceInfo {
    public string DeviceId;
    public string Name;
    public bool Enabled;
}

public static class DeviceManager {
    // 一次性枚举全部在线 PnP 设备 (ConfigManagerErrorCode != 45 排除幽灵设备)
    public static List<ManagementObject> QueryAll() {
        var list = new List<ManagementObject>();
        using (var searcher = new ManagementObjectSearcher(
            "SELECT DeviceID, Name, Status, PNPClass, CompatibleID FROM Win32_PnPEntity WHERE ConfigManagerErrorCode <> 45")) {
            foreach (ManagementObject mo in searcher.Get()) list.Add(mo);
        }
        return list;
    }

    static bool NameMatch(ManagementObject mo, string pattern) {
        var name = mo["Name"] as string ?? "";
        return Regex.IsMatch(name, pattern, RegexOptions.IgnoreCase);
    }

    public static List<DeviceInfo> GetDevices(string key) {
        var all = QueryAll();
        var result = new List<DeviceInfo>();
        foreach (var mo in FilterDevices(key, all)) {
            result.Add(new DeviceInfo {
                DeviceId = mo["DeviceID"] as string ?? "",
                Name = mo["Name"] as string ?? "",
                Enabled = string.Equals(mo["Status"] as string, "OK", StringComparison.OrdinalIgnoreCase)
            });
        }
        return result;
    }

    static IEnumerable<ManagementObject> FilterDevices(string key, List<ManagementObject> devs) {
        switch (key) {
            case "Touchpad":
                // 精确式触摸板: 兼容ID含 PNP0C50; 或鼠标类中名称含触摸板特征
                foreach (var mo in devs) {
                    string cls = mo["PNPClass"] as string ?? "";
                    if (cls == "HIDClass") {
                        var compat = mo["CompatibleID"] as string[];
                        if (compat != null && compat.Any(c => c.IndexOf("PNP0C50", StringComparison.OrdinalIgnoreCase) >= 0)) {
                            yield return mo; continue;
                        }
                        if (NameMatch(mo, "触摸板|触控板|Touchpad|Precision")) { yield return mo; continue; }
                    }
                    if (cls == "Mouse" && NameMatch(mo, "触摸板|触控板|Touchpad|Synaptics|ELAN"))
                        yield return mo;
                }
                break;
            case "Camera":
                foreach (var mo in devs) {
                    string cls = mo["PNPClass"] as string ?? "";
                    if (cls == "Camera" || cls == "Image") yield return mo;
                }
                break;
            case "Mic":
                foreach (var mo in devs) {
                    string cls = mo["PNPClass"] as string ?? "";
                    if (cls == "AudioEndpoint" && NameMatch(mo, "麦克风|话筒|Microphone|Mic\\b"))
                        yield return mo;
                }
                break;
            case "UsbStorage":
                foreach (var mo in devs) {
                    string cls = mo["PNPClass"] as string ?? "";
                    string id = mo["DeviceID"] as string ?? "";
                    if (cls == "DiskDrive" && id.StartsWith("USBSTOR", StringComparison.OrdinalIgnoreCase))
                        yield return mo;
                }
                break;
        }
    }

    // 用微软签名的 pnputil.exe 启停设备
    public static void SetState(IEnumerable<DeviceInfo> devs, bool enable) {
        string pnputil = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System), "pnputil.exe");
        foreach (var d in devs) {
            string args = (enable ? "/enable-device " : "/disable-device ") + "\"" + d.DeviceId + "\"";
            var psi = new ProcessStartInfo(pnputil, args) {
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using (var p = Process.Start(psi)) {
                p.WaitForExit(15000);
                if (p.ExitCode != 0)
                    throw new Exception("pnputil 失败 (" + p.ExitCode + "): " + d.Name);
            }
        }
    }
}

public class MainWindow : Window {
    static readonly string[] Keys = { "Touchpad", "Camera", "Mic", "UsbStorage" };
    Dictionary<string, TextBlock> devsText = new Dictionary<string, TextBlock>();
    Dictionary<string, Border> badge = new Dictionary<string, Border>();
    Dictionary<string, TextBlock> badgeText = new Dictionary<string, TextBlock>();
    Dictionary<string, ToggleButton> sw = new Dictionary<string, ToggleButton>();
    bool updating = false;

    static readonly SolidColorBrush Green = new SolidColorBrush(Color.FromRgb(0x4A, 0xDE, 0x80));
    static readonly SolidColorBrush GreenBg = new SolidColorBrush(Color.FromRgb(0x12, 0x33, 0x1F));
    static readonly SolidColorBrush Red = new SolidColorBrush(Color.FromRgb(0xF8, 0x71, 0x71));
    static readonly SolidColorBrush RedBg = new SolidColorBrush(Color.FromRgb(0x3A, 0x1B, 0x1B));
    static readonly SolidColorBrush Yellow = new SolidColorBrush(Color.FromRgb(0xFB, 0xBF, 0x24));
    static readonly SolidColorBrush YellowBg = new SolidColorBrush(Color.FromRgb(0x3A, 0x2E, 0x12));
    static readonly SolidColorBrush Gray = new SolidColorBrush(Color.FromRgb(0x8B, 0x93, 0xAC));
    static readonly SolidColorBrush GrayBg = new SolidColorBrush(Color.FromRgb(0x2A, 0x30, 0x44));

    public MainWindow() {
        // 从嵌入资源加载界面 XAML
        Window win;
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("ui.xaml"))
            win = (Window)XamlReader.Load(s);
        // 把 XAML 窗口的内容和属性搬到当前窗口
        Title = win.Title; Width = win.Width; Height = win.Height;
        ResizeMode = win.ResizeMode; WindowStartupLocation = win.WindowStartupLocation;
        Background = win.Background; FontFamily = win.FontFamily;
        Content = win.Content;

        foreach (var k in Keys) {
            devsText[k] = (TextBlock)FindName(k + "Devs");
            badge[k] = (Border)FindName(k + "Badge");
            badgeText[k] = (TextBlock)FindName(k + "BadgeText");
            sw[k] = (ToggleButton)FindName(k + "Switch");
            string key = k;   // 闭包
            sw[k].Click += (s, e) => OnToggle(key);
        }
        ((Button)FindName("BtnRefresh")).Click += (s, e) => UpdateAll();
        ((Button)FindName("BtnDevmgmt")).Click += (s, e) => Process.Start("devmgmt.msc");
        UpdateAll();
    }

    void SetBadge(string key, string text, SolidColorBrush fg, SolidColorBrush bg) {
        badgeText[key].Text = text;
        badgeText[key].Foreground = fg;
        badge[key].Background = bg;
    }

    void UpdateCard(string key) {
        updating = true;
        var devs = DeviceManager.GetDevices(key);
        if (devs.Count == 0) {
            devsText[key].Text = "未检测到此类设备";
            SetBadge(key, "无设备", Gray, GrayBg);
            sw[key].IsEnabled = false;
            sw[key].IsChecked = false;
        } else {
            devsText[key].Text = string.Join("、", devs.Select(d => d.Name));
            int on = devs.Count(d => d.Enabled);
            if (on == devs.Count)      { SetBadge(key, "已启用", Green, GreenBg);  sw[key].IsChecked = true; }
            else if (on == 0)          { SetBadge(key, "已禁用", Red, RedBg);      sw[key].IsChecked = false; }
            else { SetBadge(key, "部分启用 (" + on + "/" + devs.Count + ")", Yellow, YellowBg); sw[key].IsChecked = false; }
            sw[key].IsEnabled = true;
        }
        updating = false;
    }

    void UpdateAll() { foreach (var k in Keys) UpdateCard(k); }

    void OnToggle(string key) {
        if (updating) return;
        bool targetOn = sw[key].IsChecked == true;
        var devs = DeviceManager.GetDevices(key);
        if (devs.Count == 0) return;

        if (key == "UsbStorage" && !targetOn) {
            var r = MessageBox.Show(this,
                "禁用 USB 存储设备前，请先安全弹出正在使用的 U 盘 / 移动硬盘。\n\n确定要禁用吗？",
                "确认", MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (r != MessageBoxResult.Yes) { UpdateCard(key); return; }
        }

        sw[key].IsEnabled = false;
        try {
            DeviceManager.SetState(devs, targetOn);
        } catch (Exception ex) {
            MessageBox.Show(this, "操作失败：" + ex.Message, "错误", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        System.Threading.Thread.Sleep(400);
        UpdateCard(key);
    }

    [STAThread]
    public static int Main(string[] args) {
        // 自检模式: 输出检测结果后退出 (供无界面测试)
        if (args.Any(a => a == "--selftest")) {
            var lines = new List<string>();
            foreach (var k in Keys) {
                var devs = DeviceManager.GetDevices(k);
                lines.Add("== " + k + ": " + devs.Count + " ==");
                foreach (var d in devs)
                    lines.Add("   [" + (d.Enabled ? "ON " : "OFF") + "] " + d.Name + " | " + d.DeviceId);
            }
            System.IO.File.WriteAllLines(
                System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "selftest.txt"), lines);
            return 0;
        }
        var app = new Application();
        app.Run(new MainWindow());
        return 0;
    }
}
