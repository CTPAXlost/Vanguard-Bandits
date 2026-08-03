# Extract ATAC / icon reference screenshots into the project
$ErrorActionPreference = "Stop"
$zip = "c:\Users\leonj\OneDrive\Рабочий стол\logs_83640080731.zip"
$dest = "C:\Users\leonj\Projects\Vanguard-Bandits\assets\_refs"

if (-not (Test-Path -LiteralPath $zip)) {
  throw "Zip not found: $zip"
}

New-Item -ItemType Directory -Force -Path $dest | Out-Null
Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force

Write-Host "Extracted to:"
Write-Host "  $dest"
Write-Host ""
Get-ChildItem -LiteralPath $dest -Recurse -File | ForEach-Object {
  Write-Host ("  " + $_.FullName.Substring($dest.Length + 1) + "  (" + $_.Length + " bytes)")
}
Write-Host ""
Write-Host "Done. Tell the agent: refs extracted"
explorer.exe $dest
