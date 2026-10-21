# Generates HCOneButton/Media/icon.tga (64x64, 32-bit, uncompressed)
# from the CurseForge project logo (docs/logo.png), referenced by the TOC as
# ## IconTexture (icon in the AddOns list): 32-bit, top-left origin and a
# TGA 2.0 footer.
# Only the red "1" medallion is kept: the logo text is unreadable at 64 px.
#   powershell -ExecutionPolicy Bypass -File scripts/make-icon.ps1
[CmdletBinding()]
param(
  [string]$Source = "docs/logo.png",
  [string]$Target = "HCOneButton/Media/icon.tga",
  [int]$Size = 64,
  # Square around the medallion in the 400x400 logo (left, top, side).
  [int]$CropX = 100,
  [int]$CropY = 14,
  [int]$CropSide = 200
)
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$sourcePath = Join-Path $root $Source
$targetPath = Join-Path $root $Target
if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Source image not found: $sourcePath" }
if (($Size -band ($Size - 1)) -ne 0) { throw "Size must be a power of two" }

Add-Type -AssemblyName System.Drawing
$image = [System.Drawing.Image]::FromFile($sourcePath)
try {
  if ($CropX -lt 0 -or $CropY -lt 0 -or $CropSide -lt 1 -or $CropX + $CropSide -gt $image.Width -or $CropY + $CropSide -gt $image.Height) { throw "Crop outside the source image" }
  $crop = New-Object System.Drawing.Rectangle $CropX, $CropY, $CropSide, $CropSide
  $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.DrawImage($image, (New-Object System.Drawing.Rectangle 0, 0, $Size, $Size), $crop, [System.Drawing.GraphicsUnit]::Pixel)
  $graphics.Dispose()

  # TGA header: uncompressed true-colour, 32 bpp, 8 alpha bits, origin top-left.
  $header = New-Object byte[] 18
  $header[2] = 2
  $header[12] = $Size -band 0xFF; $header[13] = ($Size -shr 8) -band 0xFF
  $header[14] = $Size -band 0xFF; $header[15] = ($Size -shr 8) -band 0xFF
  $header[16] = 32
  $header[17] = 0x28
  $pixels = New-Object byte[] ($Size * $Size * 4)
  $offset = 0
  for ($y = 0; $y -lt $Size; $y++) {
    for ($x = 0; $x -lt $Size; $x++) {
      $color = $bitmap.GetPixel($x, $y)
      $pixels[$offset] = $color.B; $pixels[$offset + 1] = $color.G
      $pixels[$offset + 2] = $color.R; $pixels[$offset + 3] = $color.A
      $offset += 4
    }
  }
  $bitmap.Dispose()
  # TGA 2.0 footer: no extension or developer area.
  $footer = New-Object byte[] 26
  $signature = [System.Text.Encoding]::ASCII.GetBytes("TRUEVISION-XFILE.")
  [Array]::Copy($signature, 0, $footer, 8, $signature.Length)
  $directory = Split-Path -Parent $targetPath
  if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory | Out-Null }
  $stream = [System.IO.File]::Create($targetPath)
  try {
    $stream.Write($header, 0, $header.Length)
    $stream.Write($pixels, 0, $pixels.Length)
    $stream.Write($footer, 0, $footer.Length)
  } finally {
    $stream.Dispose()
  }
} finally {
  $image.Dispose()
}
Write-Output ("Wrote {0} ({1}x{1}, {2} bytes)" -f $Target, $Size, (Get-Item -LiteralPath $targetPath).Length)
