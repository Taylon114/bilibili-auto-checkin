# 部署教程

这套脚本根据自身所在位置解析路径，放在哪个目录都能用。

## 1. 放好 BiliBiliToolPro

去 [BiliBiliToolPro Releases](https://github.com/RayWangQvQ/BiliBiliToolPro/releases) 下载 `bilibili-tool-pro-vX.Y.Z-win-x64.zip`（Windows 自包含版，不用装 .NET），解压后把 `win-x64` 文件夹整个放到本目录，最终结构：

```
你的目录/
├── win-x64/
│   ├── Ray.BiliBiliTool.Console.exe
│   ├── appsettings.json
│   └── ...
├── run-daily.bat
├── install-task.cmd
└── ...
```

## 2. 扫码登录

在命令行进入 `win-x64` 目录：

```
Ray.BiliBiliTool.Console.exe --runTasks=Login
```

用 B 站手机 App 扫弹出的二维码（我的 → 扫一扫）。登录成功后会生成 `win-x64\cookies.json`（登录凭据，别外传）。二维码大约 3 分钟有效，过期重跑一次即可。

## 3. 安装计划任务（推荐）

双击 `install-task.cmd`，首次会弹 UAC 请求管理员权限。装好后任务 `BiliBiliToolPro-Daily` 每天 08:30 执行，特性：

- 08:30 电脑没开机 → 下次登录后自动补跑
- 单次最长执行 1 小时，异常会被终止
- 和开机自启同时触发时，只跑一次

验证：`Win+R` 输入 `taskschd.msc`，任务计划程序库里找 `BiliBiliToolPro-Daily`。

## 4. 开机自启（备选）

不用计划任务的话，把 `run-daily-hidden.vbs` 复制到启动文件夹：

`Win+R` → 输入 `shell:startup` → 回车，把文件粘进去。

每次开机登录后自动签到（任务幂等，重复触发没有副作用）。

## 5. 验证

- 双击 `status.bat` 看状态和 Lv6 倒计时
- 日志在 `win-x64\Logs\logYYYYMMDD.txt`，每天 10KB 左右
- 每次运行结束右下角弹通知

## 6. 升级

1. 备份 `win-x64\cookies.json`
2. 用新版替换 `win-x64` 文件夹
3. 放回 `cookies.json`，不用重新扫码
