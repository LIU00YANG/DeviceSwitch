# ============================================================
#  DeviceSwitch - Windows 设备一键开关
#  触摸板 / 摄像头 / 麦克风 / USB存储  图形界面管理工具
#  运行环境: Windows 10 / 11, PowerShell 5.1+ (系统自带)
#  原理: 调用系统 PnP 接口, 与设备管理器禁用/启用完全等效
# ============================================================

# ---------- 自动提权 (禁用设备需要管理员权限) ----------
# 编译为 exe 后自带 requireAdministrator 清单, 且 ps2exe 默认 STA, 两处判断仅对脚本直跑生效
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($PSCommandPath -and -not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`""
    exit
}
if ($PSCommandPath -and [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`""
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ---------- 设备检测 ----------
function Get-CategoryDevices([string]$key) {
    switch ($key) {
        'Touchpad' {
            # 精确式触摸板可靠识别: 兼容ID含 PNP0C50 (即使驱动名显示为通用的"I2C HID 设备")
            # 同时兜底匹配名称含 触摸板/Touchpad 的设备
            $hid = Get-PnpDevice -PresentOnly -Class HIDClass -ErrorAction SilentlyContinue
            $result = @()
            foreach ($h in $hid) {
                $compat = (Get-PnpDeviceProperty -InstanceId $h.InstanceId -KeyName 'DEVPKEY_Device_CompatibleIds' -ErrorAction SilentlyContinue).Data
                if ($compat -and ($compat -contains 'PNP0C50')) { $result += $h; continue }
                if ($h.FriendlyName -match '触摸板|触控板|Touchpad|Precision') { $result += $h }
            }
            # 其他类别的触摸板 (如 PS/2 Synaptics)
            $others = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
                $_.Class -in @('Mouse') -and $_.FriendlyName -match '触摸板|触控板|Touchpad|Synaptics|ELAN'
            }
            $result + $others
        }
        'Camera' {
            Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Class -in @('Camera', 'Image') }
        }
        'Mic' {
            Get-PnpDevice -PresentOnly -Class AudioEndpoint -ErrorAction SilentlyContinue | Where-Object {
                $_.FriendlyName -match '麦克风|话筒|Microphone|Mic\b'
            }
        }
        'UsbStorage' {
            Get-PnpDevice -PresentOnly -Class DiskDrive -ErrorAction SilentlyContinue | Where-Object {
                $_.InstanceId -match '^USBSTOR'
            }
        }
    }
}

function Test-DeviceEnabled([string]$instanceId) {
    # 设备状态: OK = 启用, Error = 已禁用 (设备管理器里被禁用)
    try {
        return ((Get-PnpDevice -InstanceId $instanceId -ErrorAction Stop).Status -eq 'OK')
    } catch {
        return $true   # 读不到状态时按"启用"处理, 避免误显示
    }
}

function Set-DeviceState([string[]]$ids, [bool]$enable) {
    foreach ($id in $ids) {
        if ($enable) { Enable-PnpDevice  -InstanceId $id -Confirm:$false -ErrorAction Stop }
        else         { Disable-PnpDevice -InstanceId $id -Confirm:$false -ErrorAction Stop }
    }
}

