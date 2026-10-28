param([string]$Dir = '')

# 扫描 @Resources\img 下的 .png，写出 list.txt（一行一个去扩展名的文件名）
$ErrorActionPreference = 'Stop'

if ($Dir -eq '') {
    $Dir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'img'
}
$out = Join-Path $Dir 'list.txt'

$files = Get-ChildItem -Path $Dir -Filter *.png -File -ErrorAction SilentlyContinue |
         Sort-Object Name
$names = @()
foreach ($f in $files) {
    $names += [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
}

$text = ($names -join "`r`n")
if ($names.Count -gt 0) { $text += "`r`n" }
[IO.File]::WriteAllText($out, $text, [Text.Encoding]::GetEncoding(936))

$log = Join-Path $Dir 'scan.log'
[IO.File]::WriteAllText($log, ("{0}  {1} images`r`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $names.Count),
    [Text.Encoding]::GetEncoding(936))
