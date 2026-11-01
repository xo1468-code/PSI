# 로컬 서버: 프로그램 폴더를 http://localhost:<Port>/ 로 제공하고,
# 기출문제 추가 도구가 보내는 data/·images/ 파일 저장 요청(POST /__save)을 처리한다.
param([int]$Port = 8765, [string]$Open = '')
$Root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.pdf'='application/pdf'; '.css'='text/css; charset=utf-8'; '.png'='image/png' }

Add-Type -AssemblyName System.Web.Extensions
$json = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$json.MaxJsonLength = [int]::MaxValue

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "서버 실행 중: http://localhost:$Port/  (이 창을 닫으면 종료됩니다)"
if ($Open) { Start-Process "http://localhost:$Port/$Open" }

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request; $res = $ctx.Response
  try {
    $rel = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
    if ($req.HttpMethod -eq 'POST' -and $rel -eq '__save') {
      $reader = New-Object System.IO.StreamReader($req.InputStream, [System.Text.Encoding]::UTF8)
      $body = $json.DeserializeObject($reader.ReadToEnd())
      $target = [System.IO.Path]::GetFullPath((Join-Path $Root $body['path']))
      $okDirs = @((Join-Path $Root 'data'), (Join-Path $Root 'images')) | ForEach-Object { [System.IO.Path]::GetFullPath($_) + '\' }
      if (-not ($okDirs | Where-Object { $target.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })) { throw "허용되지 않은 경로: $target" }
      New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
      if ($body['base64']) { [System.IO.File]::WriteAllBytes($target, [Convert]::FromBase64String($body['content'])) }
      else { [System.IO.File]::WriteAllText($target, $body['content'], $utf8) }
      $res.StatusCode = 200
    } else {
      if ($rel -eq '') { $rel = 'index.html' }
      $path = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))
      if ($path.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $ext = [System.IO.Path]::GetExtension($path).ToLower()
        if ($types.ContainsKey($ext)) { $res.ContentType = $types[$ext] }
        $res.Headers.Add('Cache-Control', 'no-store')
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } else { $res.StatusCode = 404 }
    }
  } catch {
    Write-Host "오류: $_"
    $res.StatusCode = 500
  }
  $res.Close()
}
