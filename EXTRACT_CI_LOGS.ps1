# Unpack GitHub Actions failure logs for the agent
$ErrorActionPreference = "Stop"
$zip = "c:\Users\leonj\OneDrive\Рабочий стол\logs_83640080731.zip"
$dest = "C:\Users\leonj\Projects\Vanguard-Bandits\.ci_logs"

if (-not (Test-Path -LiteralPath $zip)) {
  throw "Zip not found: $zip"
}

if (Test-Path -LiteralPath $dest) {
  Remove-Item -LiteralPath $dest -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force

Write-Host "Extracted CI logs to: $dest"
Get-ChildItem -LiteralPath $dest -Recurse -File | Select-Object -First 40 FullName, Length
Write-Host ""
Write-Host "Tell the agent: ci logs extracted"
explorer.exe $dest
