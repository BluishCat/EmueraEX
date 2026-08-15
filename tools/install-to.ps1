# 統合版 Emuera をゲームフォルダへ入れる。
#
# 元から入っている exe には触らない。名前が違えば共存できるし、共存していないと
# 新旧の描画を並べて比べられない（ハーネスは SkiaSharp 描画なので、画素レベルの
# 見た目は実機で 2 本を突き合わせるしか確認手段が無い）。
# 上書きしてしまう場合、つまり同じ名前の exe が既にある場合だけ .bak へ退避する。
#
#   .\tools\install-to.ps1 'D:\egame\era\eraTOWN'
#   .\tools\install-to.ps1 'D:\egame\era\ShinEraTenseiP'   # Data\ 配置でもそのままでよい
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    # 同名 exe があっても退避せず上書きする
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'

if (-not (Test-Path $dist)) { throw "dist がありません。先に .\tools\build.ps1 を実行してください" }
if (-not (Test-Path $GameDir)) { throw "ゲームフォルダが見つかりません: $GameDir" }

$ours = Get-ChildItem $dist -Filter '*.exe' | Select-Object -First 1
if (-not $ours) { throw "dist に exe がありません。先に .\tools\build.ps1 を実行してください" }

# 自分の以前のビルドか（版表記に EXvN が入っている）。これは黙って上書きしてよい
function Test-OurBuild {
    param([string]$Path)
    try { return ((Get-Item $Path).VersionInfo.ProductVersion -match 'EXv\d+') }
    catch { return $false }
}

# 上書きしてしまうものだけ退避する。名前が違う exe には触らない。ゲームデータにも触らない
$backedUp = @()
foreach ($src in Get-ChildItem $dist -Filter '*.exe' -File) {
    $dest = Join-Path $GameDir $src.Name
    if (-not (Test-Path $dest)) { continue }
    if (Test-OurBuild $dest) { continue }
    if ($NoBackup) {
        Write-Host "上書き: $($src.Name)（-NoBackup 指定のため退避しません）" -ForegroundColor Yellow
        continue
    }
    $bak = "$dest.bak"
    $n = 1
    while (Test-Path $bak) { $bak = "$dest.bak$n"; $n++ }
    Move-Item $dest $bak
    $backedUp += (Split-Path -Leaf $bak)
    Write-Host "同名のため退避: $($src.Name) -> $(Split-Path -Leaf $bak)" -ForegroundColor Yellow
}

# 入れるのは exe だけ。pack.ps1 を走らせた後の dist には zip や SHA256SUMS.txt も居るので、
# 中身を丸ごと配るとゲームフォルダを汚す
Get-ChildItem $dist -Filter '*.exe' -File | ForEach-Object { Copy-Item $_.FullName $GameDir -Force }

Write-Host ''
Write-Host "導入しました: $GameDir\$($ours.Name)"
Write-Host 'セーブと emuera.config / setting.json はそのまま使われます。'

# 共存している Emuera 系 exe を見せる。新旧を並べて比べるにはどちらも要る
$others = @(Get-ChildItem $GameDir -Filter '*.exe' | Where-Object { $_.Name -like '*muera*' -and $_.Name -ne $ours.Name })
if ($others.Count -gt 0) {
    Write-Host ''
    Write-Host '元の exe はそのまま残しています（名前が違うので共存できます）:'
    $others | ForEach-Object { Write-Host "    $($_.Name)" }
    Write-Host '  新旧の描画を比べるときはどちらも必要なので、消さずに置いておくことを勧めます。'
}

if ($backedUp.Count -gt 0) {
    Write-Host ''
    Write-Host "同名だったため退避したもの: $($backedUp -join ', ')" -ForegroundColor Yellow
    Write-Host '  元に戻すときは .bak を外してください。'
}

# 過去の版が退避したまま復帰していないものを知らせる
$orphans = @(Get-ChildItem $GameDir -Filter '*.exe.bak' | Where-Object { -not (Test-Path ($_.FullName -replace '\.bak$','')) })
if ($orphans.Count -gt 0) {
    Write-Host ''
    Write-Host '退避されたまま戻っていない exe があります:' -ForegroundColor Yellow
    $orphans | ForEach-Object { Write-Host "    $($_.Name)  ->  戻すなら $($_.Name -replace '\.bak$','')" }
}
