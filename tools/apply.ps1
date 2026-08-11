# patches/ を番号順に emuera.em へ当てる。
# 当て直したいときは -Reset を付けて master に戻してから当てる。
param([switch]$Reset)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$emPath = Join-Path $root 'upstream\emuera.em'

if ($Reset) {
    git -C $emPath checkout -- .
    git -C $emPath clean -fd
    git -C $emPath checkout master
}

Get-ChildItem (Join-Path $root 'patches') -Filter '*.patch' | Sort-Object Name | ForEach-Object {
    Write-Host "apply $($_.Name)"
    git -C $emPath apply $_.FullName
}
Write-Host 'done'
