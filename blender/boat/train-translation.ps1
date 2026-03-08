# Script to translate the boat grahpics for the railed variant
# Assumes the rendered frames are in the current directory in subfolders "main", "shadow", "tint" with names "000.png".."255.png"
# Stores coppies of the images with extra padding in ./padded/, then applies the computed shifts and stores in ./shifted/
param()

# Config
$layers = @("main","shadow","tint")
$pad = 136
$frameCount = 256        # frames 0..255
$frames = 0..255
$segmentLength = 64      # frames per quadrant
$base = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
# use current directory if script executed from another location
if (-not $base) { $base = Get-Location }

$paddedRoot = Join-Path $base "padded"
$shiftedRoot = Join-Path $base "shifted"

# Anchor positions at the four extremes (N, E, S, W, and repeat N)
$anchors = @(
    @{X=0;   Y=-136},   # frame 0 (N)
    @{X=124; Y=-70},    # frame 64 (E)
    @{X=0;   Y=0},      # frame 128 (S)
    @{X=-124;Y=-70},    # frame 192 (W)
    @{X=0;   Y=-136}    # frame 256 == frame 0 (wrap)
)

# Compute smooth cubic-bezier control points from Catmull-Rom (auto default)
function Get-Controls($anchors4) {
    $controls = @()
    for ($i = 0; $i -lt 4; $i++) {
        # indices with wrap: P0 = i-1, P1 = i, P2 = i+1, P3 = i+2
        $P0 = $anchors4[($i + 3) % 4]
        $P1 = $anchors4[$i]
        $P2 = $anchors4[($i + 1) % 4]
        $P3 = $anchors4[($i + 2) % 4]

        $c1x = $P1.X + (($P2.X - $P0.X) / 6.0)
        $c1y = $P1.Y + (($P2.Y - $P0.Y) / 6.0)
        $c2x = $P2.X - (($P3.X - $P1.X) / 6.0)
        $c2y = $P2.Y - (($P3.Y - $P1.Y) / 6.0)

        $controls += @{
            Start = @{ X = $P1.X; Y = $P1.Y }
            C1    = @{ X = $c1x;   Y = $c1y   }
            C2    = @{ X = $c2x;   Y = $c2y   }
            End   = @{ X = $P2.X; Y = $P2.Y }
        }
    }
    return $controls
}

function Cubic-BezierPoint($start, $c1, $c2, $end, [double]$t) {
    $u = 1.0 - $t
    $tt = $t * $t
    $uu = $u * $u
    $uuu = $uu * $u
    $ttt = $tt * $t

    $x = ($uuu * $start.X) + (3 * $uu * $t * $c1.X) + (3 * $u * $tt * $c2.X) + ($ttt * $end.X)
    $y = ($uuu * $start.Y) + (3 * $uu * $t * $c1.Y) + (3 * $u * $tt * $c2.Y) + ($ttt * $end.Y)
    return @{ X = $x; Y = $y }
}

# Create padded images if ./padded doesn't exist (skip if exists)
if (-not (Test-Path $paddedRoot)) {
    New-Item -ItemType Directory -Path $paddedRoot | Out-Null
    Add-Type -AssemblyName System.Drawing

    foreach ($layer in $layers) {
        $srcLayer = Join-Path $base $layer
        if (-not (Test-Path $srcLayer)) { continue }
        $outLayer = Join-Path $paddedRoot $layer
        New-Item -ItemType Directory -Path $outLayer | Out-Null

        foreach ($f in $frames) {
            $name = "{0:000}.png" -f $f
            $src = Join-Path $srcLayer $name
            if (-not (Test-Path $src)) { continue }

            $img = [System.Drawing.Image]::FromFile($src)
            $w = $img.Width; $h = $img.Height
            $W = $w + ($pad * 2); $H = $h + ($pad * 2)

            $bmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            # match source image resolution to avoid DPI-based scaling
            $bmp.SetResolution($img.HorizontalResolution, $img.VerticalResolution)
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.PageUnit = [System.Drawing.GraphicsUnit]::Pixel
            $g.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
            $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImageUnscaled($img, $pad, $pad)

            $outPath = Join-Path $outLayer $name
            $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

            $g.Dispose(); $bmp.Dispose(); $img.Dispose()
        }
    }
}

# Prepare shifted output dirs
Add-Type -AssemblyName System.Drawing
foreach ($layer in $layers) {
    $dest = Join-Path $shiftedRoot $layer
    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
}

# Build controls and apply shifts per-frame
$controls = Get-Controls $anchors

foreach ($layer in $layers) {
    $paddedLayer = Join-Path $paddedRoot $layer
    if (-not (Test-Path $paddedLayer)) { continue }

    foreach ($f in $frames) {
        $name = "{0:000}.png" -f $f
        $paddedPath = Join-Path $paddedLayer $name
        if (-not (Test-Path $paddedPath)) { continue }

        # determine segment and normalized t in [0,1)
        $segment = [math]::Floor($f / $segmentLength)
        if ($segment -ge 4) { $segment = 3 }  # safety for last frame
        $t = ($f % $segmentLength) / [double]$segmentLength

        $ctrl = $controls[$segment]
        $pt = Cubic-BezierPoint $ctrl.Start $ctrl.C1 $ctrl.C2 $ctrl.End $t

        # load padded image and draw it onto new canvas at (shiftX, shiftY)
        $srcImg = [System.Drawing.Image]::FromFile($paddedPath)
        $W = $srcImg.Width; $H = $srcImg.Height
        $outBmp = New-Object System.Drawing.Bitmap $W, $H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        # preserve source resolution to prevent implicit scaling
        $outBmp.SetResolution($srcImg.HorizontalResolution, $srcImg.VerticalResolution)
        $g = [System.Drawing.Graphics]::FromImage($outBmp)
        $g.PageUnit = [System.Drawing.GraphicsUnit]::Pixel
        $g.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

        $dx = [int][math]::Round($pt.X)
        $dy = [int][math]::Round($pt.Y)

        # draw padded source shifted by (dx, dy) without scaling
        $g.DrawImageUnscaled($srcImg, $dx, $dy)

        $outPath = Join-Path (Join-Path $shiftedRoot $layer) $name
        $outBmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

        $g.Dispose(); $outBmp.Dispose(); $srcImg.Dispose()
    }
}

Write-Output "Done. Padded images in: $paddedRoot    Shifted images in: $shiftedRoot"