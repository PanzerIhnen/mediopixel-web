param(
    [int]$Port = 8080,
    [string]$Root = (Join-Path $PSScriptRoot '..\docs')
)

$Root = (Resolve-Path $Root).Path
$contentTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.svg'  = 'image/svg+xml'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.ico'  = 'image/x-icon'
    '.woff2' = 'font/woff2'
    '.xml'  = 'application/xml'
    '.txt'  = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
"Serving $Root at http://localhost:$Port/"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        $requestPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
        $path = [IO.Path]::GetFullPath((Join-Path $Root $requestPath.TrimStart('/')))
        $status = 200

        if (-not $path.StartsWith($Root)) {
            $path = $null
        }
        elseif (Test-Path $path -PathType Container) {
            # GitHub Pages redirects too; relative links break without the trailing slash.
            if (-not $requestPath.EndsWith('/')) {
                $response.Redirect("$requestPath/")
                $response.Close()
                continue
            }
            $path = Join-Path $path 'index.html'
        }

        if (-not $path -or -not (Test-Path $path -PathType Leaf)) {
            $status = 404
            $path = Join-Path $Root '404.html'
        }

        $bytes = [IO.File]::ReadAllBytes($path)
        $contentType = $contentTypes[[IO.Path]::GetExtension($path).ToLowerInvariant()]
        if (-not $contentType) {
            $contentType = 'application/octet-stream'
        }

        $response.StatusCode = $status
        $response.ContentType = $contentType
        $response.Headers['Cache-Control'] = 'no-store'
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.Close()
        "$status $requestPath"
    }
}
finally {
    $listener.Stop()
}
