param([string]$Title = 'FatFishNote')
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class FG {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr l);
  public delegate bool EnumWindowsProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern void keybd_event(byte b, byte s, uint f, IntPtr e);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
}
public class K32 {
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
}
"@
$script:found = [IntPtr]::Zero
$cb = [FG+EnumWindowsProc]{
  param($h, $l)
  if ([FG]::IsWindowVisible($h)) {
    $sb = New-Object System.Text.StringBuilder 512
    [FG]::GetWindowText($h, $sb, 512) | Out-Null
    if ($sb.ToString() -match $Title) { $script:found = $h }
  }
  return $true
}
[FG]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($script:found -eq [IntPtr]::Zero) { exit 1 }

# 1) 模拟一下 Alt，解开前台锁
[FG]::keybd_event(0x12, 0, 0, [IntPtr]::Zero)
[FG]::keybd_event(0x12, 0, 2, [IntPtr]::Zero)
Start-Sleep -Milliseconds 30

# 2) 用 AttachThreadInput 抓当前前台线程
$fg = [FG]::GetForegroundWindow()
$fgThread = [FG]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
$myThread = [K32]::GetCurrentThreadId()
[FG]::AttachThreadInput($myThread, $fgThread, $true) | Out-Null
[FG]::ShowWindow($script:found, 5) | Out-Null
$ok = [FG]::SetForegroundWindow($script:found)
[FG]::AttachThreadInput($myThread, $fgThread, $false) | Out-Null
if ($ok) { exit 0 } else { exit 2 }
