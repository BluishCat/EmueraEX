# 統合パッチを andEmuera (Android 移植) 側へ配る。
# andEmuera 側の移植パッチは 10 番台なので、番号順に当てれば統合パッチが先になる。
param([string]$AndEmueraPath = 'D:\egame\era\andEmuera')

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $AndEmueraPath)) {
    throw "andEmuera が見つかりません: $AndEmueraPath"
}

$dest = Join-Path $AndEmueraPath 'patches'
Get-ChildItem (Join-Path $root 'patches') -Filter '*.patch' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dest $_.Name) -Force
    Write-Host "copy $($_.Name)"
}

Write-Host ''
Write-Host '当て直すときは andEmuera 側で:'
Write-Host "  git -C `"$AndEmueraPath\upstream\emuera.em`" checkout -- ."
Write-Host "  git -C `"$AndEmueraPath\upstream\emuera.em`" clean -fd"
Write-Host "  git -C `"$AndEmueraPath\upstream\emuera.em`" apply ../../patches/*.patch"
