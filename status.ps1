# ============================================================
#  每日状态查看器：双击 status.bat 或 powershell -File status.ps1
# ============================================================
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$base = $PSScriptRoot
$base = $PSScriptRoot
# 日志路径随 exe 的工作目录变化：可能在 win-x64\Logs，也可能在上级 Logs，两个都查
$logDirs = @(
  (Join-Path (Join-Path $base 'win-x64') 'Logs'),
  (Join-Path $base 'Logs')
) | Where-Object { Test-Path $_ }
if (-not $logDirs) { Write-Host '未找到日志目录（任务还没运行过？）'; exit }

$today = Get-Date -Format 'yyyyMMdd'
$files = @()
foreach ($d in $logDirs) { $files += Get-ChildItem $d -Filter "log$today*.txt" -ErrorAction SilentlyContinue }
$files = $files | Sort-Object LastWriteTime
if (-not $files) {
  foreach ($d in $logDirs) { $files += Get-ChildItem $d -Filter 'log*.txt' -ErrorAction SilentlyContinue }
  $files = $files | Sort-Object LastWriteTime
}
if (-not $files) { Write-Host '未找到日志文件'; exit }

# ---------- 提取"最近一次完整运行"（支持日志分文件） ----------
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

Write-Host ''
Write-Host '════════════════════════════════════════════════════'
Write-Host '   B站自动签到 · 状态报告'
Write-Host '════════════════════════════════════════════════════'

if (-not $bestSeg -and -not $lastStartRaw) {
    Write-Host '  日志中暂无运行记录，任务可能尚未执行。'
    exit
}
if (-not $lastStartEnded) {
    $warnStart = $lastStartRaw -replace ' \[INF\] ', ' '
    Write-Host '  ⚠ 警告：最近一次运行未正常结束！'
    Write-Host ('     开始于: ' + $warnStart)
    Write-Host '     可能是网络中断/进程被终止，请查看日志确认。'
    Write-Host ''
}
if (-not $bestSeg) { exit }
$seg = $bestSeg

function Get-Field($list, $pattern) {
    foreach ($l in $list) { if ($l -match $pattern) { return $Matches[1].Trim() } }
    return $null
}

$user   = Get-Field $seg '【用户名】(.+)'
$member = Get-Field $seg '【会员类型】(.+)'
$mstat  = Get-Field $seg '【会员状态】(.+)'
$coin   = Get-Field $seg '【硬币余额】(.+)'
$lv6    = Get-Field $seg '【距升级Lv6】(.+)'

$runStart = ($seg | Where-Object { $_ -match '开始运行' } | Select-Object -First 1)
$runEnd   = ($seg | Where-Object { $_ -match '运行结束' } | Select-Object -Last 1)

Write-Host ''
Write-Host '【最近一次运行】'
Write-Host ('  开始时间 : ' + $runStart)
Write-Host ('  结束时间 : ' + $(if ($runEnd) { $runEnd } else { '（进行中…）' }))
Write-Host ('  账号     : ' + $(if ($user) { $user } else { '?' }))
Write-Host ('  会员     : ' + $(if ($member) { $member } else { '?' }) + '  （状态：' + $(if ($mstat) { $mstat } else { '?' }) + '）')
Write-Host ('  硬币余额 : ' + $(if ($coin) { $coin } else { '?' }))

# ---------- Lv6 倒计时 ----------
Write-Host ''
Write-Host '【升级倒计时】'
if ($lv6 -and $lv6 -match '(\d+)') {
    $days = [int]$Matches[1]
    $target = (Get-Date).AddDays($days)
    Write-Host ('  距升级Lv6 : ' + $lv6 + '（预计 ' + $target.ToString('yyyy-MM-dd') + ' 达成）')
    # 进度条：Lv5→Lv6 共需约18000经验，每日最多65经验
    $progress = 1 - ($days * 65.0 / 18000)
    $bar = [int](20 * [math]::Max(0.0, [math]::Min(1.0, $progress)))
    Write-Host ('  进度示意  : [' + ('█' * $bar) + ('░' * (20 - $bar)) + ']  Lv5 → Lv6')
} else {
    Write-Host '  距升级Lv6 : 日志中暂无数据（可能需要再跑一次任务）'
}

# ---------- 本次任务明细 ----------
Write-Host ''
Write-Host '【任务明细（本次运行）】'
$show = $seg | Where-Object {
    $_ -match '=====开始' -or $_ -match '√' -or $_ -match '失败' -or
    $_ -match '【签到结果】' -or $_ -match '【原因】' -or $_ -match '跳过' -or $_ -match '运行结束'
}
$okN   = ($seg | Where-Object { $_ -match '√' -or ($_ -match '成功' -and $_ -notmatch '失败') }).Count
$skipN = ($seg | Where-Object { $_ -match '跳过|不需要|不用再|不赠送|不是会员|余额不足|已完成|不用再投' }).Count
$softN = ($seg | Where-Object { $_ -match '余额不足|不能重复签到|已签到|暂无可兑换' }).Count
$failN = ($seg | Where-Object { $_ -match '失败' -and $_ -notmatch '不需要|不是|无会员|已领取' }).Count
$failN = [math]::Max(0, $failN - $softN)
foreach ($t in $show) { Write-Host ('  ' + $t) }
Write-Host ''
Write-Host ('  统计: 成功 ' + $okN + ' 项 · 跳过 ' + $skipN + ' 项 · 失败 ' + $failN + ' 项')
Write-Host '  说明: 跳过=今日已完成或条件不满足(如银瓜子余额不足)，属正常'

# ---------- 最近 7 天运行历史（按天聚合） ----------
Write-Host ''
Write-Host '【最近 7 天运行记录】'
$allFiles = @()
foreach ($d in $logDirs) { $allFiles += Get-ChildItem $d -Filter 'log*.txt' -ErrorAction SilentlyContinue }
$allFiles = $allFiles | Sort-Object Name -Descending
$days = @{}
foreach ($f in $allFiles) {
    if ($f.Name -match '^log(\d{4})(\d{2})(\d{2})') {
        $d = '{0}-{1}-{2}' -f $Matches[1], $Matches[2], $Matches[3]
        if (-not $days.ContainsKey($d)) { $days[$d] = @{ Runs = 0; Last = '' } }
        $fl = Get-Content $f.FullName -Encoding UTF8
        $starts = @($fl | Where-Object { $_ -match '开始运行' })
        $days[$d].Runs += $starts.Count
        foreach ($s in $starts) { if ($s -gt $days[$d].Last) { $days[$d].Last = $s } }
    }
}
$days.GetEnumerator() | Sort-Object Name -Descending | Select-Object -First 7 | ForEach-Object {
    $d = $_.Key; $info = $_.Value
    $last = $info.Last -replace ' \[INF\] ', ' '
    if ($info.Runs -gt 0) {
        Write-Host ('  {0}  运行 {1} 次  最近: {2}' -f $d, $info.Runs, $last)
    } else {
        Write-Host ('  {0}  无运行记录' -f $d)
    }
}
Write-Host ''
Write-Host ('提示：完整详细日志见 ' + ($logDirs -join ' 或 ') + ' 下的 log' + $today + '*.txt')
Write-Host ''
