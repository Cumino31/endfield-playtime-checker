[CmdletBinding()]
param(
    [string]$CustomPath,
    [switch]$ExportJson,
    [switch]$ExportCsv
)

& {
    Write-Host "`n──────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  终末地游玩时长统计 | endfield-playtime-checker (国服版)" -ForegroundColor White
    Write-Host "──────────────────────────────────────────────────" -ForegroundColor DarkGray

    Write-Host "`n[i] 正在扫描《明日方舟：终末地》日志..." -ForegroundColor Gray

    $user = $env:USERNAME
    $searchPaths = [System.Collections.Generic.List[string]]::new()

    if ($CustomPath) {
        $searchPaths.Add($CustomPath)
    }

    $searchPaths.Add("C:\Users\$user\AppData\LocalLow\Hypergryph\Endfield\sdklogs")
    $searchPaths.Add("C:\Users\$user\AppData\LocalLow\Hypergryph\Endfield")
    $searchPaths.Add("C:\Users\$user\AppData\LocalLow\Hypergryph")

    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $root = $_.Root
        $searchPaths.Add("${root}Hypergryph")
        $searchPaths.Add("${root}Games\Hypergryph")
        $searchPaths.Add("${root}Program Files\Hypergryph")
    }

    $files = @()
    foreach ($path in $searchPaths) {
        if ($path -and (Test-Path $path)) {
            $files += Get-ChildItem -Path $path -Filter "games*.log" -Recurse -ErrorAction SilentlyContinue
            $files += Get-ChildItem -Path $path -Filter "sdk*.log"   -Recurse -ErrorAction SilentlyContinue
        }
    }

    $files = $files | Sort-Object FullName -Unique
    if (-not $files) {
        Write-Host "[x] 未找到日志文件。" -ForegroundColor Red
        Write-Host "    自动扫描路径: C:\Users\$user\AppData\LocalLow\Hypergryph\Endfield\sdklogs" -ForegroundColor DarkGray
        Write-Host "    可用 -CustomPath 'C:\完整路径' 手动指定。" -ForegroundColor DarkGray
        Write-Host "`n按任意键退出..." -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $sessions = [System.Collections.Generic.List[PSCustomObject]]::new()
    $globalYear = [DateTime]::Now.Year

    $totalFiles = $files.Count
    $currentFileIndex = 0

    foreach ($file in $files) {
        $currentFileIndex++
        $percent = [math]::Round(($currentFileIndex / $totalFiles) * 100)
        $filled = [math]::Round($percent / 5)
        $empty = 20 - $filled
        $barProg = ("=" * $filled) + ("-" * $empty)

        Write-Host -NoNewline "`r[>] 解析日志: [$barProg] $percent% ($currentFileIndex/$totalFiles) - $($file.Name)" -ForegroundColor Gray

        try {
            $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $reader = [System.IO.StreamReader]::new($stream)
            $start = $null
            $fileYear = $globalYear
            $lastMonth = 0

            while ($null -ne ($line = $reader.ReadLine())) {
                if ($line.Length -lt 12) { continue }

                if ($line -match 'enter main|create game process|OnGameStart|Game started|Session start|PlayerSession|LogGameMode') {
                    $raw = $line.Substring(1, 11)

                    $month = [int]$raw.Substring(0, 2)
                    if ($lastMonth -eq 12 -and $month -eq 1) { $fileYear++ }
                    $lastMonth = $month

                    $start = try {
                        [DateTime]::new(
                            $fileYear,
                            $month,
                            [int]$raw.Substring(3, 2),
                            [int]$raw.Substring(6, 2),
                            [int]$raw.Substring(9, 2),
                            0
                        )
                    } catch {}
                }
                elseif ($start -and ($line -match 'OnAppAboutToQuit|Child process exits|leave main|Game shutdown|Session ended')) {
                    $raw = $line.Substring(1, 11)
                    $end = try {
                        [DateTime]::new(
                            $fileYear,
                            [int]$raw.Substring(0, 2),
                            [int]$raw.Substring(3, 2),
                            [int]$raw.Substring(6, 2),
                            [int]$raw.Substring(9, 2),
                            0
                        )
                    } catch {}
                    if ($end) {
                        if ($end -lt $start) { $end = $end.AddDays(1) }
                        $mins = ($end - $start).TotalMinutes
                        if ($mins -ge 1) {
                            $sessions.Add([PSCustomObject]@{
                                Start = $start
                                End = $end
                                Duration = ($end - $start)
                                Mins = $mins
                            })
                        }
                    }
                    $start = $null
                }
            }
        } catch {} finally {
            if ($reader) { $reader.Dispose() }
            if ($stream) { $stream.Dispose() }
        }
    }
    Write-Host ""

    if ($sessions.Count -eq 0) {
        Write-Host "[x] 在日志中未找到有效会话数据。" -ForegroundColor Yellow
        Write-Host "    找到的日志文件：" -ForegroundColor DarkGray
        $files | ForEach-Object { Write-Host "    - $($_.FullName)" -ForegroundColor DarkGray }
        Write-Host "`n按任意键退出..." -ForegroundColor Gray
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    $totalMins = ($sessions | Measure-Object Mins -Sum).Sum
    $totalSpan = [TimeSpan]::FromMinutes($totalMins)
    $uniqueDays = $sessions | Group-Object { $_.Start.ToString('yyyy-MM-dd') } | Sort-Object Name
    $sortedSess = $sessions | Sort-Object Mins

    $streak = $maxStreak = 0; $prev = $null
    foreach ($d in $uniqueDays) {
        $curr = [DateTime]::Parse($d.Name)
        $streak = if ($prev -and $curr -eq $prev.AddDays(1)) { $streak + 1 } else { 1 }
        if ($streak -gt $maxStreak) { $maxStreak = $streak }
        $prev = $curr
    }

    if ($ExportJson) {
        $sessions | ConvertTo-Json | Out-File "endfield_stats.json" -Encoding utf8
        Write-Host "[+] 已导出到 endfield_stats.json" -ForegroundColor Green
    }
    if ($ExportCsv) {
        $sessions | Export-Csv -Path "endfield_stats.csv" -NoTypeInformation -Encoding utf8
        Write-Host "[+] 已导出到 endfield_stats.csv" -ForegroundColor Green
    }

    Write-Host "`n────────────────[ 总体统计 ]────────────────" -ForegroundColor DarkGray
    Write-Host " > 总游玩时长：" -NoNewline; Write-Host "$([math]::Floor($totalSpan.TotalHours))h $($totalSpan.Minutes)m" -ForegroundColor Green
    Write-Host " > 总会话数：$($sessions.Count)" -ForegroundColor Gray
    Write-Host " > 活跃天数：$($uniqueDays.Count)" -ForegroundColor Gray
    Write-Host " > 最长连续登录：$maxStreak 天" -ForegroundColor Yellow
    Write-Host " > 平均单次时长：" -NoNewline; Write-Host "$([math]::Floor(($totalMins / $sessions.Count) / 60))h $([math]::Round(($totalMins / $sessions.Count) % 60))m" -ForegroundColor Green

    Write-Host "`n────────────────[ 会话记录 ]────────────────" -ForegroundColor DarkGray
    Write-Host " > 最长一次：" -NoNewline; Write-Host "$([math]::Floor($sortedSess[-1].Duration.TotalHours))h $($sortedSess[-1].Duration.Minutes)m" -ForegroundColor Green -NoNewline; Write-Host "  (日期：$($sortedSess[-1].Start.ToString('yyyy-MM-dd')))" -ForegroundColor Gray
    Write-Host " > 最短一次：" -NoNewline; Write-Host "$($sortedSess[0].Duration.Minutes)m" -ForegroundColor Green -NoNewline; Write-Host "  (日期：$($sortedSess[0].Start.ToString('yyyy-MM-dd')))" -ForegroundColor Gray

    Write-Host "`n────────────────[ 游玩习惯 ]────────────────" -ForegroundColor DarkGray
    $nightMins = ($sessions | Where-Object { $_.Start.Hour -ge 22 -or $_.Start.Hour -lt 6 } | Measure-Object Mins -Sum).Sum
    $nightPct = if ($totalMins -gt 0) { [math]::Round(($nightMins / $totalMins) * 100) } else { 0 }
    Write-Host " > 夜间游玩 (22-06 开始)：占 $nightPct% 时长" -ForegroundColor Gray
    Write-Host " > 日间游玩：占 $(100 - $nightPct)% 时长" -ForegroundColor Gray
    Write-Host " > 速览 (<30 分钟)：$($sessions | Where-Object Mins -lt 30 | Measure-Object | Select-Object -ExpandProperty Count) 次" -ForegroundColor Gray
    Write-Host " > 标准 (30 分钟 - 3 小时)：$($sessions | Where-Object { $_.Mins -ge 30 -and $_.Mins -le 180 } | Measure-Object | Select-Object -ExpandProperty Count) 次" -ForegroundColor Gray
    Write-Host " > 马拉松 (>3 小时)：$($sessions | Where-Object Mins -gt 180 | Measure-Object | Select-Object -ExpandProperty Count) 次" -ForegroundColor Gray

    Write-Host "`n────────────────[ 启动时段分布 ]────────────────" -ForegroundColor DarkGray
    Write-Host " > 按一天中的小时统计游戏启动次数 (00:00 - 23:00)" -ForegroundColor Gray
    $hourly = 0..23 | Select-Object @{N='Hour';E={$_}}, @{N='Count';E={ $h=$_; ($sessions | Where-Object { $_.Start.Hour -eq $h }).Count }}
    $maxCount = ($hourly | Measure-Object Count -Max).Maximum

    foreach ($h in $hourly) {
        $barLen = if ($maxCount -gt 0) { [math]::Round(($h.Count / $maxCount) * 20) } else { 0 }
        $bar = "■" * $barLen
        $hourStr = "{0:D2}:00" -f $h.Hour
        $countStr = "{0,2}" -f $h.Count
        Write-Host " $hourStr │ " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($bar.PadRight(20))" -NoNewline -ForegroundColor Cyan
        Write-Host " │ " -NoNewline -ForegroundColor DarkGray
        Write-Host "$countStr" -ForegroundColor DarkGray
    }

    Write-Host "`n────────────────[ 按星期统计 ]────────────────" -ForegroundColor DarkGray
    $dayNames = [ordered]@{
        Monday = '星期一'; Tuesday = '星期二'; Wednesday = '星期三'; Thursday = '星期四'
        Friday = '星期五'; Saturday = '星期六'; Sunday = '星期日'
    }
    foreach ($day in $dayNames.Keys) {
        $dMins = ($sessions | Where-Object { $_.Start.DayOfWeek -eq $day } | Measure-Object Mins -Sum).Sum
        if ($dMins) {
            $span = [TimeSpan]::FromMinutes($dMins)
            Write-Host " > $($dayNames[$day])：" -NoNewline -ForegroundColor Gray
            Write-Host "$([math]::Floor($span.TotalHours))h $($span.Minutes)m" -ForegroundColor Green
        }
    }

    Write-Host "`n────────────────[ 按月统计 ]────────────────" -ForegroundColor DarkGray
    $sessions | Group-Object { $_.Start.ToString('yyyy-MM') } | Sort-Object Name | ForEach-Object {
        $mMins = ($_.Group | Measure-Object Mins -Sum).Sum
        $span = [TimeSpan]::FromMinutes($mMins)
        $monthLabel = ([DateTime]::ParseExact($_.Name, 'yyyy-MM', [System.Globalization.CultureInfo]::InvariantCulture)).ToString('yyyy年MM月')
        Write-Host " > ${monthLabel}：" -NoNewline -ForegroundColor Gray
        Write-Host "$([math]::Floor($span.TotalHours))h $($span.Minutes)m" -ForegroundColor Green
    }
    Write-Host "────────────────────────────────────────────" -ForegroundColor DarkGray

    Write-Host "`n────────────────[ 按日期查询记录 ]────────────────" -ForegroundColor DarkGray
    Write-Host " 输入日期查看当天详细游玩记录，直接回车退出。" -ForegroundColor Gray
    Write-Host " 格式：yyyy-MM-dd　例：2026-09-02" -ForegroundColor DarkGray

    while ($true) {
        Write-Host "`n > 请输入日期: " -NoNewline -ForegroundColor Gray
        $dateInput = Read-Host

        if ([string]::IsNullOrWhiteSpace($dateInput)) { break }

        $queryDate = [DateTime]::MinValue
        $parsed = [DateTime]::TryParseExact(
            $dateInput.Trim(),
            'yyyy-MM-dd',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$queryDate
        )

        if (-not $parsed) {
            Write-Host " [!] 格式不正确，请使用 yyyy-MM-dd（例：2026-09-02）" -ForegroundColor Red
            continue
        }

        $daySessions = @($sessions | Where-Object { $_.Start.Date -eq $queryDate.Date } | Sort-Object Start)

        if ($daySessions.Count -eq 0) {
            Write-Host " [!] $dateInput 没有找到游玩记录。" -ForegroundColor Yellow
            continue
        }

        $dayTotal = ($daySessions | Measure-Object Mins -Sum).Sum
        $daySpan = [TimeSpan]::FromMinutes($dayTotal)

        Write-Host "`n [$dateInput]  共 $($daySessions.Count) 条记录  合计 $([math]::Floor($daySpan.TotalHours))h $($daySpan.Minutes)m" -ForegroundColor Cyan
        Write-Host " ──────────────────────────────────────────────" -ForegroundColor DarkGray

        $i = 1
        foreach ($s in $daySessions) {
            $durStr = if ($s.Duration.TotalHours -ge 1) {
                "$([math]::Floor($s.Duration.TotalHours))h $($s.Duration.Minutes)m"
            } else {
                "$($s.Duration.Minutes)m"
            }
            Write-Host ("  #{0,-3}" -f $i) -NoNewline -ForegroundColor DarkGray
            Write-Host "$($s.Start.ToString('HH:mm'))" -NoNewline -ForegroundColor Green
            Write-Host " → " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($s.End.ToString('HH:mm'))" -NoNewline -ForegroundColor Green
            Write-Host "  [$durStr]" -ForegroundColor Gray
            $i++
        }
    }

    Write-Host "`n按任意键退出..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
