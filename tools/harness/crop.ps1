param([string]$In, [string]$Out, [int]$Bottom = 0, [double]$Scale = 1.0)
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Bitmap]::FromFile($In)
if ($Bottom -gt 0) {
    $h = [Math]::Min($Bottom, $src.Height)
    $rect = New-Object System.Drawing.Rectangle 0, ($src.Height - $h), $src.Width, $h
    $cut = $src.Clone($rect, $src.PixelFormat)
    $src.Dispose(); $src = $cut
}
if ($Scale -ne 1.0) {
    $w = [int]($src.Width * $Scale); $hh = [int]($src.Height * $Scale)
    $dst = New-Object System.Drawing.Bitmap $w, $hh
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $w, $hh)
    $g.Dispose(); $src.Dispose(); $src = $dst
}
$src.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"$Out ($($src.Width) x $($src.Height))"
$src.Dispose()
