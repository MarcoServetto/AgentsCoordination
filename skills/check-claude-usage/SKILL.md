---
name: check-claude-usage
description: Read the current Anthropic usage limits, both the rolling ~5-hour "Current session" and the "Weekly limits", by opening the page in the logged-in browser on this machine, screenshotting it and OCRing the numbers.
---
# Checking claude.ai usage limits

Call
```powershell
& "$HOME\.claude\skills\check-claude-usage\check_usage.ps1"
```
Result:
```
Current session: NN% used, resets in Xh Ym
Weekly limits: NN% used, resets <day> <time>
```
Report those two lines verbatim. Readings are cached for 15 minutes in
`$env:TEMP\claude-usage-check\last-check.json`; one account, four agents,
so a fresh reading from any of them is valid for all. About 15 seconds
when not cached; don't call it in a tight loop.

If this fails do not attempt the process manually.
Report the error instead. The user must fix this manually.

This script depends on Tesseract at C:\Program Files\Tesseract-OCR, on
Brave being logged in to claude.ai, and on a 1920x1080 display at 150%
scaling (it crops a fixed rectangle of the screenshot).
