param(
    [string]$Source = (Join-Path $PSScriptRoot '..\Material'),
    [string]$Target = (Join-Path $PSScriptRoot '..\docs\assets\img')
)

Add-Type -AssemblyName System.Drawing

$background = [System.Drawing.Color]::FromArgb(11, 12, 16)
$foreground = [System.Drawing.Color]::FromArgb(242, 244, 248)
$bands = @(
    [System.Drawing.Color]::FromArgb(77, 124, 254),
    [System.Drawing.Color]::FromArgb(139, 108, 255),
    [System.Drawing.Color]::FromArgb(255, 106, 85),
    [System.Drawing.Color]::FromArgb(184, 240, 58)
)

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }

function Save-Jpeg([System.Drawing.Bitmap]$Bitmap, [string]$Path, [int]$Quality) {
    $parameters = New-Object System.Drawing.Imaging.EncoderParameters 1
    $parameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
    $Bitmap.Save($Path, $jpegCodec, $parameters)
    $parameters.Dispose()
}

function Export-Resized([string]$InputPath, [string]$OutputPath, [int]$Width, [int]$Height) {
    $image = [System.Drawing.Image]::FromFile($InputPath)
    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = 'HighQualityBicubic'
    $graphics.PixelOffsetMode = 'HighQuality'

    # Without TileFlipXY the bicubic filter blends the edges with transparent pixels.
    $attributes = New-Object System.Drawing.Imaging.ImageAttributes
    $attributes.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $destination = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
    $graphics.DrawImage($image, $destination, 0, 0, $image.Width, $image.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)

    Save-Jpeg $bitmap $OutputPath 85
    $attributes.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $image.Dispose()
}

function Draw-Mark([System.Drawing.Graphics]$Graphics, [single]$X, [single]$Y, [single]$Size) {
    $unit = $Size / 32
    for ($band = 0; $band -lt $bands.Count; $band++) {
        $brush = New-Object System.Drawing.SolidBrush $bands[$band]
        $Graphics.FillRectangle($brush, $X, $Y + $band * 8 * $unit, 14 * $unit, 8 * $unit)
        $brush.Dispose()
    }

    $pen = New-Object System.Drawing.Pen $foreground, (4 * $unit)
    $bracket = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF ($X + 18 * $unit), ($Y + 2 * $unit)),
        (New-Object System.Drawing.PointF ($X + 30 * $unit), ($Y + 2 * $unit)),
        (New-Object System.Drawing.PointF ($X + 30 * $unit), ($Y + 30 * $unit)),
        (New-Object System.Drawing.PointF ($X + 18 * $unit), ($Y + 30 * $unit))
    )
    $Graphics.DrawLines($pen, $bracket)
    $pen.Dispose()
}

function Export-Icon([string]$OutputPath, [int]$Size, [single]$MarkRatio = 0.6) {
    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($background)

    # A multiple of 32 keeps every band and the bracket on whole pixels.
    $markSize = [math]::Max(1, [math]::Round($Size * $MarkRatio / 32)) * 32
    $offset = ($Size - $markSize) / 2
    Draw-Mark $graphics $offset $offset $markSize
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function Export-Favicon([string]$PngPath, [string]$OutputPath, [int]$Size) {
    $png = [IO.File]::ReadAllBytes($PngPath)
    $stream = New-Object IO.MemoryStream
    $writer = New-Object IO.BinaryWriter $stream
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]1)
    $writer.Write([byte]$Size)
    $writer.Write([byte]$Size)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$png.Length)
    $writer.Write([uint32]22)
    $writer.Write($png)
    $writer.Flush()
    [IO.File]::WriteAllBytes($OutputPath, $stream.ToArray())
    $writer.Dispose()
}

# GDI+ has no blend modes, masks or woff2 support, so these images are HTML pages rendered by headless Edge.
function Export-Page([string]$PageName, [string]$OutputPath, [int]$Width, [int]$Height) {
    $edge = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $edge) {
        Write-Warning "Microsoft Edge not found; $PageName was not rendered."
        return $false
    }

    $page = (New-Object Uri (Resolve-Path (Join-Path $PSScriptRoot $PageName)).Path).AbsoluteUri
    $profile = Join-Path $env:TEMP 'mediopixel-export'
    $arguments = @(
        '--headless=new', '--disable-gpu', '--hide-scrollbars', '--force-device-scale-factor=1',
        "--window-size=$Width,$Height", '--virtual-time-budget=4000',
        "--user-data-dir=`"$profile`"", "--screenshot=`"$OutputPath`"", $page
    )
    Start-Process -FilePath $edge -ArgumentList $arguments -Wait -WindowStyle Hidden
    return $true
}

function Export-Banner([string]$OutputPath) {
    $rendered = Join-Path $env:TEMP 'mediopixel-banner.png'
    if (Export-Page 'banner.html' $rendered 2048 1000) {
        Export-Resized $rendered $OutputPath 2048 1000
    }
}

$Source = (Resolve-Path $Source).Path
New-Item -ItemType Directory -Force (Join-Path $Target 'pop-out') | Out-Null
$Target = (Resolve-Path $Target).Path

$shots = 'popout_ss3', 'popout_ss4', 'popout_ss5', 'popout_ss6', 'popout_ss8', 'popout_ss9'
for ($index = 0; $index -lt $shots.Count; $index++) {
    $inputPath = Join-Path $Source "screenshots\$($shots[$index]).png"
    Export-Resized $inputPath (Join-Path $Target "pop-out\shot-$($index + 1).jpg") 540 1200
}

Export-Banner (Join-Path $Target 'pop-out\banner.jpg')
Export-Resized (Join-Path $Source 'popout_icon_512px.jpg') (Join-Path $Target 'pop-out\icon.jpg') 256 256

Export-Icon (Join-Path $Target 'icon-48.png') 48
Export-Icon (Join-Path $Target 'apple-touch-icon.png') 180
Export-Favicon (Join-Path $Target 'icon-48.png') (Join-Path $Target '..\..\favicon.ico') 48
Export-Page 'social-card.html' (Join-Path $Target 'og.png') 1200 630 | Out-Null

$brand = Join-Path $PSScriptRoot '..\brand'
New-Item -ItemType Directory -Force $brand | Out-Null
Export-Icon (Join-Path $brand 'avatar.png') 1080 0.5
Export-Page 'profile-banner.html' (Join-Path (Resolve-Path $brand).Path 'banner.png') 3000 1000 | Out-Null

Get-ChildItem $Target -Recurse -File | ForEach-Object { '{0,7:N0} KB  {1}' -f ($_.Length / 1KB), $_.FullName.Substring($Target.Length + 1) }
