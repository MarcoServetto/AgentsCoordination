param(
  [string]$Url = "https://claude.ai/new#settings/usage",
  [string]$OutDir = "$env:TEMP\claude-usage-check",
  [int]$MaxCacheAgeMinutes = 15
)

$ErrorActionPreference = "Stop"

$cacheFile = "$HOME\.claude\skills\check-claude-usage\state\last-check.json"
if (Test-Path $cacheFile) {
  try {
    $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json
    $ageMin = ((Get-Date) - [datetime]$cache.timestamp).TotalMinutes
    if ($ageMin -lt $MaxCacheAgeMinutes) {
      Write-Output $cache.sessionLine
      Write-Output $cache.weeklyLine
      return
    }
  } catch {
    # unreadable/corrupt cache -- fall through to a real check
  }
}

Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class DpiAware{[DllImport("user32.dll")]public static extern bool SetProcessDPIAware();}'
[DpiAware]::SetProcessDPIAware() | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bravePaths = @(
  "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
  "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
  "C:\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe"
)
$browserExe = $bravePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browserExe) {
  Write-Error "Could not find brave.exe in any known install location. Update `$bravePaths in this script if the browser or its path changed."
}
$procName = [System.IO.Path]::GetFileNameWithoutExtension($browserExe)  # "brave"

$tesseractPaths = @(
  "C:\Program Files\Tesseract-OCR\tesseract.exe",
  "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe"
)
$tesseractExe = $tesseractPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $tesseractExe) {
  Write-Error "Could not find tesseract.exe. Install it (winget install UB-Mannheim.TesseractOCR) or update `$tesseractPaths in this script."
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32Focus {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
}
"@
$SW_MAXIMIZE = 3
$SW_RESTORE  = 9

function Get-BraveWindow {
  Get-Process -Name $procName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -ne "" } |
    Sort-Object StartTime -Descending | Select-Object -First 1
}

function Focus-Window([System.Diagnostics.Process]$proc) {
  if ($proc.MainWindowHandle -eq [IntPtr]::Zero) { return $false }
  if ([Win32Focus]::IsIconic($proc.MainWindowHandle)) {
    [Win32Focus]::ShowWindowAsync($proc.MainWindowHandle, $SW_RESTORE) | Out-Null
    Start-Sleep -Milliseconds 300
  }
  [Win32Focus]::ShowWindowAsync($proc.MainWindowHandle, $SW_MAXIMIZE) | Out-Null
  [Win32Focus]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
  return $true
}

Start-Process -FilePath $browserExe -ArgumentList @(
  "--hide-crash-restore-bubble", "--new-window", $Url) | Out-Null

$deadline = (Get-Date).AddSeconds(15)
$target = $null
while ((Get-Date) -lt $deadline) {
  $target = Get-Process -Name $procName -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle -ne "" } |
    Sort-Object StartTime -Descending |
    Select-Object -First 1
  if ($target) { break }
  Start-Sleep -Milliseconds 400
}
if (-not $target) {
  Write-Error "Timed out waiting for the browser window to appear."
}

Focus-Window $target | Out-Null

Start-Sleep -Seconds 6
Focus-Window $target | Out-Null
Start-Sleep -Seconds 1

[System.Windows.Forms.SendKeys]::SendWait("^0")
Start-Sleep -Seconds 2

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outPath = Join-Path $OutDir "usage_$stamp.png"

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose()

$cropRect = New-Object System.Drawing.Rectangle(485, 140, 1235, 760)
$cropped = $bmp.Clone($cropRect, $bmp.PixelFormat)
$scale = 2
$scaled = New-Object System.Drawing.Bitmap ($cropRect.Width * $scale), ($cropRect.Height * $scale)
$sg = [System.Drawing.Graphics]::FromImage($scaled)
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$sg.DrawImage($cropped, 0, 0, $scaled.Width, $scaled.Height)
$sg.Dispose()
$cropPath = Join-Path $OutDir "usage_${stamp}_crop.png"
$scaled.Save($cropPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$cropped.Dispose()
$scaled.Dispose()

$ocrBase = Join-Path $OutDir "usage_${stamp}_ocr"
& $tesseractExe $cropPath $ocrBase --psm 6 2>$null | Out-Null
$ocrText = Get-Content "$ocrBase.txt" -Raw

$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline) {
  $w = Get-BraveWindow
  if (-not $w) { break }
  Focus-Window $w | Out-Null
  Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait("^w")
  Start-Sleep -Milliseconds 450
}
if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
  foreach ($p in (Get-Process -Name $procName -ErrorAction SilentlyContinue |
                  Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })) {
    $p.CloseMainWindow() | Out-Null
  }
  Start-Sleep -Seconds 3
  Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
}

$pctMatches = [regex]::Matches($ocrText, '(\d{1,3})\s*%\s*used')
$resetMatches = [regex]::Matches($ocrText, 'Resets\s+([^\r\n]+)')

if ($ocrText -notmatch 'Current session' -or $ocrText -notmatch 'Weekly limits') {
  Write-Error "Usage panel not recognized in OCR text (login page, Cloudflare check, or layout change). Raw OCR saved at $ocrBase.txt for inspection:`n$ocrText"
}
if ($pctMatches.Count -lt 2 -or $resetMatches.Count -lt 2) {
  Write-Error "Expected 2 usage bars, found $($pctMatches.Count) percentages and $($resetMatches.Count) reset lines. Raw OCR saved at $ocrBase.txt for inspection:`n$ocrText"
}

$sessionLine = "Current session: $($pctMatches[0].Groups[1].Value)% used, resets $($resetMatches[0].Groups[1].Value.Trim())"
$weeklyLine = "Weekly limits: $($pctMatches[1].Groups[1].Value)% used, resets $($resetMatches[1].Groups[1].Value.Trim())"

New-Item -ItemType Directory -Force -Path (Split-Path $cacheFile) | Out-Null
[pscustomobject]@{
  timestamp   = (Get-Date).ToString('o')
  sessionLine = $sessionLine
  weeklyLine  = $weeklyLine
} | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding utf8

Write-Output $sessionLine
Write-Output $weeklyLine