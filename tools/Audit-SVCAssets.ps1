<# Audit-SVCAssets.ps1 — Windows asset audit for the SVC S1 iOS port.
   Regenerates assets/manifest.txt (relative/path|bytes) and reports
   shippable-vs-waste breakdown. Read-only on the game folder. #>
param(
  [string]$GameRoot = "F:\Z E FOLDER\zzzzzzzzzzTEMPS\Sega VS Capcom S1",
  [string]$OutManifest = (Join-Path $PSScriptRoot "..\assets\manifest.txt")
)
$files = Get-ChildItem -LiteralPath $GameRoot -Recurse -File
$files | ForEach-Object { "$($_.FullName.Substring($GameRoot.Length+1))|$($_.Length)" } |
  Set-Content -LiteralPath $OutManifest -Encoding UTF8
$total = ($files | Measure-Object -Property Length -Sum).Sum
$waste = (Get-ChildItem -LiteralPath $GameRoot -Recurse -Directory -Filter "backup" |
  ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -File } |
  Measure-Object -Property Length -Sum).Sum
$dlls = (Get-ChildItem -LiteralPath (Join-Path $GameRoot "lib") -File |
  Measure-Object -Property Length -Sum).Sum
"files: $($files.Count)  total: $([math]::Round($total/1MB,1)) MB"
"backup waste: $([math]::Round($waste/1MB,1)) MB | win lib dlls: $([math]::Round($dlls/1MB,1)) MB"
"device payload est: $([math]::Round(($total-$waste-$dlls)/1MB,1)) MB (before S1-Lite roster cut)"
