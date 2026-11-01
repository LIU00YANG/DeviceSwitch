# 设备开关 DeviceSwitch

一个轻量的 Windows 硬件设备一键开关工具：触摸板、摄像头、麦克风、USB 存储设备，点一下滑块即可禁用 / 启用。

深色卡片式界面 · 原生 C# 编译 · 零依赖 · 操作与设备管理器完全等效，随时可恢复。

## 功能

| 设备 | 说明 |
|---|---|
| 🖲️ 触摸板 | 可靠识别精确式触摸板（兼容 ID `PNP0C50`），打字防误触 |
| 📷 摄像头 | 会议/隐私场景一键关闭 |
| 🎙️ 麦克风 | 全局禁用音频输入 |
| 💾 USB 存储 | 禁用 U 盘/移动硬盘（带弹出确认，防止数据丢失） |

- 与「设备管理器 → 禁用设备」完全等效，状态实时同步
- 自动请求管理员权限（UAC），无需手动右键
- 单文件免安装运行，也可通过安装向导装到系统（开始菜单 / 桌面快捷方式 / 应用列表卸载）

## 下载

前往 [Releases](../../releases) 下载 **已签名** 的 `DeviceSwitch-signed.zip`：

- `DeviceSwitch-Setup.exe` — 图形化安装程序（推荐）
- `DeviceSwitch.exe` — 主程序（绿色免安装）
- `Uninstall.exe` — 卸载程序（安装包已内置）

## 从源码构建

只需要 Windows 自带的 .NET Framework 编译器，无需安装 Visual Studio：

```powershell
# 需要管理员 PowerShell 仅用于运行产物，编译本身不需要
powershell -ExecutionPolicy Bypass -File src/Build-Native.ps1
```

产物输出到 `src/`：`DeviceSwitch.exe`、`Uninstall.exe`、`DeviceSwitch-Setup.exe`。

## 技术要点

- **界面**：WPF + XAML（`ui.xaml` / `installer-ui.xaml` 以资源形式嵌入，`XamlReader` 运行时加载）
- **设备枚举**：WMI `Win32_PnPEntity`（`ConfigManagerErrorCode <> 45` 过滤已拔出的幽灵设备）
- **设备启停**：调用微软签名的 `pnputil.exe /enable-device|/disable-device`
- **触摸板识别**：兼容 ID `PNP0C50`（Precision Touchpad 的可靠标识，驱动名可能是通用的 "I2C HID 设备"）
- **原生编译**：`csc.exe`（.NET Framework 4.x 自带），非脚本壳，杀毒软件友好

`powershell-version/` 目录保留了最初的 PowerShell + WPF 脚本版（双击 `Start-DeviceSwitch.cmd` 即可运行，无需编译）。

## 代码签名

Release 中的二进制由 [SignPath Foundation](https://signpath.org/) 免费代码签名服务签署
（面向开源项目的 Authenticode 签名），签名流程见 `.github/workflows/release.yml`。

## License

[MIT](LICENSE) © 2026 LIU00YANG
