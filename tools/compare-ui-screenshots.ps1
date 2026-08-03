param(
  [Parameter(Mandatory = $true)]
  [string]$Reference,
  [Parameter(Mandatory = $true)]
  [string]$Actual,
  [string]$OutputDirectory = (Join-Path (Get-Location) 'midscene_run\pixel-diff'),
  [int]$CropX = 0,
  [int]$CropY = 0,
  [int]$CropWidth = 390,
  [int]$CropHeight = 844,
  [int]$Tolerance = 8
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

function Get-CroppedBitmap {
  param(
    [string]$Path,
    [int]$X,
    [int]$Y,
    [int]$Width,
    [int]$Height
  )

  $source = [System.Drawing.Bitmap]::new($Path)
  if ($X -lt 0 -or $Y -lt 0 -or $X + $Width -gt $source.Width -or $Y + $Height -gt $source.Height) {
    $source.Dispose()
    throw "Crop [$X,$Y,$Width,$Height] is outside $Path ($($source.Width)x$($source.Height))."
  }

  $cropped = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($cropped)
  $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height), [System.Drawing.Rectangle]::new($X, $Y, $Width, $Height), [System.Drawing.GraphicsUnit]::Pixel)
  $graphics.Dispose()
  $source.Dispose()
  return $cropped
}

function Get-ColorDistance {
  param(
    [System.Drawing.Color]$Left,
    [System.Drawing.Color]$Right
  )

  return [Math]::Abs($Left.R - $Right.R) + [Math]::Abs($Left.G - $Right.G) + [Math]::Abs($Left.B - $Right.B) + [Math]::Abs($Left.A - $Right.A)
}

$referenceBitmap = Get-CroppedBitmap -Path $Reference -X $CropX -Y $CropY -Width $CropWidth -Height $CropHeight
$actualBitmap = Get-CroppedBitmap -Path $Actual -X $CropX -Y $CropY -Width $CropWidth -Height $CropHeight
$diffBitmap = [System.Drawing.Bitmap]::new($CropWidth, $CropHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$changedPixels = 0
$totalDistance = [double]0
$maxDistance = 0
$pixelCount = $CropWidth * $CropHeight

for ($y = 0; $y -lt $CropHeight; $y++) {
  for ($x = 0; $x -lt $CropWidth; $x++) {
    $referenceColor = $referenceBitmap.GetPixel($x, $y)
    $actualColor = $actualBitmap.GetPixel($x, $y)
    $distance = Get-ColorDistance -Left $referenceColor -Right $actualColor
    $totalDistance += $distance
    if ($distance -gt $maxDistance) {
      $maxDistance = $distance
    }
    if ($distance -gt $Tolerance) {
      $changedPixels++
      $intensity = [Math]::Min(255, [Math]::Max(0, [int]($distance * 2)))
      $diffBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $intensity, 0, 0))
    } else {
      $diffBitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 0, 0, 0))
    }
  }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$referenceCopy = Join-Path $OutputDirectory 'reference-crop.png'
$actualCopy = Join-Path $OutputDirectory 'actual-crop.png'
$diffPath = Join-Path $OutputDirectory 'diff-mask.png'
$reportPath = Join-Path $OutputDirectory 'report.json'
$referenceBitmap.Save($referenceCopy, [System.Drawing.Imaging.ImageFormat]::Png)
$actualBitmap.Save($actualCopy, [System.Drawing.Imaging.ImageFormat]::Png)
$diffBitmap.Save($diffPath, [System.Drawing.Imaging.ImageFormat]::Png)

$report = [ordered]@{
  reference = [System.IO.Path]::GetFullPath($Reference)
  actual = [System.IO.Path]::GetFullPath($Actual)
  crop = [ordered]@{ x = $CropX; y = $CropY; width = $CropWidth; height = $CropHeight }
  tolerance = $Tolerance
  pixelCount = $pixelCount
  changedPixels = $changedPixels
  changedRatio = [Math]::Round($changedPixels / [double]$pixelCount, 6)
  meanDistance = [Math]::Round($totalDistance / [double]$pixelCount, 4)
  maxDistance = $maxDistance
  outputs = [ordered]@{ referenceCrop = $referenceCopy; actualCrop = $actualCopy; diffMask = $diffPath }
}
$report | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding utf8

$referenceBitmap.Dispose()
$actualBitmap.Dispose()
$diffBitmap.Dispose()

$report | ConvertTo-Json -Depth 5
