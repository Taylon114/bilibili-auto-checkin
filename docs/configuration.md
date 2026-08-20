# 配置说明

核心配置都在 `win-x64\appsettings.json`（格式由 BiliBiliToolPro 定义，本套件不改动）。

## 常用项

### 每日任务 `DailyTaskConfig`

```json
"DailyTaskConfig": {
  "IsEnable": true,              // 总开关
  "IsWatchVideo": true,          // 观看视频
  "IsShareVideo": true,          // 分享视频
  "NumberOfCoins": 5,            // 每日投币数 [0,5]，0 表示不投
  "NumberOfProtectedCoins": 0,   // 保留硬币数
  "SaveCoinsWhenLv6": false,     // 升到 Lv6 后停投（白嫖模式）
  "SelectLike": true,            // 投币时同时点赞
  "SupportUpIds": "",            // 指定 UP 主 Id，逗号分隔；留空则随机
  "DevicePlatform": "android"    // 模拟平台 [ios, android]
}
```

### 请求间隔（影响耗时）

```json
"Security": {
  "IntervalSecondsBetweenRequestApi": 5,  // 两次 API 调用间隔（秒）
  "RandomSleepMaxMin": 0                 // 随机延迟（分钟），0 为不延迟
}
```

默认 5 秒，全程 1~3 分钟。怕被风控就调回 20 秒，想更快调到 2~3 秒。

### 任务开关

各任务配置里的 `IsEnable` 控制是否参与，比如 `MangaTaskConfig`、`Silver2CoinTaskConfig`。关掉后 `run-daily.bat` 里对应任务自动跳过。

## 通知

已移除通知功能，脚本静默运行。查看结果请使用 `status.bat`。

## 日志与缓存

| 内容 | 位置 | 说明 |
|---|---|---|
| 运行日志 | `win-x64\Logs\`（异常启动方式下可能在上级 `Logs\`） | 每天约 10KB，30 天后自动删 |
| 登录凭据 | `win-x64\cookies.json` | 必要保留，别外传 |
| 锁文件 | `.bilitool-running.lock` | 防重复用，跑完自动删 |
| 运行追踪 | `.bilitool-run.log` | 每次运行各步骤记录，排查用 |

## 性能

每天运行一次，1~3 分钟，跑完退出。没有后台进程，也不常驻网络连接。
