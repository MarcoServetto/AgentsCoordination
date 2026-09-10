---
name: check-claude-usage
description: Read Marco's current Anthropic usage limits — the rolling ~5-hour "Current session" by opening the page in the logged-in browser on this machine, screenshotting it and OCRing the numbers.
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
state\last-check.json — one account, four agents, so a fresh reading from
any of them is valid for all. About 15 seconds when not cached; don't call
it in a tight loop.

If this fails do not attempt the process manually.
Report the error instead. The user must fix this manually.

This script depends from Tesseract at C:\Program Files\Tesseract-OCR