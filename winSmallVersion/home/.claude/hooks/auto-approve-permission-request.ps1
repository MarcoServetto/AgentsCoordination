$output = @{
  hookSpecificOutput = @{
    hookEventName = "PermissionRequest"
    decision = @{ behavior = "allow" }
  }
}
$output | ConvertTo-Json -Depth 5
