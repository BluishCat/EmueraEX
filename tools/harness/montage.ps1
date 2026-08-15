param([string[]]$In, [string]$Out, [double]$Scale = 0.5)
Add-Type -AssemblyName System.Drawing
$imgs = $In | ForEach-Object { [System.Drawing.Bitmap]::FromFile($_) }
$w = [int](($imgs | ForEach-Object { $_.Width } | Measure-Object -Maximum).Maximum * $Scale)
$h = 0
foreach ($i in $imgs) { $h += [int]($i.Height * $Scale) + 6 }
$dst = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($dst)
$g.Clear([System.Drawing.Color]::DimGray)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$y = 0
foreach ($i in $imgs) {
    $ih = [int]($i.Height * $Scale)
    $g.DrawImage($i, 0, $y, [int]($i.Width * $Scale), $ih)
    $y += $ih + 6
    $i.Dispose()
}
$g.Dispose()
$dst.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"$Out ($($dst.Width) x $($dst.Height))"
$dst.Dispose()
