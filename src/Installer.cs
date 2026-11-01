// DeviceSwitch 安装程序 (原生 C#, 程序文件以资源形式嵌入)
using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Threading;
using Microsoft.Win32;

[assembly: AssemblyTitle("DeviceSwitch Setup")]
[assembly: AssemblyDescription("DeviceSwitch installer")]
[assembly: AssemblyProduct("DeviceSwitch")]
[assembly: AssemblyCopyright("2026")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

public class SetupWindow : Window {
    TextBox txtPath;
    CheckBox chkDesktop, chkStart;
    Grid pageWelcome, pageProg, pageDone;
    ProgressBar bar;
    TextBlock txtStep, txtDoneInfo;
    string installedTo;

    public SetupWindow() {
        Window win;
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("installer-ui.xaml"))
            win = (Window)XamlReader.Load(s);
        Title = win.Title; Width = win.Width; Height = win.Height;
        ResizeMode = win.ResizeMode; WindowStartupLocation = win.WindowStartupLocation;
        Background = win.Background; FontFamily = win.FontFamily;
        Content = win.Content;

        txtPath = (TextBox)FindName("TxtPath");
        chkDesktop = (CheckBox)FindName("ChkDesktop");
        chkStart = (CheckBox)FindName("ChkStartMenu");
        pageWelcome = (Grid)FindName("PageWelcome");
        pageProg = (Grid)FindName("PageProgress");
        pageDone = (Grid)FindName("PageDone");
        bar = (ProgressBar)FindName("Bar");
        txtStep = (TextBlock)FindName("TxtStep");
        txtDoneInfo = (TextBlock)FindName("TxtDoneInfo");

        txtPath.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "DeviceSwitch");

        ((Button)FindName("BtnBrowse")).Click += (s, e) => {
            using (var dlg = new System.Windows.Forms.FolderBrowserDialog { Description = "选择安装文件夹" })
                if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK) txtPath.Text = dlg.SelectedPath;
        };
        ((Button)FindName("BtnCancel1")).Click += (s, e) => Close();
        ((Button)FindName("BtnClose")).Click += (s, e) => Close();
        ((Button)FindName("BtnRun")).Click += (s, e) => {
            if (installedTo != null) Process.Start(Path.Combine(installedTo, "DeviceSwitch.exe"));
            Close();
        };
        ((Button)FindName("BtnInstall")).Click += (s, e) => DoInstall();
    }

    void RefreshUi() {
        Dispatcher.Invoke(new Action(() => { }), DispatcherPriority.Render);
    }
    void SetStep(int pct, string msg) { bar.Value = pct; txtStep.Text = msg; RefreshUi(); }

    void ExtractResource(string resName, string destPath) {
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream(resName))
        using (var fs = File.Create(destPath)) s.CopyTo(fs);
    }

    void CreateShortcut(string lnkPath, string target) {
        // 通过 COM WScript.Shell 创建快捷方式
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic sc = shell.CreateShortcut(lnkPath);
        sc.TargetPath = target;
        sc.Description = "设备开关 - 一键禁用/启用硬件设备";
        sc.Save();
    }

    void DoInstall() {
        string dest = txtPath.Text.Trim();
        if (dest.Length == 0) return;
        pageWelcome.Visibility = Visibility.Collapsed;
        pageProg.Visibility = Visibility.Visible;
        try {
            SetStep(10, "创建安装目录...");
            Directory.CreateDirectory(dest);

            SetStep(30, "释放程序文件...");
            ExtractResource("DeviceSwitch.exe", Path.Combine(dest, "DeviceSwitch.exe"));
            ExtractResource("Uninstall.exe", Path.Combine(dest, "Uninstall.exe"));

            SetStep(55, "创建快捷方式...");
            string target = Path.Combine(dest, "DeviceSwitch.exe");
            if (chkStart.IsChecked == true)
                CreateShortcut(Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.CommonStartMenu),
                    @"Programs\设备开关.lnk"), target);
            if (chkDesktop.IsChecked == true)
                CreateShortcut(Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory),
                    "设备开关.lnk"), target);

            SetStep(80, "写入注册信息...");
            long sizeKB = new DirectoryInfo(dest).GetFiles().Sum(f => f.Length) / 1024;
            using (var key = Registry.LocalMachine.CreateSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DeviceSwitch")) {
                key.SetValue("DisplayName", "设备开关 DeviceSwitch");
                key.SetValue("DisplayVersion", "1.0.0");
                key.SetValue("Publisher", "DeviceSwitch");
                key.SetValue("InstallLocation", dest);
                key.SetValue("DisplayIcon", target + ",0");
                key.SetValue("UninstallString", "\"" + Path.Combine(dest, "Uninstall.exe") + "\"");
                key.SetValue("EstimatedSize", (uint)sizeKB, RegistryValueKind.DWord);
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
            }

            SetStep(100, "完成");
            installedTo = dest;
            txtDoneInfo.Text = "已安装到：" + dest + "\n可在「设置 → 应用 → 已安装的应用」中卸载。";
            pageProg.Visibility = Visibility.Collapsed;
            pageDone.Visibility = Visibility.Visible;
        } catch (Exception ex) {
            MessageBox.Show(this, "安装失败：" + ex.Message, "错误", MessageBoxButton.OK, MessageBoxImage.Error);
            pageProg.Visibility = Visibility.Collapsed;
            pageWelcome.Visibility = Visibility.Visible;
        }
    }

    [STAThread]
    public static int Main() {
        new Application().Run(new SetupWindow());
        return 0;
    }
}
