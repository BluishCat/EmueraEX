# 統合版 Emuera をゲームフォルダへ入れる。
# 既にある Emuera 系の exe は .bak にリネームして残す（消さない）。
#
#   .\tools\install-to.ps1 'D:\egame\era\eraTOWN'
#   .\tools\install-to.ps1 'D:\egame\era\ShinEraTenseiP'   # Data\ 配置でもそのままでよい
param(
    [Parameter(Mandatory = $true)][string]$GameDir,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root 'dist'

if (-not (Test-Path $dist)) { throw "dist がありません。先に .\tools\build.ps1 を実行してください" }
if (-not (Test-Path $GameDir)) { throw "ゲームフォルダが見つかりません: $GameDir" }

$ours = Get-ChildItem $dist -Filter '*.exe' | Select-Object -First 1
if (-not $ours) { throw "dist に exe がありません。先に .\tools\build.ps1 を実行してください" }

# 元から入っていた Emuera 系 exe を退避。ゲームデータには触らない。
# 自分が入れる exe は上書きするだけで、退避対象にしない（再導入で .bak が増えないように）
if (-not $NoBackup) {
    Get-ChildItem $GameDir -Filter '*.exe' | Where-Object { $_.Name -like '*muera*' -and $_.Name -ne $ours.Name } | ForEach-Object {
        $bak = "$($_.FullName).bak"
        if (-not (Test-Path $bak)) {
            Move-Item $_.FullName $bak
            Write-Host "退避: $($_.Name) -> $($_.Name).bak"
        }
    }
}

# dist は exe 1本だけ。単一ファイルなのでリネームしても動く
Get-ChildItem $dist -File | ForEach-Object { Copy-Item $_.FullName $GameDir -Force }

Write-Host ''
Write-Host "導入しました: $GameDir\$($ours.Name)"
Write-Host 'セーブと emuera.config / setting.json はそのまま使われます。'
Write-Host '元に戻すときは .bak を戻してください。'
