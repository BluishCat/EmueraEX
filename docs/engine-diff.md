# Emuera.EM+EE と Emuera.NET(.netEmuera) の差分

2026-08-11 時点の実測。再調査を繰り返さないための記録。
調査・実装・検証は [Claude Code](https://claude.com/claude-code)（Anthropic）を使って行った。

## 血縁関係

2つは無関係な実装ではなく、**同一コードベースの兄弟フォーク**。

| | Emuera.EM+EE | Emuera.NET（.netEmuera） |
|---|---|---|
| リポジトリ | `gitlab.com/EvilMask/emuera.em` master | `gitlab.com/alnatiyan/EmueraDotNet` **BugFix_Test** |
| 版 | 1.824+v24+EMv18+EEv56 | 0.2.6.0 `7b7dd3bf`（ShinEraTenseiP 同梱の実物） |
| 由来 | 2018〜。Enter 氏 588 commits / EvilMask 氏 204 commits | 2024-04 に EM+EE から分岐（VVII 氏 → alnatiyan 氏） |
| TFM | net10.0-windows | net9.0-windows7.0 |
| 描画 | WinForms + TextRenderer | SkiaSharp |
| HTML | 自前トークナイザ | AngleSharp |
| ルート名前空間 | `MinorShift.Emuera` | 同左 |
| ソース構成 | `Runtime/` + `UI/` | ほぼ同一（ファイル名まで一致） |

- EM+EE は **EEv47 で VVII 氏の master（2024-06-30 時点）を丸ごとマージ済み**。v54 / v55 でも追加パッチを取り込んでいる
- `setting.json` はファイル名もキー名も共通
- EM+EE のリモートに `VVII-SkiaSharp` / `VVII-cherry-pick` / `VVII-commits` ブランチがある

## 語彙差分（列挙型の突き合わせ）

| 種別 | .NET のみ | EM+EE のみ |
|---|---|---|
| 命令 `FunctionCode` | `MATCHALL` / `OUTPUTLOG`（後者は EM+EE に式中関数として存在） | 30個（`PLAYSOUND` `PLAYBGM` `TOOLTIP_*` `SETBGIMAGE` `BINPUT` 等の EE 系） |
| 式中関数 | 25個 | **104個**（`DT_*` `XML_*` `MAP_*` `ENUM*` `GETVAR/SETVAR` `HOTKEY_STATE` 等） |
| 変数 `VariableCode` | **0個** | 6個（`DAYNAME` `MONEYNAME` `TIMENAME` `GAMEBASE_URL` `GAMEBASE_VERSIONNAME` `__COUNT_INTEGER__`） |

**.NET のみの式中関数 25個の内訳（すべて移植済み）**

| 関数 | 移植先パッチ | 備考 |
|---|---|---|
| `GETCSVNOBY{NAME,NICKNAME,CALLNAME,MASTERNAME}` 4個 | `02` | EM+EE には名前→CSV番号の逆引きが無かったので `ConstantData` に辞書を追加 |
| `HASH_XXH3` / `HASH_XXH32` 2個 | `02` | `System.IO.Hashing` 依存 |
| `DICT_*` 6個 | `07` | EM+EE の `MAP_*` と機能は重複するが、キーを数値に潰す仕様が違うので別実装。文字列キーは `GetHashCode()`（.netEmuera と同じ） |
| `G_POLYGON_*` 4個 | `07` | .netEmuera は SkiaSharp の `SKPath`。EM+EE は `System.Drawing` の `DrawPolygon`/`FillPolygon` で実装 |
| `SQL_*` 9個 | `07` | `Microsoft.Data.Sqlite` 依存。セーブデータ連携込み |

`SQL_*` はメソッド9個だけでなく、以下3点の連携がある（.netEmuera と同じ位置に入れた）。

- `Process.cs` — 起動時に `temp_db` を作り直す
- `VariableEvaluator.SaveTo` — `sav/temp_db/*.db` をセーブデータの隣へコピー
- `VariableEvaluator.LoadFrom` — セーブデータの隣から `temp_db` へ書き戻す

なお `SQL_READER_READ` は**行が取れたとき 0・尽きたとき 1** を返す（他の `SQL_*` と戻り値の意味が逆）。
.netEmuera の実装がそうなっているので、互換のためそのまま合わせている。

→ **EM+EE がほぼ上位互換**。統合は「EM+EE をベースに .NET 側を移植する」一方向で成立する。
2026-08-11 時点で、.NET 側にしか無かった命令・式中関数・変数は**すべて移植済み**。

## 挙動差分（列挙型に現れないもの）

### VARI / VARS（対応済み）

EEv47 でマージされた後、.NET 側だけが変更されていた。

| | EM+EE（マージ時点） | .netEmuera 0.2.6 |
|---|---|---|
| 右辺の解析時期 | `LogicalLineParser`（ロード時・即時） | `CreateArgument`（引数解析パス・遅延） |
| `flag` | 未設定 | `EXTENDED \| METHOD_SAFE` |

即時解析だとユーザ定義 `#FUNCTION` がまだ登録されておらず `VARI X = ユーザ関数(...)` が
「解釈できない識別子です」で落ちる。`METHOD_SAFE` が無いと `#FUNCTION` 中で `VARI` を使えない。
→ `patches/04-vari-deferred-parse.patch` で解消。

### setting.json（対応済み）

.NET 側は `JSONGameConfigData`（setting.json）と `JSONUserConfigData`（setting_user.json）に分割。
EM+EE には前者しかなく、キーも3個しかない。

| キー | EM+EE | .NET | 対応 |
|---|---|---|---|
| `UseButtonFocusBackgroundColor` | ○ | ○ | — |
| `UseNewRandom` | ○ | ○ | — |
| `UseScopedVariableInstruction` | ○ | ○ | — |
| `ImageSamplingOption` | ✕ | ○ (`Resampler`) | キーのみ追加（SkiaSharp 前提のため解釈しない） |
| `CheckUTF8withBOM` | ✕ | ○ | キーのみ追加（警告表示の有無だけなので実害なし） |
| `FontAntialias` | ✕ | ○ | キーのみ追加（同上） |
| `UseRenameInCharaCSV` | ✕ | ○ | **実装済み**（キャラCSVへの `_Rename.csv` 適用可否） |

キーを追加しないと `JSONConfig.Save()` が相手側の設定を消してしまう。

`setting_user.json`（クリップボード連携 `CB*` 14キー）は .NET 側だけの機能。未対応。

### HTML_PRINT の `<div>` 方言（対応済み）

.netEmuera は HTML パーサを AngleSharp に載せ替えた際に、`<div>` の仕様ごと変えている。

| | EM+EE | .netEmuera |
|---|---|---|
| `width` / `height` | **必須** | 省略可（内容に合わせて自動サイズ） |
| 背景色 | `bcolor` | `background_color` |
| 枠線 | `border` / `radius`（`StyledBoxModel`） | `border_width` / `border_color` |
| `padding` | ○ | ○（同名） |
| `display` | `absolute` / `relative` | `absolute-lefttop` / `absolute-leftbottom` |

ShinEraTenseiP での使用実績（`<div>` 全344箇所）:

| 属性 | 使用数 |
|---|---|
| `xpos` | 290 |
| `ypos` | 265 |
| `width` | 67 |
| `height` | 60 |
| `display`（値は `absolute-leftbottom` 51 / `absolute-lefttop` 17） | 56 |
| `border_width` | 43 |
| `padding` | 42 |
| `background_color` | 36 |
| `border_color` | 9 |

**344箇所のうち 261箇所が width を持たない。**

対応の内訳（`patches/05-div-dialect.patch`）:

- `background_color` → EM+EE の `color`（div の背景色）、`border_width` → `border`、`border_color` → `bcolor` の別名を追加
- `display` を `bool isRelative` から `DivDisplayMode`（Relative / Absolute / AbsoluteLeftTop / AbsoluteLeftBottom）に拡張。
  EM+EE 従来の `absolute` は `画面高 - ypos - 高さ` だったが、.netEmuera の `absolute-leftbottom` は `画面高 + ypos` で式が違うため、従来の挙動は残したまま別モードとして足した
- width/height 省略時は .netEmuera と同じ「中身の幅」「行数×行高」をレイアウト上の大きさにする。
  ただし EM+EE は div の中身をクリップするので、画像のように行高を超える中身が消えてしまう。
  クリップ矩形だけノードの実寸まで広げて回避している

**あわせて上流のバグを1つ修正**（`ConsoleButtonString.FilterEscaped`）。
EM+EE は div を「行からはみ出す要素」としてのみ描画しており（通常の描画経路は div を読み飛ばす）、
高さが行高ちょうどに収まる div は一切描画されなかった。
従来は width/height が必須で行高を超えるものしか無かったため表面化していなかったが、
自動サイズだと1行の div がちょうどこの条件に当たる。

回帰確認: eraTOWN / erablue_resort のタイトル画面を素の EM+EE と統合版でピクセル比較したところ、
差分はバージョン文字列（コミットハッシュ）の領域のみ（1824x1263 中 X=1774..1812, Y=38..46）。

### `<div>` の入れ子（`patches/08-div-nesting.patch`）

実プレイ中の SHOP 画面で発覚。EM+EE は div の入れ子を明示的に禁止していた
（`case "div": if (state.CurrentDivTag != null) throw NestedTag`）が、
.netEmuera は AngleSharp で読むので入れ子が普通に通る。
ShinEraTenseiP は「位置決め用の外側 div の中に中身の div を並べる」書き方を **25箇所**で使っている。

```
SHOWLINE += @"<div xpos='...' ypos='...'>" + ... + "</div>"    ← 内側を貯めて
HTML_PRINT @"<div xpos='0' ypos='...'>" + SHOWLINE + "<div>"   ← 外側で包む
```

対応:

- 状態を「いま中にいる div」(`CurrentDivTag`) と「開いたばかりで中身をこれから読む div」(`PendingDivTag`) に分けた。
  再帰の `parent == null` 制限を外し、入れ子でも同じ手順で組み立てる
- `ConsoleButtonString.DrawTo` は div を読み飛ばすので、入れ子の div は `ConsoleDivPart.DrawTo` 側で自分で描く
- 自動サイズの幅計算に入れ子 div の右端を含める（div は表示ノードとしての `Width` が 0 のため）
- **末尾で閉じ忘れている div は HTML と同じく自動で閉じる**。
  上の例のように `</div>` を `<div>` と打ち間違えたまま配布されているバリアントが実際にある

入れ子は従来 100% 例外で落ちていた（＝EM+EE 系ゲームは使っていない）ので、この変更に回帰リスクはない。

### `<div>` 属性の不正トークン（`patches/09-div-lenient-attrs.patch`）

入れ子を通したあと、同じ SHOP 画面で次に引っかかったもの。

```
SHOWLINE += @"<div xpos = '{50 + 2200 * L_ROW}'  + ypos = '{500 * L_COLUMN}'>" + ...
                                                 ^ 余分な +
```

ERB の書き間違いで、属性の間に `+` が残っている（SHOP.ERB に3箇所）。
AngleSharp は不正な属性を黙って無視するので .netEmuera では表面化しない。
EM+EE の属性ループは `名前 = "値"` の3つ組を前提にしているため解析エラーになっていた。

対応: 属性名として読めないトークンは読み飛ばす（`<div>` のみ。他のタグでは該当例がない）。

検証はエラーログに残っていた HTML 文字列（3,116文字・`<div>` 30個）をそのまま
`HTML_PRINT` に食わせて、SHOP 画面のレイアウトが描画されることを確認した。

## 検証済みの動作

`Data/ERB/TEST.ERB` 相当の最小ゲームでの実測値:

| 項目 | 結果 |
|---|---|
| `MATCHALL 配列, 5`（`[5,3,5,9,5,1,3,5]`） | `RESULT:0=4`, 添字 `0,2,4,7` |
| `MATCHALL 配列, 5, 2, 6`（範囲指定） | `RESULT:0=2`, 添字 `2,4` |
| `MATCHALL 配列, 777`（該当なし） | `RESULT:0=0` |
| `MATCHALL 文字列配列, "ALPHA"` | `RESULT:0=2`, 添字 `0,2` |
| `MATCHALL CFLAG, 3, 77`（1次元キャラクタ変数） | `RESULT:0=2`, 添字 `0,2` |
| `GETCSVNOBY{NAME,NICKNAME,CALLNAME,MASTERNAME}` | 正引き一致 / 該当なしは `-1` |
| `HASH_XXH3("abc")` | `8696274497037089104`（= `0x78AF5F94892F3950`、XXH3 の既知値） |
| `HASH_XXH32("abc")` | `852579327`（= `0x32D153FF`、XXH32 の既知値） |
| `UseRenameInCharaCSV` | `true` で `[[NICK_A]]` が置換される / `false` で置換されない |
| `VARI X = ユーザ定義関数(3)` | `300` |
| `#FUNCTION` 中の `VARI` | `12` |
| `VARS X = "..."` / `VARI 配列, 4` | 正常 |
| `Data/` 配置の自動判別 | `Data/ERB` を検出して起動 |
| `<div>` 自動サイズ（枠あり/枠なし/背景のみ/padding のみ/複数行） | いずれも中身に合わせて描画 |
| `<div>` 固定サイズ（従来の属性名も含む） | 従来どおり |
| `display='absolute-lefttop'` / `'absolute-leftbottom'` | 画面左上基準 / 画面下端基準に配置 |
| ゲームパッド（十字キーで選択移動 → A で決定） | eraTOWN のタイトルで選択が動き、決定でゲームが進行 |
| `DICT_*`（作成・存在・キー有無・数値/文字列の出し入れ・欠損キー） | 期待どおり。欠損キーは数値 0 / 文字列 "" |
| `G_POLYGON_*`（三角形を FILL → DRAW → CLEAR） | `GGETCOLOR` で内側=ブラシ色・外側=透明・辺上=ペン色を確認。CLEAR 後の DRAW は頂点不足エラー |
| `SQL_*`（NONQUERY / SCALER / READER / IS_NULL） | 期待どおり。`SQL_READER_READ` は終端で 1 |
| `SQL_*` のセーブ連携 | `SAVEDATA 90` で `sav/save90/savetest.db` が作られ、再起動＋`LOADDATA 90` で値が復元 |

## ゲームパッド対応（統合版の追加機能）

`patches/06-gamepad.patch`。上流のどちらにも無い機能。

- `Runtime/Utils/GamePad.cs` — XInput（`xinput1_4.dll`、無ければ `xinput9_1_0.dll`）を P/Invoke。追加依存なし。
  左スティックは十字キーに合成し、方向のみキーリピートする
- `UI/Game/EmueraConsole.GamePad.cs` — 選択可能なボタンを画面の並び順に集めて `selectingButton` を動かす。
  判定条件はマウスのホバー選択と同じ（世代一致・数値入力待ちなら数値ボタンのみ）
- `UI/Framework/Forms/MainWindow.GamePad.cs` — 16ms 間隔のタイマーで読み、決定はマウス左クリックと同じ経路に流す

era 系は「数字を打つかボタンをクリックする」しか無いため、キーの読み替えではなく
ボタン選択カーソル方式にしている。ウィンドウが前面にないときは反応しない。

### 上下左右を画面上の位置で動かす（`patches/10-gamepad-2d-nav.patch`）

最初の実装はボタンを一列に並べて前後に動かしていたため、左右と上下が同じ挙動になっていた。
ボタンの画面上の位置（行のY・中心X）を持たせて、

- 左右 … 並び順で1つ隣（行末まで行けば次の行へ）
- 上下 … 一番近い上/下の行の中で、今の横位置に一番近いボタンへ

とした。あわせて **`<div>` の中のボタンも集める**ようにした
（マウスは `ConsoleDivPart.TestChildHitbox` で拾えるのに、パッドからは見えていなかった。
ShinEraTenseiP の SHOP 画面のように、選択肢が div の中にある画面では何も選べなかった）。

3列×3行のボタンと div 内のボタンを並べた画面で、
右→右→下→下→左→上 が A1→A2→B2→C2→C1→B1 と動くこと、
さらに下へ送ると div 内の D1→D2 へ入ることを確認済み。

### 生キー入力待ちでパッドが効かない（`patches/11-gamepad-primitive-key.patch`）

コマンドを選んだ直後にパッドが効かなくなるという報告から判明。
原因は `INPUTMOUSEKEY`（`console.IsWaitingPrimitive`）で、
この状態は「選択肢を選ぶ」入力待ちではなく生のキーコードを待っているため、
選択カーソルを動かす作りでは何も起きなかった。
ShinEraTenseiP は `INPUTMOUSEKEY` を28箇所、`FORCEWAIT` を282箇所で使っている。

対応: `IsWaitingPrimitive` のときはキーボードと同じ `console.PressPrimitiveKey` に流す。

| パッド | 渡すキー |
|---|---|
| A | `Keys.Return` |
| B | `Keys.Escape` |
| 十字キー | `Keys.Left` / `Right` / `Up` / `Down` |

「メニュー → コマンド選択 → FORCEWAIT → INPUTMOUSEKEY → WAIT → メニューへ戻る」
を2周する ERB で、すべてパッドだけで進めることを確認した
（`INPUTMOUSEKEY` が `RESULT=3 RESULT:1=13`＝Enter を受け取っている）。

### 生入力待ちでは決定をクリックとして送る（`patches/12-gamepad-primitive-click.patch`）

上のキー渡しだけでは ShinEraTenseiP のターンエンドが進まなかった。
同じ画面をマウスでクリックすると進むことから、このゲームはキー(`RESULT=3`)ではなく
クリック(`RESULT=1`)を見ていると判断し、決定/キャンセルを
`console.MouseDown` に流すようにした（＝マウスでクリックしたのとまったく同じ経路）。

| パッド | 送るもの |
|---|---|
| A | 左クリック（カーソルの現在地。画面外なら中央） |
| B | 右クリック（同上） |
| 十字キー | 矢印キー（`PressPrimitiveKey`） |

クリック位置をカーソルの現在地にしているのは、ゲーム側が座標やボタン値を読むことがあるため。
「その場でクリックした」のと同じ結果になる。

実機のセーブデータを使い、パッドだけで CONTINUE →
`[100] ターンエンド` の選択・決定 → 売春イベントの本文送り → **73ターン目のコマンド画面に復帰**
まで到達できることを確認した。

### 右クリック相当のボタン（`patches/13-gamepad-rightclick.patch`）

era 系で右クリックは「本文を飛ばして読み進める」割り当てが標準なので、
パッドにも専用のボタンが要る。`GamePadConfig.RightClick`（既定 X）を足し、
上流の `mainPicBox_MouseDown` の右ボタン経路をそのままなぞる。

| 状態 | A（Decide） | X（RightClick） | B（Cancel） |
|---|---|---|---|
| ボタン選択待ち | 左クリック決定 | 右クリック決定（`MesSkip` を立てる） | 選択解除・入力欄クリア |
| 生入力待ち（`IsWaitingPrimitive`） | 左クリック | 右クリック | Esc キー |

生入力待ちの B は右クリックから Esc に移した（右クリックが X に分かれたため）。

`WAIT` を3つ並べた ERB で挙動を確認済み。同じボタンを選んで

- **A** → `選んだ値=1` のあと `A行目 (WAIT)` で停止（1つずつ送る）
- **X** → `選んだ値=1` のあと `A行目`/`B行目`/`C行目`/`続けます` を一気に通過してメニューへ復帰

となり、マウスの左/右クリックと同じ差が出ている。

## Android (andEmuera) への反映

同じ上流に同じパッチを当てるだけで通った。`tools/sync-android.ps1` で `patches/` を配る。
andEmuera 自身の移植パッチを `10` / `11` 番に振り直し、統合パッチ（`00`〜`07`）を先に当てる。
**10本すべて競合なしで適用できた**（当初は競合を見込んでいたが、統合パッチが新規ファイル中心で、
既存ファイルへの変更箇所も andEmuera 側と離れていたため）。

Android 側で必要だった追加作業は3点だけ:

| 項目 | 対応 |
|---|---|
| `System.IO.Hashing` / `Microsoft.Data.Sqlite.Core` / `SQLitePCLRaw.bundle_e_sqlite3` | `Emuera.Core.csproj` に追加 |
| `Runtime/Utils/GamePad.cs`（XInput の P/Invoke） | `Emuera.Core.csproj` で除外。呼び出し側の `UI/Framework/**` は元から除外済み |
| `G_POLYGON_*` の描画 | **不要**。既存の SkiaSharp 裏打ちシムに `DrawPolygon`/`FillPolygon` が既にあった |

TestHarness での実測値は Windows 版と一致（`MATCHALL count=3 idx=0,2,4` /
`HASH_XXH3=8696274497037089104` / `DICT long=1234 str=V` /
`G_POLYGON 内側=4278255360 外側=0` / `SQL count=1 name=seven` / `VARI=300`）。
erablue_resort（ERB 2,697本 / CSV 3,044本）のロードも警告なしで完走。

ゲームパッドはコア側の `EmueraConsole.MoveSelectingButton` / `ClearSelectingButton` が
Android でもコンパイルされるので、入力層さえ書けば同じ操作を実装できる。
