# ============================================================
#  DeviceSwitch 安装程序 (由 Build-Installer.ps1 生成, 内嵌程序文件)
# ============================================================
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

$script:AppExeB64 = '__APP_B64__'
$script:UninsB64  = '__UNINS_B64__'

$xamlText = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="设备开关 - 安装程序" Width="540" Height="430" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        Background="#141824" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style x:Key="MainBtn" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="22,9"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" CornerRadius="9" Background="#22C55E" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#16A34A"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GhostBtn" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Foreground" Value="#C9CEDF"/>
      <Setter Property="Padding" Value="18,9"/>
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
  </Window.Resources>

  <Grid>
    <!-- 页面1: 欢迎 + 安装路径 -->
    <Grid x:Name="PageWelcome" Margin="30,24">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel>
        <TextBlock Text="设备开关" FontSize="26" FontWeight="Bold" Foreground="#F1F3FA"/>
        <TextBlock Text="DeviceSwitch v1.0 · Windows 设备一键开关工具" FontSize="12"
                   Foreground="#8B93AC" Margin="0,4,0,0"/>
      </StackPanel>
      <StackPanel Grid.Row="1" Margin="0,28,0,0">
        <TextBlock Text="一键禁用 / 启用触摸板、摄像头、麦克风、USB 存储设备。"
                   FontSize="13" Foreground="#C9CEDF" TextWrapping="Wrap"/>
        <TextBlock Text="安装位置" FontSize="13" FontWeight="SemiBold" Foreground="#EDEFF7" Margin="0,22,0,8"/>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBox x:Name="TxtPath" FontSize="12" Padding="10,8" Background="#1E2433"
                   Foreground="#EDEFF7" BorderBrush="#3A4157" BorderThickness="1"
                   VerticalContentAlignment="Center"/>
          <Button x:Name="BtnBrowse" Grid.Column="1" Style="{StaticResource GhostBtn}"
                  Content="浏览..." Margin="10,0,0,0" Padding="14,8"/>
        </Grid>
        <CheckBox x:Name="ChkDesktop" Content="创建桌面快捷方式" IsChecked="True"
                  Foreground="#C9CEDF" FontSize="12" Margin="0,16,0,0"/>
        <CheckBox x:Name="ChkStartMenu" Content="创建开始菜单快捷方式" IsChecked="True"
                  Foreground="#C9CEDF" FontSize="12" Margin="0,8,0,0"/>
      </StackPanel>
      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnCancel1" Style="{StaticResource GhostBtn}" Content="取消" Margin="0,0,10,0"/>
        <Button x:Name="BtnInstall" Style="{StaticResource MainBtn}" Content="立即安装"/>
      </StackPanel>
    </Grid>

    <!-- 页面2: 安装进度 -->
    <Grid x:Name="PageProgress" Margin="30,24" Visibility="Collapsed">
      <StackPanel VerticalAlignment="Center">
        <TextBlock Text="正在安装..." FontSize="22" FontWeight="Bold" Foreground="#F1F3FA"
                   HorizontalAlignment="Center"/>
        <ProgressBar x:Name="Bar" Height="10" Margin="0,24,0,0" Minimum="0" Maximum="100"
                     Background="#1E2433" Foreground="#22C55E" BorderBrush="#3A4157"/>
        <TextBlock x:Name="TxtStep" FontSize="12" Foreground="#8B93AC"
                   HorizontalAlignment="Center" Margin="0,14,0,0"/>
      </StackPanel>
    </Grid>

    <!-- 页面3: 完成 -->
    <Grid x:Name="PageDone" Margin="30,24" Visibility="Collapsed">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel VerticalAlignment="Center">
        <TextBlock Text="✓ 安装完成" FontSize="24" FontWeight="Bold" Foreground="#4ADE80"
                   HorizontalAlignment="Center"/>
        <TextBlock x:Name="TxtDoneInfo" FontSize="12" Foreground="#8B93AC" TextWrapping="Wrap"
                   HorizontalAlignment="Center" TextAlignment="Center" Margin="0,14,0,0"/>
      </StackPanel>
      <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="BtnRun" Style="{StaticResource MainBtn}" Content="运行设备开关" Margin="0,0,10,0"/>
        <Button x:Name="BtnClose" Style="{StaticResource GhostBtn}" Content="关闭"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
"@

[xml]$xaml = $xamlText
$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

