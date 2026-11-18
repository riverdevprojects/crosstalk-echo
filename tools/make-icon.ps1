param([string]$OutPath)
Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Full-bleed square background; iOS applies the rounded mask itself.
$bg = [System.Drawing.Color]::FromArgb(237, 234, 228)
$g.Clear($bg)

function New-Bubble([float]$x, [float]$y, [float]$w, [float]$h, [float]$r, [bool]$tailLeft) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    if ($tailLeft) {
        $p.AddLine($x + $w - $r, $y + $h, $x + $r + 150, $y + $h)
        $p.AddLine($x + $r + 150, $y + $h, $x + $r - 10, $y + $h + 120)
        $p.AddLine($x + $r - 10, $y + $h + 120, $x + $r + 40, $y + $h)
    } else {
        $p.AddLine($x + $w - $r - 40, $y + $h, $x + $w - $r + 10, $y + $h + 120)
        $p.AddLine($x + $w - $r + 10, $y + $h + 120, $x + $w - $r - 150, $y + $h)
    }
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

# One speech bubble, centered (bubble 600x420 plus a 120px tail = 540 tall).
$bubble = New-Bubble 212 242 600 420 130 $true
$ink = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(38, 37, 35))
$g.FillPath($ink, $bubble)

$g.Dispose()
$bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"saved $OutPath"
