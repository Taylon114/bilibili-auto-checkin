# bilibili-auto-checkin

B 站每日自动签到的一套 Windows 部署脚本。核心引擎用 [BiliBiliToolPro](https://github.com/RayWangQvQ/BiliBiliToolPro)（MIT），本仓库负责把"定时、开机自启、状态查看、结果通知"这些周边事情包好，省得每次手动跑。

扫码登录一次，之后每天到点自动执行，跑完右下角弹个结果，想细看就双击 `status.bat`。

## 功能

- 每天 08:30 自动执行全部签到任务；当时没开机的话，开机后自动补跑
- 可选开机自启（复制一个 vbs 到启动文件夹即可）
- 结果通知：优先系统通知，系统通知被关掉时改用自绘窗口，反正能看见
- `status.bat` 看当天进度、距 Lv6 还有几天、最近 7 天记录
- 防重复：计划任务和开机自启同时触发也不会跑两遍
- 日志每天 10KB 左右，超过 30 天自动清理
- 跑完即退出，无常驻进程

## 部署

1. 从 [BiliBiliToolPro Releases](https://github.com/RayWangQvQ/BiliBiliToolPro/releases) 下载 `win-x64` 包，解压后把 `win-x64` 文件夹放到本目录下（与 `run-daily.bat` 同级）
2. 运行 `win-x64\Ray.BiliBiliTool.Console.exe --runTasks=Login`，用 B 站手机 App 扫码
3. 双击 `install-task.cmd`（会自动请求管理员权限），装好每天 08:30 的计划任务

不想用计划任务的话，把 `run-daily-hidden.vbs` 复制到启动文件夹（`Win+R` 输入 `shell:startup`）即可。

详细步骤见 [docs/deploy.md](docs/deploy.md)，配置说明见 [docs/configuration.md](docs/configuration.md)。

## 目录结构

```
├── win-x64/                  BiliBiliToolPro 程序（自行下载，不入库）
├── run-daily.bat             每日执行入口（防重复 + 日志清理）
├── run-daily-hidden.vbs      隐藏启动，开机自启用
├── run-daily-hidden-sync.vbs 隐藏同步启动，计划任务用
├── notify.ps1                结果通知（Toast 失败自动换自绘窗口）
├── status.ps1 / status.bat   状态查看
├── install-task.cmd / .ps1   计划任务安装（自动提权）
├── task-daily.xml            计划任务模板
└── docs/                     文档
```

## 常见问题

**为什么有时候显示"失败 1 项（漫画签到）"？**
当天已经签过到、又跑了一次，B 站返回"不能重复签到"，工具会把这个情况标成失败。正常每天只跑一次不会出现。

**通知弹不出来？**
脚本会检测系统通知开关，关了就用自绘窗口，跟系统设置无关。

**8:30 没开机怎么办？**
计划任务配了"错过后尽快补跑"，开机就补；另外还有开机自启兜底。

**Cookie 过期了？**
重新跑一次 `win-x64\Ray.BiliBiliTool.Console.exe --runTasks=Login` 扫码。

## 免责声明

仅供学习交流，请勿滥用，使用后果自负。

## 致谢

核心引擎 [RayWangQvQ/BiliBiliToolPro](https://github.com/RayWangQvQ/BiliBiliToolPro)（MIT）。接口文档参考 [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)。

## License

[MIT](LICENSE)
