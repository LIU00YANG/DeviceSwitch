# 纯字节方式生成 256x256 32bpp ICO 图标 (深色圆角方块 + 绿色开关滑块)
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path $dir 'icon.ico'
$size = 256

# 颜色 (R,G,B)
$bg    = 20, 24, 36      # 深色背景 #141824
$green = 34, 197, 94     # 开关绿 #22C55E
$white = 232, 234, 242   # 滑块钮 #E8EAF2

function Test-InRoundRect($x, $y, $w, $h, $r) {
    $cx = [Math]::Min([Math]::Max($x, $r), $w - $r)
    $cy = [Math]::Min([Math]::Max($y, $r), $h - $r)
    return (($x - $cx) * ($x - $cx) + ($y - $cy) * ($y - $cy)) -le ($r * $r)
}
function Test-InEllipse($x, $y, $cx, $cy, $rx, $ry) {
    $dx = ($x - $cx) / $rx; $dy = ($y - $cy) / $ry
    return ($dx * $dx + $dy * $dy) -le 1.0
}

# XOR 位图数据 (BGRA, 自底向上)
$xor = New-Object byte[] ($size * $size * 4)
for ($y = 0; $y -lt $size; $y++) {
    $row = ($size - 1 - $y) * $size * 4   # 自底向上
    for ($x = 0; $x -lt $size; $x++) {
        $o = $row + $x * 4
        if (-not (Test-InRoundRect $x $y $size $size 56)) {
            continue   # 透明
        }
        $c = $bg
        if (Test-InEllipse $x $y 128 128 88 32) { $c = $green }       # 绿色滑轨
        if (Test-InEllipse $x $y 186 128 24 24) { $c = $white }       # 白色滑钮
        $xor[$o]   = [byte]$c[2]   # B
        $xor[$o+1] = [byte]$c[1]   # G
        $xor[$o+2] = [byte]$c[0]   # R
        $xor[$o+3] = 255           # A
    }
}

$and = New-Object byte[] ($size * 32)   # AND 掩码全 0 (不透明由 Alpha 控制)

# BITMAPINFOHEADER (高度写 2 倍 = XOR + AND)
$bih = New-Object byte[] 40
[BitConverter]::GetBytes([uint32]40).CopyTo($bih, 0)
[BitConverter]::GetBytes([int32]$size).CopyTo($bih, 4)
[BitConverter]::GetBytes([int32]($size * 2)).CopyTo($bih, 8)
[BitConverter]::GetBytes([uint16]1).CopyTo($bih, 12)
[BitConverter]::GetBytes([uint16]32).CopyTo($bih, 14)

$imgLen = 40 + $xor.Length + $and.Length
$fs = [System.IO.File]::Create($out)
$bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)   # ICONDIR
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)  # 256x256
$bw.Write([uint16]1); $bw.Write([uint16]32)
$bw.Write([uint32]$imgLen); $bw.Write([uint32]22)
$bw.Write($bih); $bw.Write($xor); $bw.Write($and)
$bw.Close(); $fs.Close()
"icon.ico OK: $((Get-Item $out).Length) bytes"
