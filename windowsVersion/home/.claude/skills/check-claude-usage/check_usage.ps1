param(
  [string]$Url = "https://claude.ai/new#settings/usage",
  [string]$OutDir = "$env:TEMP\claude-usage-check",
  [int]$MaxCacheAgeMinutes = 15
)

$ErrorActionPreference = "Stop"

$cacheFile = Join-Path $OutDir "last-check.json"
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

Start-Sleep -Seconds 8
Focus-Window $target | Out-Null
Start-Sleep -Seconds 1

[System.Windows.Forms.SendKeys]::SendWait("^0")
Start-Sleep -Seconds 2

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# The usage card's height varies day to day (a promo/boost banner, an extra
# per-model bar, etc. can appear above or between the two required bars), so
# the capture area is most of the screen rather than a tight box around
# where the card used to sit -- a wide net that stays valid whatever prose
# or extra bars the card grows, instead of a box tuned to one layout.
$cropRect = New-Object System.Drawing.Rectangle(200, 60, 1700, 960)

function Grab-UsageScreenshot([string]$Stamp) {
  $outPath = Join-Path $OutDir "usage_$Stamp.png"
  $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
  $gfx = [System.Drawing.Graphics]::FromImage($bmp)
  $gfx.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $gfx.Dispose()
  $cropped = $bmp.Clone($cropRect, $bmp.PixelFormat)
  $scale = 2
  $scaled = New-Object System.Drawing.Bitmap ($cropRect.Width * $scale), ($cropRect.Height * $scale)
  $sg = [System.Drawing.Graphics]::FromImage($scaled)
  $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $sg.DrawImage($cropped, 0, 0, $scaled.Width, $scaled.Height)
  $sg.Dispose()
  $cropPath = Join-Path $OutDir "usage_${Stamp}_crop.png"
  $scaled.Save($cropPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  $cropped.Dispose()
  $scaled.Dispose()
  $cropPath
}

function Ocr-Text([string]$CropPath, [string]$OcrBase, [int]$Psm) {
  & $tesseractExe $CropPath $OcrBase --psm $Psm | Out-Null
  Get-Content "$OcrBase.txt" -Raw
}

# Anchor on the bar's own label line rather than position or an exact bar
# count: extra bars (a promo-period "Fable this week" bar, say) come and go,
# and a bar with a near-zero reading sometimes renders with no "NN% used"
# text next to it at all -- both are layout noise, not a reason to fail the
# whole check. Only the label itself is load-bearing.
function Find-UsageBar([string]$Text, [string]$LabelPattern) {
  $label = [regex]::Match($Text, $LabelPattern)
  if (-not $label.Success) { return $null }
  $windowEnd = [Math]::Min($Text.Length, $label.Index + 250)
  $window = $Text.Substring($label.Index, $windowEnd - $label.Index)
  $reset = [regex]::Match($window, 'Resets?\s+([^\r\n.]+)')
  # A bar's own percentage, when shown, sits between its label and its own
  # "Resets ..." line -- never search past that boundary, or the next bar's
  # percentage (or reset time) bleeds in as a false match for this one.
  $pctScope = if ($reset.Success) { $window.Substring(0, $reset.Index) } else { $window }
  $pct = [regex]::Match($pctScope, '(\d{1,3})\s*%\s*used')
  [pscustomobject]@{
    pct   = if ($pct.Success) { $pct.Groups[1].Value } else { "unknown" }
    reset = if ($reset.Success) { $reset.Groups[1].Value.Trim() } else { "unknown" }
  }
}
$sessionLabelRe = '(?im)^\s*Current session\s*$'
$weeklyLabelRe  = '(?im)^\s*(?:This week|Weekly limits)\s*$'

# A slow-loading promo banner delays the real numbers, not just their
# position, so retry a few times with growing waits before treating it as a
# genuine layout break -- transient load lag and an actual broken layout
# fail the same way on a single attempt and must not be confused.
$maxAttempts = 3
$session = $null
$weekly = $null
for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
  # On this shared four-agent desktop, SetForegroundWindow can silently lose
  # the browser to another agent's window between the initial focus and now;
  # re-assert it before every attempt rather than trusting it stuck once.
  Focus-Window $target | Out-Null
  Start-Sleep -Milliseconds 300
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $cropPath = Grab-UsageScreenshot $stamp
  $ocrBase = Join-Path $OutDir "usage_${stamp}_ocr"
  $ocrText = Ocr-Text $cropPath $ocrBase 6
  $session = Find-UsageBar $ocrText $sessionLabelRe
  $weekly = Find-UsageBar $ocrText $weeklyLabelRe

  # psm 6 (uniform block) sometimes drops one bar's right-column percentage
  # outright while reading its neighbors fine -- a page-segmentation miss,
  # not a missing number (confirmed by eye against the screenshot). Before
  # accepting "unknown", re-OCR the same image with psm 11 (sparse text,
  # no block-layout assumption) and use it only to fill in a percentage the
  # first pass missed.
  $needsFallback = ($session -and $session.pct -eq "unknown") -or ($weekly -and $weekly.pct -eq "unknown")
  if ($needsFallback) {
    $ocrBase2 = "${ocrBase}_alt"
    $ocrText2 = Ocr-Text $cropPath $ocrBase2 11
    if ($session -and $session.pct -eq "unknown") {
      $s2 = Find-UsageBar $ocrText2 $sessionLabelRe
      if ($s2 -and $s2.pct -ne "unknown") { $session = $s2 }
    }
    if ($weekly -and $weekly.pct -eq "unknown") {
      $w2 = Find-UsageBar $ocrText2 $weeklyLabelRe
      if ($w2 -and $w2.pct -ne "unknown") { $weekly = $w2 }
    }
  }

  if ($session -and $weekly -and $session.pct -ne "unknown" -and $weekly.pct -ne "unknown") { break }
  if ($attempt -lt $maxAttempts) { Start-Sleep -Seconds (5 * $attempt) }
}

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

if (-not ($session -and $weekly)) {
  Write-Error "Usage panel not recognized after $maxAttempts attempts (login page, Cloudflare check, or a layout change bigger than the capture area). Raw OCR saved at $ocrBase.txt for inspection:`n$ocrText"
}
if ($session.pct -eq "unknown") {
  Write-Warning "No 'NN% used' text found near the Current session label (likely a near-zero reading the UI renders without a number) -- reporting 'unknown'. Raw OCR at $ocrBase.txt."
}
if ($weekly.pct -eq "unknown") {
  Write-Warning "No 'NN% used' text found near the This week/Weekly limits label -- reporting 'unknown'. Raw OCR at $ocrBase.txt."
}

$sessionLine = "Current session: $($session.pct)% used, resets $($session.reset)"
$weeklyLine = "Weekly limits: $($weekly.pct)% used, resets $($weekly.reset)"

[pscustomobject]@{
  timestamp   = (Get-Date).ToString('o')
  sessionLine = $sessionLine
  weeklyLine  = $weeklyLine
} | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding utf8

Write-Output $sessionLine
Write-Output $weeklyLine