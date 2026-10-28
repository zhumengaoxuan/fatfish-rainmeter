# anime.ps1 —— 抓 yuc.wiki 当季番剧表，写 @Resources\anime.txt（GBK）
# 用法：powershell -ExecutionPolicy Bypass -File anime.ps1 [-Day 周一]
param(
    [string]$Day = ""
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outFile = Join-Path $root 'anime.txt'

function Log($msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    [IO.File]::AppendAllText((Join-Path $root 'anime.log'), $line + "`r`n", [Text.Encoding]::GetEncoding(936))
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if ($Day -eq "") {
        $dow = @('周日','周一','周二','周三','周四','周五','周六')[[int](Get-Date).DayOfWeek]
        $Day = $dow
    }

    # 当季页面：本月；抓不到就试下个月（换季边界）
    $now = Get-Date
    $candidates = @(
        $now.ToString('yyyyMM'),
        $now.AddMonths(1).ToString('yyyyMM'),
        $now.AddMonths(-1).ToString('yyyyMM')
    )

    $html = $null
    $usedUrl = $null
    foreach ($ym in $candidates) {
        $url = "https://yuc.wiki/$ym/"
        try {
            $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -Headers @{ 'User-Agent' = 'Mozilla/5.0' }
            if ($r.StatusCode -eq 200 -and $r.Content.Length -gt 5000) {
                $html = $r.Content
                $usedUrl = $url
                break
            }
        } catch {
            continue
        }
    }
    if (-not $html) { Log "ERR 页面抓取失败"; exit 1 }

    # 定位当天段落：<!--周一--> … 下一个 <!--周X-->
    $marker = "<!--$Day-->"
    $start = $html.IndexOf($marker)
    if ($start -lt 0) { Log "ERR 未找到 $Day 段落"; exit 1 }

    $rest = $html.Substring($start)
    $nextIdx = [int]::MaxValue
    foreach ($d in @('周一','周二','周三','周四','周五','周六','周日')) {
        if ($d -eq $Day) { continue }
        $p = $rest.IndexOf("<!--$d-->")
        if ($p -gt 0 -and $p -lt $nextIdx) { $nextIdx = $p }
    }
    if ($nextIdx -eq [int]::MaxValue) { $section = $rest } else { $section = $rest.Substring(0, $nextIdx) }

    # 逐个条目：时间 + 开播日 + 标题
    $pattern = '(?s)<p class="imgtext4">(?<time>[^<]+)</p>\s*<p class="imgep">(?<date>[^<]*)</p>.*?class="date_title_[^"]*">(?<title>.*?)</td>'
    $rows = [regex]::Matches($section, $pattern)
    if ($rows.Count -eq 0) { Log "ERR $Day 无条目"; exit 1 }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("#date " + (Get-Date -Format 'yyyy-MM-dd'))
    $lines.Add("#src $usedUrl")
    foreach ($m in $rows) {
        $t = $m.Groups['time'].Value.Trim() -replace '~$',''
        $title = $m.Groups['title'].Value
        $title = $title -replace '(?i)<br\s*/?>', ' '
        $title = $title -replace '<[^>]+>', ''
        $title = [System.Net.WebUtility]::HtmlDecode($title)
        $title = ($title -replace '\s+', ' ').Trim()
        if ($title -eq '') { continue }
        $lines.Add("$t`t$title")
    }

    [IO.File]::WriteAllText($outFile, ($lines -join "`r`n") + "`r`n", [Text.Encoding]::GetEncoding(936))
    Log ("OK {0} 条 ({1}) {2}" -f ($lines.Count - 2), $Day, $usedUrl)
    exit 0
} catch {
    Log ("ERR " + $_.Exception.Message)
    exit 1
}
