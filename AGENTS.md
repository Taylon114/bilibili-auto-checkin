# AGENTS.md（给后续维护者 / AI 助手的交接说明）

本仓库是 B 站每日签到的一套 Windows 部署脚本，给 BiliBiliToolPro 做封装。
改动前先读这份说明，能省很多排查时间。

## 仓库是什么

- 核心引擎是第三方的 `RayWangQvQ/BiliBiliToolPro`（MIT），**不入库**。
  用户按 README 自行下载 `win-x64` 包放到本目录，gitignore 已排除。
- 本仓库只含部署层的脚本：定时、开机自启、状态查看。

## 文件职责

| 文件 | 作用 |
|---|---|
| `run-daily.bat` | 每日入口：防重复锁 → 带看门狗跑任务 → 清日志 |
| `run-daily-hidden.vbs` | 隐藏启动（异步），开机自启用 |
| `run-daily-hidden-sync.vbs` | 隐藏启动（同步等待），计划任务用 |
| `status.ps1` / `status.bat` | 状态查看：进度、Lv6 倒计时、7 天记录 |
| `install-task.ps1` / `.cmd` | 计划任务安装（cmd 负责提权） |
| `task-daily.xml` | 计划任务模板，含 `__ROOT__`/`__DATE__` 占位符 |

## 容易踩的坑（都是实测过的）

1. **bat/cmd 必须是纯 ASCII + CRLF 换行。**
   系统是英文（OEM 码页 936/437 之外），文件里一旦有中文，cmd 会把 UTF-8 字节误读成命令运算符，整个脚本解析错乱。加注释只能用英文。
2. **ps1 必须是 UTF-8 带 BOM。**
   脚本跑在 Windows PowerShell 5.1 下，没 BOM 的 UTF-8 会被按 ANSI 读，中文全变乱码、正则匹配不上。任何编辑器改完都要重新加 BOM。
3. **tasklist 显示进程名会截断到 24 字符。**
   `Ray.BiliBiliTool.Console.exe` 显示为 `Ray.BiliBiliTool.Console.`（末尾多点），
   匹配要用子串（如 `find /i "BiliBiliTool"`），不能匹配完整 exe 名。
4. **`[math]::Min/Max` 带整数字面量会选错重载。**
   `[math]::Min(1, 0.94)` 会把 0.94 截断成 1。必须写 `1.0` / `0.0`。
5. **日志可能分多个文件。**
   两个实例并发写日志时，Serilog 会把后面的写到 `logYYYYMMDD_001.txt`。
   解析"最近一次运行"必须遍历当天所有 `log*.txt`，且只认"开始运行 → 运行结束"完整段落。
6. **`-replace` 是正则**，替换串里的 `$` 有特殊含义。替换路径用 `.Replace()`（install-task.ps1 里已示范）。
7. **PS 方法调用里逗号会拆参数。**
   `[Convert]::FromBase64String($x -replace "`n",'')` 会把 `-replace` 拆成两个参数，要加括号：`FromBase64String(($x -replace "`n",''))`。
8. **exe 的日志目录随启动方式变化（2026-08-15 实测踩过）。**
   计划任务的 WorkingDirectory 是仓库根目录时，exe 的相对日志路径 `Logs/log.txt` 会写到**上级 `Logs\`**，
   而不是 `win-x64\Logs\`，导致 status 找不到日志。
   已修复：watchdog 用 `-WorkingDirectory` 固定 exe 目录；status 同时扫描两个位置；
   部署版 appsettings 用绝对路径。**改启动链路时不要再破坏这条。**
9. **`run-daily.bat` 每一步都写 `%~dp0.bilitool-run.log` 追踪日志**，任务"报成功但没跑"时先看它。
10. **appsettings.json 里的 Windows 路径必须用正斜杠或双反斜杠（2026-08-16 实测踩过）。**
    这是 JSON 文件，单反斜杠 `F:\...` 是非法转义字符（`\P`/`\w`），会导致 exe 启动即崩溃
    （退出码 -532462766，日志里只见 project+banner、无任何任务的 `[INF]` 日志）。必须写
    `"path": "F:/Project/.../log.txt"` 或 `F:\\Project\\...`。exe 一启动读配置崩的排查
    先看 stdout 有无 `BiliBiliToolPro 开始运行` + stderr 有无 `JsonReaderException`。

## 怎么测试

- 本地跑 `status.ps1`（需要有 `win-x64\Logs` 下的日志，没有就造一条模拟数据）。
- 完整回归：在有 exe 的部署目录跑 `run-daily.bat`，确认"开始运行/运行结束"成对出现、
  进程零残留、`.bilitool-running.lock` 被清理。
- 日志错位回归：只在上层 `Logs\` 放今天的日志（`win-x64\Logs` 留空），`status.ps1` 应仍能显示。

## 约定

- 主分支 `main`，改动直接提交推送。
- 不提交：`cookies.json`、`Logs/`、`win-x64/`、`*.lock`（gitignore 已覆盖）。
- 变更记录写在 `CHANGELOG.md`。
