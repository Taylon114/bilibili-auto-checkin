# ============================================================
#  每日完成通知
#  优先系统 Toast，失败或系统通知被关时改用自绘窗口。
#  有完整运行发结果，运行中断发异常提示，今天没跑则静默退出。
# ============================================================
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------- 读取今日日志（兼容两个可能的日志位置） ----------
# 日志路径随 exe 的工作目录变化：可能在 win-x64\Logs，也可能在上级 Logs
$base = $PSScriptRoot
$logDirs = @(
  (Join-Path (Join-Path $base 'win-x64') 'Logs'),
  (Join-Path $base 'Logs')
) | Where-Object { Test-Path $_ }

$today = Get-Date -Format 'yyyyMMdd'
$files = @()
foreach ($d in $logDirs) { $files += Get-ChildItem $d -Filter "log$today*.txt" -ErrorAction SilentlyContinue }
$files = $files | Sort-Object LastWriteTime
if (-not $files) { exit }

# ---------- 查找"最近一次完整运行"与"最近一次运行起点" ----------
$bestSeg = $null
$lastStartRaw = $null
$lastStartEnded = $false
foreach ($f in $files) {
    $fl = Get-Content $f.FullName -Encoding UTF8
    $fc = @($fl | Where-Object { $_ -match '\[INF\]' } | ForEach-Object { ($_ -replace '^\d{4}-\d{2}-\d{2} \S+ \S+ \[INF\] ', '') })
    for ($i = 0; $i -lt $fc.Count; $i++) {
        if ($fc[$i] -match '开始运行') {
            $lastStartRaw = $fl[$i]
            # 截取本运行的完整段落（从"开始运行"到自己的"运行结束"）
            $endAbs = -1
            for ($j = $i; $j -lt $fc.Count; $j++) { if ($fc[$j] -match '运行结束') { $endAbs = $j; break } }
            $lastStartEnded = ($endAbs -ge 0)
            if ($endAbs -ge 0) {
                $seg = $fc[$i..$endAbs]
                # 文件按时间升序处理，最后遇到的完整运行即最新一次
                $bestSeg = $seg
            }
        }
    }
}

# ---------- 发送通知（Toast 优先，自绘窗口兜底） ----------
function Send-Notify($Title, $BodyLines) {
    $toastEnabled = $true
    $t = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name ToastEnabled -ErrorAction SilentlyContinue
    if ($t -and $t.ToastEnabled -eq 0) { $toastEnabled = $false }
    $w = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\WPN' -Name ToastEnabled -ErrorAction SilentlyContinue
    if ($w -and $w.ToastEnabled -eq 0) { $toastEnabled = $false }

    if ($toastEnabled) {
        try {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text @($Title, ($BodyLines -join '  |  ')) -UniqueIdentifier 'bilitool-daily' -Urgent -ErrorAction Stop
            Start-Sleep -Seconds 2
            $h = Get-BTHistory -UniqueIdentifier 'bilitool-daily' -ErrorAction SilentlyContinue
            if ($h) { return }
        } catch { }
    }

    # 自绘通知窗口
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $rounded = $false
    try {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public class RoundedRect {
    [DllImport("Gdi32.dll", EntryPoint = "CreateRoundRectRgn")]
    public static extern IntPtr CreateRoundRectRgn(int l, int t, int r, int b, int w, int h);
}
'@ -ErrorAction Stop
        $rounded = $true
    } catch { }

    $scr = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w = 400
    $h = 120 + ($BodyLines.Count * 18)

    $f = New-Object System.Windows.Forms.Form
    $f.FormBorderStyle = 'None'
    $f.TopMost = $true
    $f.ShowInTaskbar = $false
    $f.StartPosition = 'Manual'
    $f.BackColor = [System.Drawing.Color]::FromArgb(37, 37, 37)
    $f.Width = $w
    $f.Height = $h
    $f.Location = New-Object System.Drawing.Point (($scr.Width - $w - 20), ($scr.Height - $h - 70))
    if ($rounded) {
        $f.Region = [System.Drawing.Region]::FromHrgn([RoundedRect]::CreateRoundRectRgn(0, 0, $w, $h, 14, 14))
    }

    $l1 = New-Object System.Windows.Forms.Label
    $l1.Text = $Title
    $l1.ForeColor = [System.Drawing.Color]::White
    $l1.BackColor = [System.Drawing.Color]::Transparent
    $l1.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold)
    $l1.SetBounds(16, 12, ($w - 32), 26)

    $l2 = New-Object System.Windows.Forms.Label
    $l2.Text = ($BodyLines -join "`n")
    $l2.ForeColor = [System.Drawing.Color]::FromArgb(215, 215, 215)
    $l2.BackColor = [System.Drawing.Color]::Transparent
    $l2.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
    $l2.SetBounds(16, 44, ($w - 32), ($h - 56))

    $f.Controls.Add($l1)
    $f.Controls.Add($l2)

    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 12000
    $t.Add_Tick({ $f.Close() })
    $f.Add_Shown({ $t.Start() })
    $f.Show()
    [System.Windows.Forms.Application]::Run($f)
}

# ---------- 分支 1：有完整运行 -> 正常结果 ----------
if ($bestSeg) {
    $seg = $bestSeg
    function Get-Field($list, $pattern) {
        foreach ($l in $list) { if ($l -match $pattern) { return $Matches[1].Trim() } }
        return $null
    }
    $user = Get-Field $seg '【用户名】(.+)'
    $lv6  = Get-Field $seg '【距升级Lv6】(.+)'
    $coin = Get-Field $seg '【硬币余额】(.+)'

    $okN   = ($seg | Where-Object { $_ -match '√' -or ($_ -match '成功' -and $_ -notmatch '失败') }).Count
    $skipN = ($seg | Where-Object { $_ -match '跳过|不需要|不用再|不赠送|不是会员|余额不足|已完成|不用再投' }).Count
    $softN = ($seg | Where-Object { $_ -match '余额不足|不能重复签到|已签到|暂无可兑换' }).Count
    $failN = ($seg | Where-Object { $_ -match '失败' -and $_ -notmatch '不需要|不是|无会员|已领取' }).Count
    $failN = [math]::Max(0, $failN - $softN)

    $title = 'B站每日签到完成'
    if ($failN -gt 0) { $title = 'B站签到（有失败项）' }
    $body = @()
    if ($user) { $body += "账号：$user" }
    if ($coin) { $body += "硬币余额：$coin" }
    if ($lv6)  { $body += "距Lv6：$lv6" }
    $body += "成功 $okN 项 · 跳过 $skipN 项 · 失败 $failN 项"
    Send-Notify $title $body
    exit
}

# ---------- 分支 2：最近一次运行未完成 -> 异常通知 ----------
if ($lastStartRaw -and -not $lastStartEnded) {
    $cleanStart = $lastStartRaw -replace ' \[INF\] ', ' '
    Send-Notify 'B站签到运行异常' @(
        "最近一次运行（$cleanStart）未正常结束",
        '可能是网络中断、进程被终止或程序异常，请查看日志确认'
    )
    exit
}

# ---------- 分支 3：今天无运行 -> 静默退出 ----------
exit
