# ============================================================
#  BiliBiliToolPro 计划任务安装器
#  用法：以管理员身份运行 install-task.cmd（本脚本由它调用）
#  功能：注册每天 08:30 的计划任务
#        - 错过后自动补跑 (StartWhenAvailable)
#        - 最长执行 1 小时 (ExecutionTimeLimit)
#  路径基于脚本自身位置解析（可移植）
# ============================================================
$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$taskName = 'BiliBiliToolPro-Daily'
$xmlTemplate = Join-Path $base 'task-daily.xml'

Write-Host '============================================'
Write-Host '  安装 B站每日自动签到计划任务'
Write-Host '============================================'
Write-Host ''
Write-Host ('基础目录: ' + $base)

if (-not (Test-Path $xmlTemplate)) {
    Write-Host '[错误] 未找到 task-daily.xml 模板'
    Read-Host '按回车键退出'
    exit 1
}

# 占位符替换：__ROOT__ -> 实际目录；__DATE__ -> 明天 08:30
# 注意：必须用字面 .Replace()（-replace 是正则，路径含 $ 等字符会出错）
$startDate = (Get-Date).AddDays(1).ToString('yyyy-MM-ddT08:30:00')
$xml = Get-Content $xmlTemplate -Raw -Encoding Unicode
$xml = $xml.Replace('__ROOT__', $base).Replace('__DATE__', $startDate)

$ok = $false

# 方案一：Task Scheduler COM（支持完整设置）
try {
    $s = New-Object -ComObject Schedule.Service
    $s.Connect()
    $folder = $s.GetFolder('\')
    $task = $s.NewTask(0)
    $task.XmlText = $xml
    $folder.RegisterTaskDefinition($taskName, $task, 6, $null, $null, 3)
    Write-Host '[OK] 计划任务已注册（COM 方式）'
    $ok = $true
} catch {
    Write-Host ('[警告] COM 方式失败: ' + $_.Exception.Message)
}

# 方案二：schtasks /XML（回退）
if (-not $ok) {
    try {
        $tmpXml = Join-Path $env:TEMP 'bilitool-task.xml'
        [System.IO.File]::WriteAllText($tmpXml, $xml, (New-Object System.Text.UnicodeEncoding $false, $true))
        & schtasks /Create /F /TN $taskName /XML $tmpXml
        Remove-Item $tmpXml -Force -ErrorAction SilentlyContinue
        Write-Host '[OK] 计划任务已注册（schtasks 方式）'
        $ok = $true
    } catch {
        Write-Host ('[错误] schtasks 方式也失败: ' + $_.Exception.Message)
    }
}

if ($ok) {
    Write-Host ''
    Write-Host '验证结果：'
    & schtasks /Query /TN $taskName /V /FO LIST 2>&1 |
        Select-String -Pattern 'TaskName|Next Run|Status|Task To Run|Schedule Type' |
        ForEach-Object { Write-Host ('  ' + $_.Line.Trim()) }
} else {
    Write-Host ''
    Write-Host '[错误] 安装失败，请以管理员身份重试。'
}

Write-Host ''
Read-Host '按回车键退出'
