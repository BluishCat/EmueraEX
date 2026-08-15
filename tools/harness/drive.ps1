# andEmuera WebHost (Emuera.TestHarness --serve) を叩く CLI ドライバ。
#
#   drive.ps1 -Cmds 'submit:1','click:400,300','enter','skip','wait:2' [-Shot out.png] [-Port 8321]
#
# 1 接続で順に送り、各コマンドの後に画面の更新 (generation の増加) を待つ。
# 画面は HTTP の /screen.png から取る (WebSocket のフレームは受け取らない)。
param(
    [string[]]$Cmds = @(),
    [string]$Shot,
    [int]$Port = 8321,
    [int]$W = 1512,
    [int]$H = 1037,
    [switch]$NoResize,
    [int]$WaitMs = 20000
)

$ErrorActionPreference = 'Stop'
$base = "http://localhost:$Port"

function Get-Status {
    (Invoke-WebRequest -Uri "$base/status" -UseBasicParsing -TimeoutSec 10).Content | ConvertFrom-Json
}

$ws = [System.Net.WebSockets.ClientWebSocket]::new()
$ct = [System.Threading.CancellationToken]::None
$ws.ConnectAsync([Uri]"ws://localhost:$Port/ws", $ct).Wait(10000) | Out-Null

function Send-Json($obj) {
    $json = $obj | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $seg = [System.ArraySegment[byte]]::new($bytes)
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait(10000) | Out-Null
}

# 画面を作らせない (フレームは HTTP で取る)。hello を送らないと resize が効かない実装ではない
if (-not $NoResize) {
    Send-Json @{ t = 'resize'; w = $W; h = $H }
    Start-Sleep -Milliseconds 500
}

foreach ($c in $Cmds) {
    $before = (Get-Status).generation
    $name, $arg = $c -split ':', 2

    switch ($name) {
        'submit' { Send-Json @{ t = 'submit'; v = "$arg" } }
        'enter'  { Send-Json @{ t = 'enter' } }
        'skip'   { Send-Json @{ t = 'skip' } }
        'click'  { $xy = $arg -split ','; Send-Json @{ t = 'click'; x = [int]$xy[0]; y = [int]$xy[1] } }
        'rclick' { $xy = $arg -split ','; Send-Json @{ t = 'click'; x = [int]$xy[0]; y = [int]$xy[1]; right = $true } }
        'move'   { $xy = $arg -split ','; Send-Json @{ t = 'move'; x = [int]$xy[0]; y = [int]$xy[1] } }
        'scroll' { Send-Json @{ t = 'scrollLines'; n = [int]$arg; x = [int]($W / 2); y = [int]($H / 2) } }
        'latest' { Send-Json @{ t = 'latest' } }
        'wait'   { Start-Sleep -Seconds ([int]$arg); Write-Output "wait $arg"; continue }
        default  { throw "unknown command: $c" }
    }

    # 画面が更新されるまで待つ (更新の無い操作もあるので打ち切る)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $WaitMs) {
        Start-Sleep -Milliseconds 200
        $s = Get-Status
        if ($s.generation -ne $before) { break }
    }
    $s = Get-Status
    Write-Output ("{0,-16} gen {1} -> {2}  error={3}  {4}ms" -f $c, $before, $s.generation, $s.error, $sw.ElapsedMilliseconds)
    if ($s.error) { Write-Output '  ★ IsError が立ちました'; break }
}

# 相手は簡易実装なので閉じ方に付き合わないことがある。閉じられなくても続ける
try { $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, '', $ct).Wait(3000) | Out-Null } catch { }
$ws.Dispose()

if ($Shot) {
    Start-Sleep -Milliseconds 400
    Invoke-WebRequest -Uri "$base/screen.png" -UseBasicParsing -TimeoutSec 30 -OutFile $Shot
    Write-Output "shot: $Shot ($((Get-Item $Shot).Length) bytes)"
}
