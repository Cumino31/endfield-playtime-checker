# 终末地游玩时长统计 | Arknights: Endfield Playtime Checker (CN)

一个轻量的 PowerShell 脚本，读取《明日方舟：终末地》**国服（Hypergryph）**的本地游戏日志，统计总游玩时长、每次会话记录和连续登录天数，并支持按日期查询当天的详细记录。

> 本项目基于 **[endfield-playtime-checker](https://github.com/genrusaii/endfield-playtime-checker)** 修改而来，感谢原作者。修改过程中使用了Claude-Sonnet 5.5
> 原版面向国际服（Gryphline），本版本调整为国服路径并中文化，同时新增了"按日期查询"功能。

## 特点

- **性能优化**：使用 .NET StreamReader 逐行读取，解析大体积日志也很快，不占内存（不同于基于 `Get-Content` 的简易脚本）。
- **隐私优先**：脚本完全在本地运行，不联网，不上传任何数据，你可以逐行审查代码。
- **按日期查询**（新增）：输入 `yyyy-MM-dd`，查看当天每一次游玩的起止时间和时长。

## 使用方法

1. 打开 **PowerShell**（按 `Win + X`，选择 **终端** 或 **PowerShell**）。
2. 复制整份 `script.ps1` 的代码，粘贴到 PowerShell 窗口，按 **回车**。
3. 在控制台查看统计结果；末尾可输入日期查询当天记录，直接回车退出。

可选参数（粘贴方式不支持传参，需要先保存为文件再运行）：

```powershell
.\script.ps1 -CustomPath "D:\Games\Hypergryph"   # 手动指定日志目录
.\script.ps1 -ExportCsv -ExportJson               # 导出会话数据
```

> 如果把脚本保存为文件运行，请确保文件编码为 **UTF-8 with BOM**，否则 Windows 自带的 PowerShell 5.1 可能会把中文显示成乱码。

## 默认扫描位置

- `C:\Users\<用户名>\AppData\LocalLow\Hypergryph\...`
- 各磁盘根目录下的 `Hypergryph`、`Games\Hypergryph`、`Program Files\Hypergryph`

匹配 `games*.log` 与 `sdk*.log`。

## 已知限制

- 脚本按日志文件累计时长，**不区分账号**；同一台电脑上多个账号的时长会合并在一起。
- 时间精度为分钟；短于 1 分钟的会话会被忽略。
- 日志格式可能随游戏版本更新而变化，若统计结果异常，欢迎提 Issue。



## English

A lightweight PowerShell script that reads the local logs of **Arknights: Endfield (CN server / Hypergryph)** and reports total playtime, session history, activity streaks, and a per-date session lookup.

Based on **[endfield-playtime-checker](https://github.com/genrusaii/endfield-playtime-checker)**(international server / Gryphline). This fork changes the log paths to the CN server, localizes the output to Chinese, and adds the per-date query.

**Usage:** open PowerShell, paste the whole `script.ps1`, press Enter. Runs entirely locally; no data leaves your machine.

**Limitations:** sessions from multiple accounts on the same PC are merged; minute-level precision only.
