param(
    [string]$Source = (Join-Path $PSScriptRoot '..\Material'),
    [string]$Target = (Join-Path $PSScriptRoot '..\docs\assets\img')
)

Add-Type -AssemblyName System.Drawing

$background = [System.Drawing.Color]::FromArgb(11, 12, 16)
$foreground = [System.Drawing.Color]::FromArgb(242, 244, 248)
$muted = [System.Drawing.Color]::FromArgb(154, 161, 174)
$accent = [System.Drawing.Color]::FromArgb(77, 124, 254)

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
    $pen = New-Object System.Drawing.Pen $foreground, (4 * $unit)
    $Graphics.DrawRectangle($pen, $X + 2 * $unit, $Y + 2 * $unit, 28 * $unit, 28 * $unit)
    $brush = New-Object System.Drawing.SolidBrush $accent
    $Graphics.FillRectangle($brush, $X, $Y, 16 * $unit, $Size)
    $brush.Dispose()
    $pen.Dispose()
}

function Export-Icon([string]$OutputPath, [int]$Size) {
    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($background)
    $markSize = [math]::Round($Size * 0.6)
    $offset = ($Size - $markSize) / 2
    Draw-Mark $graphics $offset $offset $markSize
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function Export-SocialCard([string]$OutputPath) {
    $installed = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    $fontName = 'Consolas'
    if ($installed -contains 'Cascadia Mono') {
        $fontName = 'Cascadia Mono'
    }

    $bitmap = New-Object System.Drawing.Bitmap 1200, 630
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear($background)
    $graphics.TextRenderingHint = 'AntiAlias'
    Draw-Mark $graphics 150 235 160

    $titleFont = New-Object System.Drawing.Font $fontName, 84, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFont = New-Object System.Drawing.Font $fontName, 34, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = New-Object System.Drawing.SolidBrush $foreground
    $subtitleBrush = New-Object System.Drawing.SolidBrush $muted
    $graphics.DrawString('medio pixel', $titleFont, $titleBrush, 360, 240)
    $graphics.DrawString('indie games studio', $subtitleFont, $subtitleBrush, 366, 345)

    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $subtitleBrush.Dispose()
    $titleBrush.Dispose()
    $subtitleFont.Dispose()
    $titleFont.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$Source = (Resolve-Path $Source).Path
New-Item -ItemType Directory -Force (Join-Path $Target 'pop-out') | Out-Null
$Target = (Resolve-Path $Target).Path

$shots = 'popout_ss3', 'popout_ss4', 'popout_ss5', 'popout_ss6', 'popout_ss8', 'popout_ss9'
for ($index = 0; $index -lt $shots.Count; $index++) {
    $inputPath = Join-Path $Source "screenshots\$($shots[$index]).png"
    Export-Resized $inputPath (Join-Path $Target "pop-out\shot-$($index + 1).jpg") 540 1200
}

Copy-Item (Join-Path $Source 'baner2.jpg') (Join-Path $Target 'pop-out\banner.jpg') -Force
Export-Resized (Join-Path $Source 'popout_icon_512px.jpg') (Join-Path $Target 'pop-out\icon.jpg') 256 256

Export-Icon (Join-Path $Target 'icon-48.png') 48
Export-Icon (Join-Path $Target 'apple-touch-icon.png') 180
Export-SocialCard (Join-Path $Target 'og.png')

Get-ChildItem $Target -Recurse -File | ForEach-Object { '{0,7:N0} KB  {1}' -f ($_.Length / 1KB), $_.FullName.Substring($Target.Length + 1) }
