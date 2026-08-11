<#
.SYNOPSIS
    配布用パッケージを dist/ に作る。

.DESCRIPTION
    dist/EmueraEX-<版>.zip を作る。中身は exe・導入手順・ドキュメント・
    改変差分 (patches/)・ライセンス表示。

    patches/ を同梱するのは、上流 Emuera のライセンス (zlib 相当) が
    「ソースを変更した場合はそのことを明示する」ことを求めているため。
    改変の中身そのものが patches/ にある。

.EXAMPLE
    .\tools\pack.ps1
#>
[CmdletBinding()]
param(
    # 版。既定では Emuera.csproj の InformationalVersion から EXvN を取る
    [string]$Version,
    # exe を作り直さず、今ある dist\EmueraEX.exe を使う
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$repo   = Split-Path -Parent $PSScriptRoot
$dist   = Join-Path $repo 'dist'
$csproj = Join-Path $repo 'upstream\emuera.em\Emuera\Emuera.csproj'

Add-Type -AssemblyName System.IO.Compression.FileSystem

# zip を作る。SourceDir の中身を、その相対パスのまま入れる
# (呼び出し側が 1 段親を渡すので、zip の中は EmueraEX-<版>/… で包まれる)。
#
# Compress-Archive も ZipFile.CreateFromDirectory も、Windows PowerShell では
# エントリ名の区切りに \ を使う。Windows の展開ソフトは読めるが、Linux / macOS の
# unzip では 1 ファイル扱いになってしまうので、エントリを自分で足して / に直す。
function New-Zip {
    param([string]$SourceDir, [string]$Destination)

    if (Test-Path $Destination) { Remove-Item $Destination -Force }

    $root = (Resolve-Path $SourceDir).Path.TrimEnd('\')
    $archive = [System.IO.Compression.ZipFile]::Open($Destination, 'Create')
    try {
        foreach ($file in Get-ChildItem $root -Recurse -File) {
            $relative = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $file.FullName, $relative,
                [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    finally {
        $archive.Dispose()
    }
}

# ---------------------------------------------------------------- 事前確認

if (-not (Test-Path $csproj)) {
    throw @"
上流が見つかりません: $csproj
先に取得してください:
    .\tools\setup.ps1
    .\tools\apply.ps1
"@
}

$upstreamLicenses = Join-Path $repo 'upstream\emuera.em\Readme\License'

[xml]$proj = Get-Content $csproj
$fullVersion = $proj.SelectSingleNode('//PropertyGroup/InformationalVersion').InnerText
if (-not $Version) {
    if ($fullVersion -match '(EXv\d+)') { $Version = $Matches[1] }
    else { throw "InformationalVersion から EXvN を取れませんでした: $fullVersion" }
}

Write-Host "EmueraEX $fullVersion" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------- ビルド

$exe = Join-Path $dist 'EmueraEX.exe'
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot 'build.ps1')
    if ($LASTEXITCODE -ne 0) { throw "ビルドに失敗しました (終了コード $LASTEXITCODE)。" }
}
if (-not (Test-Path $exe)) { throw "exe がありません: $exe" }

# ---------------------------------------------------------------- 組み立て

# zip の中を <名前>-<版>/ で包むため、1 段親を挟んでフォルダごと固める
$stageRoot = Join-Path $dist '_stage'
if (Test-Path $stageRoot) { Remove-Item $stageRoot -Recurse -Force }
$stage = Join-Path $stageRoot "EmueraEX-$Version"
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item $exe $stage

# --- 改変差分とドキュメント
Copy-Item (Join-Path $repo 'patches') -Destination $stage -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'docs') | Out-Null
Copy-Item (Join-Path $repo 'docs\engine-diff.md') (Join-Path $stage 'docs')
Copy-Item (Join-Path $repo 'README.md') (Join-Path $stage 'docs\README.md')

# --- ライセンス表示
$licenseDir = Join-Path $stage 'licenses'
New-Item -ItemType Directory -Force -Path $licenseDir | Out-Null
Copy-Item (Join-Path $repo 'licenses\*') $licenseDir
if (Test-Path (Join-Path $upstreamLicenses 'LibWebp.LICENSE.txt')) {
    Copy-Item (Join-Path $upstreamLicenses 'LibWebp.LICENSE.txt') $licenseDir
}

# --- 出典表示 (zlib ライセンスの「改変した旨の明示」はここが本体)
$notice = @'
EmueraEX {FULLVERSION}

本ソフトウェアは、以下のソフトウェアを改変・統合して作られたものです。
EmueraEX の作者はオリジナルの作者ではありません。

    Emuera        (MinorShift 氏)       https://ja.osdn.net/projects/emuera/
    Emuera.EM+EE  (EvilMask 氏ほか)     https://gitlab.com/EvilMask/emuera.em
    Emuera.NET    (VVII 氏ほか)         https://gitlab.com/alnatiyan/EmueraDotNet

    Copyright (C) 2008- MinorShift, 妊）|дﾟ)の中の人, VVII

Emuera / Emuera.NET のライセンス (どちらも zlib ライセンス相当) に従い、
ソースを改変した旨をここに明示します。全文は licenses/ にあります。

上流ソースへの変更は、すべて patches/ に差分として同梱しています。
上流を取得して patches/ を順に当てれば、この exe と同じものが作れます。
手順は docs/README.md にあります。

    https://github.com/BluishCat/EmueraEX

同梱しているもの:

    libwebp                 Copyright (c) Google Inc.
                            BSD 3-Clause            licenses/LibWebp.LICENSE.txt

    SQLite (e_sqlite3)      パブリックドメイン      https://www.sqlite.org/copyright.html

    Microsoft.Data.Sqlite   Copyright (c) .NET Foundation and Contributors
                            MIT License             https://github.com/dotnet/efcore/blob/main/LICENSE.txt

    SQLitePCLRaw            Copyright (c) Eric Sink
                            Apache License 2.0      https://github.com/ericsink/SQLitePCL.raw/blob/master/LICENSE.txt

    System.IO.Hashing       Copyright (c) .NET Foundation and Contributors
                            MIT License             https://github.com/dotnet/runtime/blob/main/LICENSE.TXT

本ソフトウェアは「現状のまま」で提供され、何らの保証もありません。
本ソフトウェアの使用によって生じるいかなる損害についても、作者は責任を負いません。

このリポジトリの内容は Claude Code (Anthropic) を使って作りました。
'@
$notice = $notice.Replace('{FULLVERSION}', $fullVersion)
Set-Content -Path (Join-Path $stage 'NOTICE.txt') -Value $notice -Encoding utf8

# --- 導入手順
$readme = @'
EmueraEX {FULLVERSION}

era 系エンジンの 2 系統 Emuera.EM+EE と Emuera.NET (.netEmuera) を統合したものです。
どちらの系統のバリアントも、この exe 1 本で動きます。


== 1. 必要なもの ==

.NET 10 のランタイム (Desktop 込み) が要ります。自己完結型ではありません。
入っていない場合は起動時にダウンロード先が案内されます。

    https://dotnet.microsoft.com/download/dotnet/10.0
    → ".NET Desktop Runtime" の x64


== 2. 入れる ==

EmueraEX.exe をゲームフォルダに置いて、そのまま実行します。
元から入っている Emuera 系の exe は消さずに残しておいて構いません。

    <ゲームフォルダ>\
        EmueraEX.exe    ← ここに置く
        emuera.config
        csv\
        erb\
        sav\

ShinEraTenseiP のように中身が Data\ に入っているバリアントも、そのままで動きます。
exe の直下に erb が無く Data\erb があれば、自動で Data\ を見にいきます。

ゲームフォルダを汚したくない場合は、外から指すこともできます。

    EmueraEX.exe --ExeDir "C:\era\eraTOWN"

emuera.config / setting.json / sav はそのまま引き継がれます。


== 3. 統合されている機能 ==

.netEmuera 専用だった次のものが、EM+EE 側でも使えます。

    MATCHALL
    GETCSVNOBYNAME / GETCSVNOBYNICKNAME / GETCSVNOBYCALLNAME / GETCSVNOBYMASTERNAME
    HASH_XXH3 / HASH_XXH32
    DICT_*      (6 個)
    G_POLYGON_* (4 個)
    SQL_*       (9 個。セーブデータ連携込み)
    VARI / VARS (右辺にユーザ定義関数を書ける。#FUNCTION 中でも使える)
    HTML_PRINT の <div> 方言 (自動サイズ、属性の別名、入れ子、絶対配置)
    setting.json の .netEmuera 由来キー

詳しくは docs/engine-diff.md を見てください。


== 4. ゲームパッド ==

XInput 対応パッド (Xbox 互換) で操作できます。

    選択カーソル移動      十字キー / 左スティック
    決定 (左クリック相当) A
    右クリック相当        X
    選択解除・入力欄クリア B
    履歴スクロール        LB / RB

左右は同じ行の隣のボタンへ、上下は一番近い上下の行の中で横位置が近いボタンへ動きます。
X はマウスの右クリックと同じ扱いで、テキスト待ちで押せば以降のメッセージ待ちを
飛ばして読み進めます。

割り当ては setting.json の GamePad で変えられます。"Enabled": false で無効化できます。
ウィンドウが前面にないときは反応しません。


== 5. SQL_* について ==

SQLite を使います。DB の実体は sav\temp_db\ に置かれ、SAVEDATA / SAVEGAME 時に
セーブデータの隣へコピーされ、LOADDATA / LOADGAME 時に書き戻されます。
起動時に temp_db は作り直されるので、セーブせずに終了した変更は残りません。

SQLite 一式は exe に同梱されているので、別途置く必要はありません。


== 6. 元に戻す ==

EmueraEX.exe を消して、元の exe を使ってください。
セーブデータは共通なので、そのまま続きから遊べます。


== 7. 出典 ==

本ソフトウェアは Emuera / Emuera.EM+EE / Emuera.NET の改変版です。
オリジナルの作者ではありません。詳しくは NOTICE.txt と licenses/ を見てください。
上流への変更は patches/ に差分として同梱しています。

    https://github.com/BluishCat/EmueraEX
'@
$readme = $readme.Replace('{FULLVERSION}', $fullVersion)
Set-Content -Path (Join-Path $stage 'README.txt') -Value $readme -Encoding utf8

$zip = Join-Path $dist "EmueraEX-$Version.zip"
New-Zip -SourceDir $stageRoot -Destination $zip
Remove-Item $stageRoot -Recurse -Force

# ---------------------------------------------------------------- 結果

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
Set-Content -Path (Join-Path $dist 'SHA256SUMS.txt') `
    -Value "$hash  $(Split-Path -Leaf $zip)" -Encoding ascii

Write-Host ""
Write-Host "できました:" -ForegroundColor Green
Write-Host ("  {0}  ({1:N1} MB)" -f $zip, ((Get-Item $zip).Length / 1MB))
Write-Host ""
Write-Host "  $hash  $(Split-Path -Leaf $zip)"