$txtPath     = $win.FindName('TxtPath')
$btnBrowse   = $win.FindName('BtnBrowse')
$btnInstall  = $win.FindName('BtnInstall')
$btnCancel1  = $win.FindName('BtnCancel1')
$chkDesktop  = $win.FindName('ChkDesktop')
$chkStart    = $win.FindName('ChkStartMenu')
$pageWelcome = $win.FindName('PageWelcome')
$pageProg    = $win.FindName('PageProgress')
$pageDone    = $win.FindName('PageDone')
$bar         = $win.FindName('Bar')
$txtStep     = $win.FindName('TxtStep')
$txtDoneInfo = $win.FindName('TxtDoneInfo')
$btnRun      = $win.FindName('BtnRun')
$btnClose    = $win.FindName('BtnClose')

$txtPath.Text = Join-Path $env:ProgramFiles 'DeviceSwitch'
$script:installedTo = $null

function Update-Ui {
    $win.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Render)
}
function Set-Step([int]$pct, [string]$msg) {
    $bar.Value = $pct; $txtStep.Text = $msg; Update-Ui
}

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = '选择安装文件夹'
    if ($dlg.ShowDialog() -eq 'OK') { $txtPath.Text = $dlg.SelectedPath }
})
$btnCancel1.Add_Click({ $win.Close() })
$btnClose.Add_Click({ $win.Close() })
$btnRun.Add_Click({
    if ($script:installedTo) {
        Start-Process (Join-Path $script:installedTo 'DeviceSwitch.exe')
    }
    $win.Close()
})

$btnInstall.Add_Click({
    $dest = $txtPath.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($dest)) { return }
    $pageWelcome.Visibility = 'Collapsed'
    $pageProg.Visibility = 'Visible'
    try {
        Set-Step 10 '创建安装目录...'
        New-Item -ItemType Directory -Path $dest -Force | Out-Null

        Set-Step 30 '释放程序文件...'
        [System.IO.File]::WriteAllBytes((Join-Path $dest 'DeviceSwitch.exe'), [Convert]::FromBase64String($script:AppExeB64))
        [System.IO.File]::WriteAllBytes((Join-Path $dest 'Uninstall.exe'),   [Convert]::FromBase64String($script:UninsB64))

        Set-Step 55 '创建快捷方式...'
        $shell = New-Object -ComObject WScript.Shell
        if ($chkStart.IsChecked) {
            $lnkPath = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\设备开关.lnk'
            $sc = $shell.CreateShortcut($lnkPath)
            $sc.TargetPath = Join-Path $dest 'DeviceSwitch.exe'
            $sc.Description = '设备开关 - 一键禁用/启用硬件设备'
            $sc.Save()
        }
        if ($chkDesktop.IsChecked) {
            $lnkPath = Join-Path $env:PUBLIC 'Desktop\设备开关.lnk'
            $sc2 = $shell.CreateShortcut($lnkPath)
            $sc2.TargetPath = Join-Path $dest 'DeviceSwitch.exe'
            $sc2.Description = '设备开关 - 一键禁用/启用硬件设备'
            $sc2.Save()
        }

        Set-Step 80 '写入注册信息...'
        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\DeviceSwitch'
        New-Item -Path $regPath -Force | Out-Null
        $sizeKB = [Math]::Round(((Get-ChildItem $dest -File | Measure-Object Length -Sum).Sum / 1KB))
        Set-ItemProperty $regPath 'DisplayName'     '设备开关 DeviceSwitch'
        Set-ItemProperty $regPath 'DisplayVersion'  '1.0.0'
        Set-ItemProperty $regPath 'Publisher'       'DeviceSwitch'
        Set-ItemProperty $regPath 'InstallLocation' $dest
        Set-ItemProperty $regPath 'DisplayIcon'     ((Join-Path $dest 'DeviceSwitch.exe') + ',0')
        Set-ItemProperty $regPath 'UninstallString' ('"' + (Join-Path $dest 'Uninstall.exe') + '"')
        Set-ItemProperty $regPath 'EstimatedSize'   ([uint32]$sizeKB) -Type DWord
        Set-ItemProperty $regPath 'NoModify'        1 -Type DWord
        Set-ItemProperty $regPath 'NoRepair'        1 -Type DWord

        Set-Step 100 '完成'
        $script:installedTo = $dest
        $txtDoneInfo.Text = "已安装到：$dest`n可在「设置 → 应用 → 已安装的应用」中卸载。"
        $pageProg.Visibility = 'Collapsed'
        $pageDone.Visibility = 'Visible'
    } catch {
        [System.Windows.MessageBox]::Show($win, "安装失败：$($_.Exception.Message)", '错误', 'OK', 'Error') | Out-Null
        $pageProg.Visibility = 'Collapsed'
        $pageWelcome.Visibility = 'Visible'
    }
})

$win.ShowDialog() | Out-Null
