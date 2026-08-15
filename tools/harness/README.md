# ヘッドレス実行テスト

GUI の exe を起動せずに、実ゲームを動かして確認するための道具。
エンジンは andEmuera 側の `Emuera.TestHarness`（同じ `patches/` を当てた上流をリンク参照している）を使う。

```powershell
# 1. ゲームをローカルへ複製する (利用者の sav を壊さない / SMB 越しはロードが遅い)
robocopy 'X:\era\ShinEraTenseiP\Data' 'D:\tmp\STP\Data' /MIR /MT:16

# 2. ハーネスを建て直す (VS も COM 参照も不要)
dotnet build 'X:\era\andEmuera\src\Emuera.TestHarness\Emuera.TestHarness.csproj' -c Debug

# 3. 常駐させる
& 'X:\era\andEmuera\src\Emuera.TestHarness\bin\Debug\net10.0\Emuera.TestHarness.exe' 'D:\tmp\STP\Data' --serve --port 8321

# 4. 操作する
.\drive.ps1 -Cmds 'enter','submit:120','click:450,960' -Shot out.png
.\crop.ps1 -In out.png -Out small.png -Bottom 400 -Scale 0.55
.\montage.ps1 -In a.png,b.png -Out sheet.png -Scale 0.5
```

`drive.ps1` のコマンド:

| 書き方 | 意味 |
|---|---|
| `submit:<文字列>` | 入力欄に入れて確定（`submit:120` / `submit:f`） |
| `enter` / `skip` | 改行待ちを送る / 右クリック相当の飛ばし読み |
| `click:x,y` / `rclick:x,y` | 画面座標のクリック |
| `move:x,y` | ポインタ移動（ボタンのフォーカス確認用） |
| `scroll:<行>` / `latest` | バックログ送り（正で過去へ）/ 最新へ |
| `wait:<秒>` | 待つ |

1コマンドごとに `/status` の `generation` 更新を待ち、`error` が立った時点で止まる。
画面は `/screen.png` から取る。

**取りこぼしに見えて違うもの**（巡回で毎回引っかかる）:

- `HTML_PRINT` のあとに `WAIT` を置く画面が多い。`generation` は WAIT の描画で先に動くので、
  次のコマンドが**メニューではなく WAIT に吸われる**。「ボタンを押したのに戻らない」の大半はこれ。
  もう一度同じキーを送れば通る。切り分けるときは 1 コマンドずつ送って毎回撮ること。
- ショップ一覧のような `ONEINPUT` の画面に `submit:107` を送ると**先頭の 1 文字だけ**が入る。
  複数桁のコマンドはメインメニュー側の画面でしか通らない。

**致命エラーの見分け方**: `/status` の `error` が true になり、ゲームフォルダの `emuera.log` が
**そのたびに書き直される**（`EmueraConsole.RunEmueraProgram` が Error 状態で `OutputSystemLog` を呼ぶ）。
逆に言えば `emuera.log` の更新時刻が最後に落ちた時刻で、古いままなら以降は落ちていない。

**限界**: 描画は SkiaSharp、音声・ゲームパッド・実マウスは無い。
スクリプトエラーと HTML の解析・レイアウトは共有コードなので同じだが、
画素レベルの見た目と WinForms 固有の挙動は実 exe で確かめること。
