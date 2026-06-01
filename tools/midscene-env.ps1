param(
  [string]$ModelName = "doubao-seed-2-0-lite-260215",
  [string]$ModelFamily = "doubao-seed",
  [string]$BaseUrl = "https://ark.cn-beijing.volces.com/api/v3",
  [int]$ReplanningCycleLimit = 60,
  [switch]$CheckHdc
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($env:MIDSCENE_MODEL_API_KEY)) {
  throw 'MIDSCENE_MODEL_API_KEY is not set. Please export your local API key before running the regression.'
}

$env:MIDSCENE_MODEL_NAME = $ModelName
$env:MIDSCENE_MODEL_FAMILY = $ModelFamily
$env:MIDSCENE_MODEL_BASE_URL = $BaseUrl
$env:MIDSCENE_REPLANNING_CYCLE_LIMIT = $ReplanningCycleLimit.ToString()

Write-Host '[FitTracker Midscene] Environment prepared.'
Write-Host ('- MIDSCENE_MODEL_NAME=' + $env:MIDSCENE_MODEL_NAME)
Write-Host ('- MIDSCENE_MODEL_FAMILY=' + $env:MIDSCENE_MODEL_FAMILY)
Write-Host ('- MIDSCENE_MODEL_BASE_URL=' + $env:MIDSCENE_MODEL_BASE_URL)
Write-Host ('- MIDSCENE_REPLANNING_CYCLE_LIMIT=' + $env:MIDSCENE_REPLANNING_CYCLE_LIMIT)

if ($CheckHdc) {
  hdc version
  hdc list targets
}

