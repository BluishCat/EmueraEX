# 上流2本を取得する。すでにあるものはフェッチして固定位置へ戻すだけ。
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ベース: Emuera.EM+EE。patches/ を当てる対象
$emPath = Join-Path $root 'upstream\emuera.em'
$emUrl = 'https://gitlab.com/EvilMask/emuera.em.git'

# 移植元: .netEmuera。読むだけで改変しない。
# ShinEraTenseiP 同梱の 0.2.6.0 と同一コミットに固定する
$netPath = Join-Path $root 'upstream\emuera.net'
$netUrl = 'https://gitlab.com/alnatiyan/EmueraDotNet.git'
$netCommit = '7b7dd3bf240eff4fdfc7094f4175de0e014532b7'

if (-not (Test-Path $emPath)) {
    git clone $emUrl $emPath
} else {
    git -C $emPath fetch origin
}

if (-not (Test-Path $netPath)) {
    git clone -b BugFix_Test $netUrl $netPath
} else {
    git -C $netPath fetch origin
}
git -C $netPath checkout $netCommit

Write-Host "emuera.em  : $(git -C $emPath log -1 --format='%h %ad %s' --date=short)"
Write-Host "emuera.net : $(git -C $netPath log -1 --format='%h %ad %s' --date=short)"