# ---------- 界面 (WPF / XAML) ----------
$xamlText = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="设备开关" Width="470" Height="700" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#141824" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <!-- 开关滑块样式 -->
    <Style x:Key="SwitchStyle" TargetType="ToggleButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Grid Width="48" Height="26">
              <Border x:Name="Track" CornerRadius="13" Background="#3A4157"/>
              <Ellipse x:Name="Thumb" Width="20" Height="20" Fill="#E8EAF2"
                       HorizontalAlignment="Left" VerticalAlignment="Center" Margin="3,0,0,0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Track" Property="Background" Value="#22C55E"/>
                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="Thumb" Property="Margin" Value="0,0,3,0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.35"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- 底部按钮样式 -->
    <Style x:Key="BarBtn" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="#C9CEDF"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" CornerRadius="9" Background="#262C40" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#333B57"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- 卡片样式 -->
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="CornerRadius" Value="14"/>
      <Setter Property="Background" Value="#1E2433"/>
      <Setter Property="Margin" Value="22,7"/>
      <Setter Property="Padding" Value="18,14"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- 标题栏 -->
    <StackPanel Margin="24,20,24,8">
      <TextBlock Text="设备开关" FontSize="24" FontWeight="Bold" Foreground="#F1F3FA"/>
      <TextBlock Text="一键禁用 / 启用硬件设备 · 与设备管理器等效 · 可随时恢复"
                 FontSize="12" Foreground="#8B93AC" Margin="0,4,0,0"/>
    </StackPanel>

    <!-- 设备卡片 -->
    <StackPanel Grid.Row="1" VerticalAlignment="Center">

      <Border Style="{StaticResource Card}">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="🖲️" FontSize="26" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <StackPanel Grid.Column="1" VerticalAlignment="Center">
            <TextBlock Text="触摸板" FontSize="15" FontWeight="SemiBold" Foreground="#EDEFF7"/>
            <TextBlock x:Name="TouchpadDevs" FontSize="11" Foreground="#8B93AC" Margin="0,2,0,6" TextWrapping="Wrap"/>
            <Border x:Name="TouchpadBadge" CornerRadius="9" Padding="10,2" HorizontalAlignment="Left">
              <TextBlock x:Name="TouchpadBadgeText" FontSize="11"/>
            </Border>
          </StackPanel>
          <ToggleButton x:Name="TouchpadSwitch" Grid.Column="2" Style="{StaticResource SwitchStyle}" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Card}">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="📷" FontSize="26" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <StackPanel Grid.Column="1" VerticalAlignment="Center">
            <TextBlock Text="摄像头" FontSize="15" FontWeight="SemiBold" Foreground="#EDEFF7"/>
            <TextBlock x:Name="CameraDevs" FontSize="11" Foreground="#8B93AC" Margin="0,2,0,6" TextWrapping="Wrap"/>
            <Border x:Name="CameraBadge" CornerRadius="9" Padding="10,2" HorizontalAlignment="Left">
              <TextBlock x:Name="CameraBadgeText" FontSize="11"/>
            </Border>
          </StackPanel>
          <ToggleButton x:Name="CameraSwitch" Grid.Column="2" Style="{StaticResource SwitchStyle}" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Card}">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="🎙️" FontSize="26" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <StackPanel Grid.Column="1" VerticalAlignment="Center">
            <TextBlock Text="麦克风" FontSize="15" FontWeight="SemiBold" Foreground="#EDEFF7"/>
            <TextBlock x:Name="MicDevs" FontSize="11" Foreground="#8B93AC" Margin="0,2,0,6" TextWrapping="Wrap"/>
            <Border x:Name="MicBadge" CornerRadius="9" Padding="10,2" HorizontalAlignment="Left">
              <TextBlock x:Name="MicBadgeText" FontSize="11"/>
            </Border>
          </StackPanel>
          <ToggleButton x:Name="MicSwitch" Grid.Column="2" Style="{StaticResource SwitchStyle}" VerticalAlignment="Center"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Card}">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="💾" FontSize="26" VerticalAlignment="Center" Margin="0,0,14,0"/>
          <StackPanel Grid.Column="1" VerticalAlignment="Center">
            <TextBlock Text="USB 存储设备" FontSize="15" FontWeight="SemiBold" Foreground="#EDEFF7"/>
            <TextBlock x:Name="UsbStorageDevs" FontSize="11" Foreground="#8B93AC" Margin="0,2,0,6" TextWrapping="Wrap"/>
            <Border x:Name="UsbStorageBadge" CornerRadius="9" Padding="10,2" HorizontalAlignment="Left">
              <TextBlock x:Name="UsbStorageBadgeText" FontSize="11"/>
            </Border>
          </StackPanel>
          <ToggleButton x:Name="UsbStorageSwitch" Grid.Column="2" Style="{StaticResource SwitchStyle}" VerticalAlignment="Center"/>
        </Grid>
      </Border>

    </StackPanel>

    <!-- 底部工具栏 -->
    <DockPanel Grid.Row="2" Margin="22,8,22,18">
      <TextBlock DockPanel.Dock="Left" VerticalAlignment="Center" FontSize="11"
                 Foreground="#5E6580" Text="v1.0 · 管理员模式"/>
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnDevmgmt" Style="{StaticResource BarBtn}" Content="设备管理器" Margin="0,0,10,0"/>
        <Button x:Name="BtnRefresh" Style="{StaticResource BarBtn}" Content="刷新状态"/>
      </StackPanel>
    </DockPanel>
  </Grid>
