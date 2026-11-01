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

public class SetupWindow {
    // 直接使用 XamlReader 加载出的窗口 (x:Name 注册在该窗口的 NameScope 上)
    public Window Win;
    TextBox txtPath;
    CheckBox chkDesktop, chkStart;
    Grid pageWelcome, pageProg, pageDone;
    ProgressBar bar;
    TextBlock txtStep, txtDoneInfo;
    string installedTo;

    public SetupWindow() {
        using (var s = Assembly.GetExecutingAssembly().GetManifestResourceStream("installer-ui.xaml"))
            Win = (Window)XamlReader.Load(s);

        txtPath = (TextBox)Win.FindName("TxtPath");
        chkDesktop = (CheckBox)Win.FindName("ChkDesktop");
        chkStart = (CheckBox)Win.FindName("ChkStartMenu");
        pageWelcome = (Grid)Win.FindName("PageWelcome");
        pageProg = (Grid)Win.FindName("PageProgress");
        pageDone = (Grid)Win.FindName("PageDone");
        bar = (ProgressBar)Win.FindName("Bar");
        txtStep = (TextBlock)Win.FindName("TxtStep");
        txtDoneInfo = (TextBlock)Win.FindName("TxtDoneInfo");

        txtPath.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "DeviceSwitch");

        ((Button)Win.FindName("BtnBrowse")).Click += (s, e) => {
            using (var dlg = new System.Windows.Forms.FolderBrowserDialog { Description = "选择安装文件夹" })
                if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK) txtPath.Text = dlg.SelectedPath;
        };
        ((Button)Win.FindName("BtnCancel1")).Click += (s, e) => Win.Close();
        ((Button)Win.FindName("BtnClose")).Click += (s, e) => Win.Close();
        ((Button)Win.FindName("BtnRun")).Click += (s, e) => {
            if (installedTo != null) Process.Start(Path.Combine(installedTo, "DeviceSwitch.exe"));
            Win.Close();
        };
        ((Button)Win.FindName("BtnInstall")).Click += (s, e) => DoInstall();
    }

    void RefreshUi() {
        Win.Dispatcher.Invoke(new Action(() => { }), DispatcherPriority.Render);
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
            MessageBox.Show(Win, "安装失败：" + ex.Message, "错误", MessageBoxButton.OK, MessageBoxImage.Error);
            pageProg.Visibility = Visibility.Collapsed;
            pageWelcome.Visibility = Visibility.Visible;
        }
    }

    [STAThread]
    public static int Main() {
        new Application().Run(new SetupWindow().Win);
        return 0;
    }
}
