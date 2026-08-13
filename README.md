# EmueraEX

era 系エンジンの2系統 **Emuera.EM+EE** と **Emuera.NET（.netEmuera）** を統合し、
どちらのバリアントも同じ exe で動かすための改変です。

**このリポジトリにエンジン本体のソースは入っていません。** 上流を clone して
`patches/` の差分を当てる形で、変更点だけを管理しています。

## これは改変版です

本ソフトウェアは [Emuera](https://ja.osdn.net/projects/emuera/)（MinorShift 氏）および
その派生である [Emuera.EM+EE](https://gitlab.com/EvilMask/emuera.em)（EvilMask 氏 / Enter 氏）を**改変**したものです。
移植元として [Emuera.NET](https://gitlab.com/alnatiyan/EmueraDotNet)（VVII 氏 / alnatiyan 氏）を参照しています。
オリジナルの作者ではありません。

Emuera / Emuera.NET のライセンス（どちらも zlib ライセンス相当。全文は [licenses/](licenses/)）に従い、
改変した旨をここに明示します。上流ソースへの変更はすべて `patches/` に差分として保管しています。

```
Copyright (C) 2008- MinorShift, 妊）|дﾟ)の中の人, VVII
```

## 制作について

**このリポジトリの内容は [Claude Code](https://claude.com/claude-code)（Anthropic）を使って作りました。**
両エンジンの語彙差分の突き合わせ、パッチの作成、実ゲームでの動作確認まで含みます。

## 方針

**EM+EE をベースに、Emuera.NET 側の機能を移植する**（一方向）。

命令・式中関数・変数を突き合わせた結果、EM+EE がほぼ上位互換でした。
逆方向（.NET をベースに EM+EE を移植）は134個の移植になり非現実的です。
詳しくは [docs/engine-diff.md](docs/engine-diff.md)。

上流は `upstream/` に clone するだけで改変せず、変更は `patches/*.patch` に隔離します。
この流儀は Android 移植版 andEmuera と揃えてあり、同じパッチを Android 側にも適用できます。

## 構成

```
EmueraEX/
├─ upstream/          ← setup.ps1 が clone する（このリポジトリには含まれない）
│   ├─ emuera.em/     EvilMask/emuera.em (master)               ベース。patches を当てる対象
│   └─ emuera.net/    alnatiyan/EmueraDotNet (BugFix_Test 固定)  移植元。読むだけ
├─ patches/           EM+EE に当てる統合パッチ（番号順に適用）
├─ tools/             setup.ps1 / apply.ps1 / build.ps1 / pack.ps1 / install-to.ps1 / sync-android.ps1
├─ docs/              engine-diff.md（両エンジンの差分一覧）
└─ licenses/          上流のライセンス全文
```

## ビルド

必要なもの:

- .NET 10 SDK
- Visual Studio の MSBuild
  （既定構成が WMPLib の COM 参照を使うため `dotnet build` では通りません。
   音声に NAudio を使う `Release-NAudio` 構成なら `dotnet build` でも可）

```powershell
.\tools\setup.ps1     # 上流2本を取得
.\tools\apply.ps1     # patches を順に適用
.\tools\build.ps1     # dist\EmueraEX.exe を作る
```

`build.ps1` は publish で単一ファイル化するので、出来上がりは **`dist\EmueraEX.exe` の1本だけ**です
（約 4.9MB）。依存 DLL もネイティブライブラリ（libwebp / e_sqlite3）も exe に同梱され、
実行時に展開されます。上流の配布物と同じ作り方です。

exe の名前は `-Name` で変えられます。単一ファイルなので後から手でリネームしても動きます。

```powershell
.\tools\build.ps1 -Name Emuera.NET統合版
```

## 配布物を作る

```powershell
.\tools\pack.ps1
```

`dist\EmueraEX-<版>.zip` が出ます（約 2.2MB）。中身は exe・導入手順（`README.txt`）・
出典表示（`NOTICE.txt`）・`docs/`・`licenses/`・**`patches/`** です。
patches を同梱するのは、zlib ライセンスが求める「改変した旨の明示」の本体が
そこにあるためで、上流に当て直せば同じ exe を再現できます。

`dist\SHA256SUMS.txt` も一緒に出ます。

**リリースのたびに `Emuera.csproj` の `InformationalVersion` の `EXvN` を +1 してください。**
zip 名と中の版表記はここから取っています。

## 版表記

画面右上に出る版表記は **`EmueraEX 1.824+v24+EMv18+EEv56+EXv7`** です。
`EEv56` までがベースの EM+EE の版、`EXv7` が統合レイヤの版で、
統合パッチを増やしたらここを上げます（`Emuera.csproj` の `InformationalVersion`）。
名前そのものは `Runtime/Utils/Sys.cs` の `EmueraVersionText` です。

## 使う

`dist\EmueraEX.exe` をゲームフォルダに置くだけです。スクリプトを使うと、
元から入っていた Emuera 系 exe を `.bak` に退避してから入れます。

```powershell
.\tools\install-to.ps1 'C:\era\eraTOWN'
```

`Data\` 配置のバリアント（ShinEraTenseiP など）もそのままで構いません。
exe の直下に `ERB` が無く `Data\ERB` があれば自動で `Data\` を見にいきます。

ゲームフォルダを汚したくない場合は `--ExeDir` で外から指すこともできます。

```powershell
.\dist\EmueraEX.exe --ExeDir "C:\era\eraTOWN"
```

**`--ExeDir` は `ERB` があるフォルダを直接渡してください。**
上の `Data\` の自動判別は exe を置いて起動したときだけのもので、`--ExeDir` を
明示すると通りません（`Program.cs` の `ResolveGameDir` を経由しないため）。
`Data\` 配置のバリアントでは `Data` まで含めて渡します。渡し先を間違えると
タイトルバーが「フォルダなし」になって起動しません。

```powershell
.\dist\EmueraEX.exe --ExeDir "C:\era\ShinEraTenseiP\Data"
```

**注意**

- .NET 10 のランタイム（Desktop 込み）が必要です。自己完結型ではありません
- `emuera.config` / `setting.json` / `sav` はそのまま引き継がれます
- 元に戻すには `.bak` を戻してください

## 適用済みのパッチ

| パッチ | 内容 |
|---|---|
| `00-data-dir-autodetect` | exe 直下に `ERB` が無く `Data\ERB` があれば `Data\` を実行ディレクトリとみなす（.netEmuera 系バリアントの配置）。`--ExeDir` 指定時は無効 |
| `01-matchall` | `MATCHALL` 命令。配列中で値に一致した要素の添字を `RESULT` に列挙する |
| `02-getcsvnoby-hash` | `GETCSVNOBY{NAME,NICKNAME,CALLNAME,MASTERNAME}` と `HASH_XXH3` / `HASH_XXH32` |
| `03-json-config` | `setting.json` の .netEmuera 由来キー4つ。`UseRenameInCharaCSV` は挙動も実装 |
| `04-vari-deferred-parse` | `VARI`/`VARS` の右辺解析を遅延させ、`METHOD_SAFE` を付与。ユーザ定義関数を右辺に書けるようにし、`#FUNCTION` 中でも使えるようにする |
| `05-div-dialect` | `HTML_PRINT` の `<div>` を .netEmuera の方言に合わせる。width/height 省略時の自動サイズ、`background_color` / `border_width` / `border_color` の別名、`display='absolute-lefttop'` / `'absolute-leftbottom'` |
| `06-gamepad` | ゲームパッド（XInput）でボタンを選んで決定できるようにする |
| `07-dict-polygon-sql` | 残りの .netEmuera 専用関数。`DICT_*` 6個・`G_POLYGON_*` 4個・`SQL_*` 9個。SQL はセーブデータ連携込み |
| `08-div-nesting` | `<div>` の入れ子と閉じ忘れ（`</div>` を `<div>` と打ち間違えた形）を許容する。あわせて SQL の起動時初期化が失敗しても起動を止めないようにする |
| `09-div-lenient-attrs` | `<div>` の属性に紛れた不正なトークン（`<div xpos='..'  + ypos='..'>` のような余分な `+`）を読み飛ばす |
| `10-gamepad-2d-nav` | パッドの選択移動を画面上の位置で行う。左右は行内の隣へ、上下は上/下の行の横位置が近いボタンへ。`<div>` の中のボタンも選べるようにする |
| `11-gamepad-primitive-key` | `INPUTMOUSEKEY` など生の入力を待っている画面で、パッドの十字キーを矢印キーとして渡す |
| `12-gamepad-primitive-click` | 同じ画面で決定/キャンセルを**クリック**として送る。キーだけでは進まないゲームがあるため |
| `13-gamepad-rightclick` | マウスの右クリックに当たるパッドボタン（既定 X）。テキストの飛ばし読みと、右クリック決定（`RESULT:1` に 2）に使う |
| `14-version-text` | 画面右上の版表記を `EmueraEX 1.824+v24+EMv18+EEv56+EXvN` にする。git のコミットハッシュは付けない |
| `15-div-unknown-attrs` | `<div>` の知らない属性名を読み飛ばす。.netEmuera は HTML パーサなので綴りの間違いを素通しし、その状態で配布されているゲームがある |
| `16-html-bare-attr-values` | `<div xpos=850>` のような引用符の無い属性値を許す。HTML の規則どおり「空白か `>` まで」を値として読む。字句解析に渡す前に引用符を補うので、全タグに効く |
| `17-div-in-button` | `<button>` / `<font>` の中で `<div>` を開けるようにする。.netEmuera では単に入れ子になるだけで、`<button><div>…</div></button>` を作るゲームがある |
| `18-font-size` | `<font size>` で文字の大きさを変えられるようにする。既定は設定フォントサイズに対する%、`px` を付ければピクセル指定 |
| `19-img-xpos` | `<img xpos>` を受け取る。.netEmuera でも値を使うのは絶対配置のときだけなので、受け取って捨てる |
| `20-div-in-button-click` | `<button><div>…</div></button>` で `<div>` の矩形をそのボタンの当たり判定にする。マウス／タップで枠を押して選べるようにする |
| `21-div-in-button-click-nested` | 20 を入れ子でも効かせる。`<div><button><div>…</div></button></div>` のようにボタンが `<div>` の中に居る形（隊列表示や調教画面がこれ）で枠を押して選べるようにし、カーソルを乗せたときの色も変わるようにする |
| `22-div-hitbox-rect` | `<div>` の当たり判定の矩形を描画に合わせる。枠（margin/border/padding）のぶん下にずれていたのを直し、大きさ省略時は中身の実寸まで広げる（行高を超える画像のはみ出した部分を押せるようにする） |
| `23-html-island-hittest` | `HTML_PRINT_ISLAND` の中のボタンをクリックできるようにする。従来は描画されるだけで当たり判定に入っていなかった。あわせて `display='absolute-*'` の `<div>` の当たり判定を描画と同じ原点で出す |
| `24-html-bare-lt` | タグにならない `<` を文字として出す。HTML の規則どおり「次が英字でも `/` でもなければタグではない」と見る。`[<]減` のような本文で解析が止まっていた（ShinEraTenseiP の調教画面がこれで開けなかった） |

## 動作状況

| バリアント | エンジン | 状態 |
|---|---|---|
| eraTOWN 143.30 | EM+EE | ○ タイトル到達。素の EM+EE と描画差なし |
| erablue_resort 0.108 | EM+EE | ○ タイトル到達。素の EM+EE と描画差なし |
| ShinEraTenseiP 0.5.8 | .netEmuera | ○ チュートリアル戦闘まで確認。隊列表示（`FORMATION.ERB`）・ショップ・TALK の敵選択・悪魔会話・調教画面（`USERCOM.ERB`）が通る。原版の .netEmuera とほぼ同じ見た目 |

EM+EE 系2本は素の EM+EE と画面をピクセル比較し、差はバージョン文字列（コミットハッシュ）のみでした。

ShinEraTenseiP は原版の .netEmuera と隊列表示をピクセル比較しました。中身・大きさ・色は同じで、
入れ子の `<div>` で置いた要素（スキル行とキャラ画像）だけが 1px ずれます。
`<div>` の入れ子まわり（パッチ05/08）由来で、16/17 とは別の話です。

## ゲームパッド

XInput 対応パッド（Xbox 互換）で操作できます。既定の割り当て:

| 操作 | 既定 |
|---|---|
| 選択カーソル移動 | 十字キー / 左スティック |
| 決定（左クリック相当） | A |
| 選択解除・入力欄クリア | B |
| 右クリック相当 | X |
| 履歴スクロール | LB / RB |

**X（右クリック相当）**はマウスの右クリックとまったく同じ扱いです。
テキスト待ちで押せば以降のメッセージ待ちを飛ばして読み進め、
ボタンを選んだ状態で押せば右クリックでの決定（ゲームからは `RESULT:1` が 2 に見える）になります。
右クリックを「戻る」に割り当てているゲームでは、その通りに動きます。

移動は画面上の位置で決まります。**左右**は同じ行の隣のボタンへ（行末まで行けば次の行へ）、
**上下**は一番近い上/下の行の中で、今の横位置に一番近いボタンへ移動します。
`<div>` の中に置かれたボタンも対象です。

`INPUTMOUSEKEY` のように生の入力を待つ画面では、選択カーソルではなく
マウス・キーボードと同じ入力として渡します。

| パッド | 送るもの |
|---|---|
| A | 左クリック（カーソルの現在地） |
| X | 右クリック（同上） |
| B | Esc キー |
| 十字キー | 矢印キー |

決定をキーではなくクリックにしているのは、キーだけでは進まないゲームがあるためです
（ShinEraTenseiP のターンエンドがこれに当たります）。

割り当ては `setting.json` の `GamePad` で変えられます。値は XInput のボタンビットで、
複数割り当ては OR で足します（`0x1000` A / `0x2000` B / `0x4000` X / `0x8000` Y /
`0x0100` LB / `0x0200` RB / `0x0001` 上 / `0x0002` 下 / `0x0004` 左 / `0x0008` 右 /
`0x0010` START / `0x0020` BACK）。`"Enabled": false` で無効化できます。

era 系は「数字を打つかボタンをクリックする」しか無いため、パッドは画面上のボタンを
選ぶ方式にしています。決定はマウス左クリックと同じ経路に流すので、ERB から見た挙動は
クリックしたときと同じです。ウィンドウが前面にないときは反応しません。

## SQL_* について

`SQL_*` は SQLite を使います。DB の実体は `sav/temp_db/` に置かれ、
`SAVEDATA`/`SAVEGAME` 時にセーブデータの隣（`sav/save00/` のようなフォルダ）へコピーされ、
`LOADDATA`/`LOADGAME` 時に書き戻されます。起動時に `temp_db` は作り直されるので、
セーブせずに終了した変更は残りません。

SQLite 一式（`Microsoft.Data.Sqlite.dll` / `SQLitePCLRaw.*.dll` / ネイティブの `e_sqlite3.dll`）は
`EmueraEX.exe` に同梱されているので、別途置く必要はありません。

## Android (andEmuera) へ配る

Android 移植版 **andEmuera**（別リポジトリ）は同じ上流に同じパッチを当てて動きます。

```powershell
.\tools\sync-android.ps1 -AndEmueraPath <andEmuera のパス>
```

`patches/` を andEmuera 側へコピーします。andEmuera 自身の移植パッチは
`10-android-portability` / `11-performance` なので、ファイル名順に当てれば
統合パッチが先になります（この順序でないと当たりません）。

Android 側の追加事項:

- `Microsoft.Data.Sqlite.Core` + `SQLitePCLRaw.bundle_e_sqlite3` を `Emuera.Core.csproj` に追加済み
- `Runtime/Utils/GamePad.cs` は XInput の P/Invoke なので `Emuera.Core.csproj` で除外。
  ゲームパッド操作自体は WinForms 前提のため Android では無効
- `G_POLYGON_*` は既存の SkiaSharp 裏打ちシム（`Compat/Drawing/Graphics.cs`）がそのまま使えた

TestHarness で確認済み（Windows と同じ値）:

```
MATCHALL count=3 idx=0,2,4 / HASH_XXH3=8696274497037089104 / GETCSVNOBYNICKNAME=20
DICT long=1234 str=V / G_POLYGON 内側=4278255360 外側=0 / SQL count=1 name=seven / VARI=300
```