</Window>
"@

[xml]$xaml = $xamlText
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

# ---------- 控件引用 ----------
$keys = @('Touchpad', 'Camera', 'Mic', 'UsbStorage')
$ui = @{}
foreach ($k in $keys) {
    $ui[$k] = @{
        Devs      = $win.FindName("${k}Devs")
        Badge     = $win.FindName("${k}Badge")
        BadgeText = $win.FindName("${k}BadgeText")
        Switch    = $win.FindName("${k}Switch")
    }
}
$btnRefresh  = $win.FindName('BtnRefresh')
$btnDevmgmt  = $win.FindName('BtnDevmgmt')
$script:updating = $false

# ---------- 状态刷新 ----------
function Update-Card([string]$key) {
    $script:updating = $true
    $c = $ui[$key]
    $devs = @(Get-CategoryDevices $key)
    if ($devs.Count -eq 0) {
        $c.Devs.Text = '未检测到此类设备'
        $c.BadgeText.Text = '无设备'
        $c.BadgeText.Foreground = '#8B93AC'
        $c.Badge.Background = '#2A3044'
        $c.Switch.IsEnabled = $false
        $c.Switch.IsChecked = $false
    } else {
        $names = ($devs | ForEach-Object { $_.FriendlyName }) -join '、'
        $c.Devs.Text = $names
        $enabledCount = @($devs | Where-Object { Test-DeviceEnabled $_.InstanceId }).Count
        if ($enabledCount -eq $devs.Count) {
            $c.BadgeText.Text = '已启用'
            $c.BadgeText.Foreground = '#4ADE80'
            $c.Badge.Background = '#12331F'
            $c.Switch.IsChecked = $true
        } elseif ($enabledCount -eq 0) {
            $c.BadgeText.Text = '已禁用'
            $c.BadgeText.Foreground = '#F87171'
            $c.Badge.Background = '#3A1B1B'
            $c.Switch.IsChecked = $false
        } else {
            $c.BadgeText.Text = "部分启用 ($enabledCount/$($devs.Count))"
            $c.BadgeText.Foreground = '#FBBF24'
            $c.Badge.Background = '#3A2E12'
            $c.Switch.IsChecked = $false
        }
        $c.Switch.IsEnabled = $true
    }
    $script:updating = $false
}

function Update-All { foreach ($k in $keys) { Update-Card $k } }

# ---------- 开关事件 ----------
foreach ($k in $keys) {
    $key = $k   # 闭包捕获
    $ui[$key].Switch.Add_Click({
        if ($script:updating) { return }
        $targetOn = [bool]$ui[$key].Switch.IsChecked
        $devs = @(Get-CategoryDevices $key)
        if ($devs.Count -eq 0) { return }

        # USB 存储禁用前提示
        if ($key -eq 'UsbStorage' -and -not $targetOn) {
            $r = [System.Windows.MessageBox]::Show($win,
                "禁用 USB 存储设备前，请先安全弹出正在使用的 U 盘 / 移动硬盘。`n`n确定要禁用吗？",
                '确认', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { Update-Card $key; return }
        }

        $ui[$key].Switch.IsEnabled = $false
        try {
            Set-DeviceState ($devs | ForEach-Object { $_.InstanceId }) $targetOn
        } catch {
            [System.Windows.MessageBox]::Show($win,
                "操作失败：$($_.Exception.Message)`n`n请确认以管理员身份运行。",
                '错误', 'OK', 'Error') | Out-Null
        }
        Start-Sleep -Milliseconds 400
        Update-Card $key
    }.GetNewClosure())
}

$btnRefresh.Add_Click({ Update-All })
$btnDevmgmt.Add_Click({ Start-Process devmgmt.msc })

# ---------- 启动 ----------
Update-All
$win.ShowDialog() | Out-Null
