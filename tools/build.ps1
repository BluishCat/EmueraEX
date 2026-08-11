# 統合版 Emuera をビルドして dist\Emuera.exe を作る。
#
# csproj が PublishSingleFile を持っているので publish すると exe 1本にまとまる
# (ネイティブDLL — libwebp / e_sqlite3 — も exe に同梱され、実行時に展開される)。
# 上流の配布物と同じ作り方。
#
# 既定構成は WMPLib の COM 参照を使うため dotnet publish では通らない。
# Visual Studio の MSBuild.exe が要る。
param(
    [ValidateSet('Release', 'Release-NAudio', 'Debug', 'Debug-NAudio')]
    [string]$Configuration = 'Release',
    [ValidateSet('x64', 'x86')]
    [string]$Platform = 'x64',
    # 出来上がる exe の名前。単一ファイルなのでリネームしても動く
    # (AssemblyName は変えない。上流のリソース名や manifest に触らずに済むため)
    [string]$Name = 'EmueraEX'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $root 'upstream\emuera.em\Emuera\Emuera.csproj'

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) {
    throw 'vswhere が見つかりません。Visual Studio (MSBuild 込み) を入れてください'
}
$msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) {
    throw 'MSBuild.exe が見つかりません'
}

$rid = if ($Platform -eq 'x86') { 'win-x86' } else { 'win-x64' }
$publishDir = Join-Path $root 'obj\publish'

# SatelliteResourceLanguages: System.CommandLine などの各国語リソースを日本語だけにする。
#   付けないと cs/de/es/... のフォルダが13個ぶら下がる
& $msbuild $proj /t:Restore`;Publish `
    /p:Configuration=$Configuration /p:Platform=$Platform `
    /p:RuntimeIdentifier=$rid /p:SelfContained=false `
    /p:PublishDir=$publishDir\ `
    /p:SatelliteResourceLanguages=ja `
    /v:m /nologo
if ($LASTEXITCODE -ne 0) { throw "ビルドに失敗しました (exit=$LASTEXITCODE)" }

$dist = Join-Path $root 'dist'
if (Test-Path $dist) { Get-ChildItem $dist -Recurse | Remove-Item -Recurse -Force }
New-Item -ItemType Directory -Force -Path $dist | Out-Null

# pdb は配布に不要なので置かない
Get-ChildItem $publishDir -File | Where-Object { $_.Extension -ne '.pdb' } | ForEach-Object {
    $target = if ($_.Name -eq 'Emuera.exe') { "$Name.exe" } else { $_.Name }
    Copy-Item $_.FullName (Join-Path $dist $target) -Force
}

Write-Host ''
Get-ChildItem $dist | ForEach-Object { "  {0}  {1:N0} bytes" -f $_.Name, $_.Length }
Write-Host "dist: $dist"
