---
type: report
title: 0025 AI アセット設計結果 — worktree の作業ツリーと web の送信側・出力先
description: worktree で機構が丸ごと無効になる経路を cwd 基準の解決で塞ぎ、web を実行分類にした決定が勘定していなかった curl の送信側と出力先の取り出し方を定めた設計結果
tags: [report, ai-asset-design, issue-9, review-fix]
keywords: [worktree, CLAUDE_PROJECT_DIR, cwd, curl, wget, upload-file, POST, WF206, cmdpos_args, 出力先, 横断, 降ろす]
---

# 0025 AI アセット設計結果 — worktree の作業ツリーと `web` の送信側・出力先

## サマリ

境界レビュー 2 巡目の **A3・A4・A5・B7・B8** を反映した。中心は **worktree に入ると機構が丸ごと無効になる**（ロックアウトではなく**静かな無効化**）という発見と、**`web` を実行分類にした 0022 の決定が `curl` の送信側を勘定していなかった**という穴である。更新は要件 2 本・仕様 5 本・DDR 1 本の訂正・全体計画 1 本、新規の DDR は 4 件（`i0009-55`〜`58`）。

確定したのは 4 つ。

1. **worktree では `cwd` 側の作業ツリーを採る**（`i0009-55`）。`${CLAUDE_PROJECT_DIR}` は本流に留まり `cwd` が Claude に追随する、と公式が明記している
2. **`web` の判定順は「送信側 → 出力先 → `web`」**（`i0009-56`）。`curl -T` / `-d @` / `-X POST` は**宣言の有無によらず WF206**
3. **出力先の取り出しは `cmdpos_args` の走査**（`i0009-57`）。`cmdpos_operands` ではオプション本体が落ちて URL と区別できない
4. **横断で決めた規則は個別の要件・仕様・再掲表まで降ろす**（`i0009-58`）。1 巡目で閉じきれなかった 7 件も 2 巡目の 5 件も、すべてこの型だった

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **f1（✕問題）worktree での無効化**。これは**ロックアウトより悪い**種類の失敗で、機構が静かに全部通す。しかも **0019 の改定（`git rev-parse` の禁止）で悪化していた**（旧仕様なら `cwd` で解決していた）。`cwd` からの `.claude` の上向き探索で塞いだが、**`cwd` を信頼してよいか**（フックの入力なので Claude Code が渡すもの）と、**`logs/` と `wip/` を worktree 側に置く**という帰結が正しいかを見てほしい
- **f4（△注意）横断→個別の降ろし方を規約にしたこと**（`i0009-58`）。DDR の「影響」に降ろす先を 4 種類（個別仕様 / 要件 / 再掲表 / 根拠にしている DDR）列挙し切る、と決めたが、**これは手順であって機械で確かめられない**。同じ型が 3 巡目に出ないという保証は無い

**◇承認が欲しい（方針は決めた）**

- **f2**: `curl` / `wget` の送信側を `web` として通さず WF206 にすること（`-X GET` は通す）
- **f3**: 出力先の取り出しを `cmdpos_args` の走査にし、`://` を含む語を URL として除くこと

**・細かいレビューは不要（ほぼ確実）**

- `10-task-investigation-exec` の要件・仕様の是正、`20-common-step-shell-script` の分類表への `web` の追加

## 確かめられなかったこと（この結果が言っていないこと）

- **worktree の実挙動を試していない**（フックが未登録のため）。公式の記述に基づく設計で、フェーズ 4c の実測項目として登録した
- **`cwd` からの上向き探索が、worktree 以外の場面で誤らないか**（例: `.claude` を持つサブプロジェクトがネストしている場合）。ネストは想定していない
- **送信側オプションの列挙が網羅的か**（`curl` は 200 以上のオプションを持つ）。`.curlrc` 経由の指定も見ていない
- **`-X GET` を通す判断**が、`-X GET` に本文を付ける形（`curl -X GET -d @a.md`）で破れないか — この形は `-d` があるので (1) で拒否されるが、他の組み合わせを網羅していない
- `i0009-58` の規約が実際に取りこぼしを減らすか

## 実施条件（読んだ対象）

- 公式原本: `wip/tmp/hooks.md:594-602`（`Worktrees are different.` の Note）
- 更新対象: 要件 `00_requirement/skills/10-task-investigation-exec.md`・`00_requirement/自己改善ワークフロー機構.md`、仕様 `10_spec/フック共通仕様.md`（§2・§8）・`hooks/20-PreToolUse/workflow-guard.md`・`10_spec/skills/10-task-investigation-exec.md`・`10_spec/skills/20-common-step-shell-script.md`、全体計画のフェーズ 4c
- 訂正した DDR: `i0009-41`
- 訂正した報告: `wip/30_reports/0022-ai-asset-design.md` と `.html`（`cmdpos_operands` の申し送り）
- 入力: `wip/30_reports/0022-ai-asset-design-appendix-A.md`（A3・A4・A5・B7・B8）

## 実施した内容と結果

### 1. worktree では `cwd` 側の作業ツリーを採る（A3） ✕問題

公式の Note（`hooks.md:594-602`）にこうある。

```
Worktrees are different. If Claude enters a worktree during the session,
Claude Code keeps ${CLAUDE_PROJECT_DIR} where it was and passes the worktree
path to your hooks a different way:
 * ${CLAUDE_PROJECT_DIR} stays put: it still points at the project root where
   the session started, so a command such as
   ${CLAUDE_PROJECT_DIR}/.claude/hooks/check-style.sh still runs the script in
   the main checkout.
 * cwd follows Claude: the cwd field in the hook's input JSON is the worktree
   root after Claude enters a worktree, and the new directory after Claude runs
   cd. Read it when a hook needs to know which directory Claude is working in.
```

`i0009-20` が登録を `${CLAUDE_PROJECT_DIR}` 基準にし、`i0009-22` が `git rev-parse --show-toplevel` を禁じた結果、`HOOK_ROOT` は **本流のチェックアウト**を指し続ける。すると `workflow-guard` は本流の空の `wip/10_tickets/10_doing/` を見て「**0 枚 → 即座に許可**」となり、**すべての書き込みと実行が素通りする**。`workflow-entry` の継続条件も `workflow-state-guard` の置き場保護も同じ。**旧仕様（`cwd` で `git rev-parse`）なら worktree 側に解決していたので、0019 の改定で悪化していた**。しかも要件は並行作業の手段として worktree を挙げている。

**決定**: フックは次の順で作業ツリーを決める（共通仕様 §2）。

1. `cwd` が `HOOK_ROOT` と異なり、かつ `cwd` から上向きに探して `.claude` を持つディレクトリが見つかるなら、**そのディレクトリ**
2. そうでなければ `HOOK_ROOT`

上向き探索は `[ -d ]` の繰り返しで **`git` を呼ばない**（fork 上限に影響しない）。**スクリプトの置き場は常に `HOOK_ROOT`**（worktree 側に実体が無くても本流で動く）、**`logs/` と `wip/` は作業ツリー側**（worktree ごとに進行状態が分かれる）。フェーズ 4c に実測項目を置いた。DDR `i0009-55`。

**結論**: **ロックアウトより悪い「静かな無効化」**を塞いだ。0019 の結果報告が「確かめられなかったこと」に挙げていたが、答えは取得済みの原本の中にあった（2 巡目で 2 回目のパターン）。

### 2. `web` の判定順は送信側を先に見る（A4） ◎良

`i0009-41` は「書き込みの穴を新たに開けない」の根拠に**出力先オプション**だけを挙げ、**送信側**を勘定していなかった。

| 形 | 何が起きるか |
|---|---|
| `curl -T a.md <url>` / `--upload-file` | ローカルのファイルを外部へ送る |
| `curl -d @a.md <url>` / `--data-binary @a.md` | 同上（ファイルの中身が本文） |
| `curl -F file=@a.md <url>` | 同上（multipart） |
| `curl -X POST https://api.github.com/repos/…/issues` | **issue の起票**そのもの |
| `wget --post-file=a.md <url>` / `--method=PUT` | 同上 |

改定前は `curl` が既定拒否（WF204）だったため閉じていた経路で、改定後は `web` を宣言した `investigation` チケットから**宣言していないリモート書き込み**が通る。出力先を持たないので WF205 にも落ちない。

**決定**: 判定を順序つきにする。(1) **送信側は宣言の有無によらず deny WF206**（`-X GET` / `--method=GET` は通す）、(2) 出力先を持つ形は書き込みとして WF205 の判定、(3) 残りが `web`。宣言があっても (1)(2) は免除しない。DDR `i0009-56`。テスト `WG-T17`。

**結論**: 「`web` の宣言は外部を**見て**よいの許可であって、外部に**書いて**よいの許可ではない」を判定順に落とした。分類を足すときは「今まで塞がっていたもののうち何が通るようになるか」を数える必要がある（2 巡目で 3 回見つかった型）。

### 3. 出力先の取り出しは `cmdpos_args` の走査（A5） ◎良

`i0009-41` の影響と 0022 の申し送りは、出力先オプションの照合に `cmdpos_operands`（`i0009-39`）が使えると書いていた。実際には使えない。

```
cmdpos_operands の定義: CP_ARGS[i] から `-` で始まる語と `--` 以降を除いた位置引数

curl https://x/y -o wip/tmp/a   → [https://x/y, wip/tmp/a]
curl -o wip/tmp/a https://x/y   → [wip/tmp/a, https://x/y]
curl https://x/y                → [https://x/y]     ← 出力先は無い
```

オプション本体（`-o`）が落ちるので、**どれが URL でどれが出力先かを区別できない**。この結果に §8 の判定を当てると、出力先を持たない `curl <url>` でも URL がパスとして判定され、`WG-T15` が固定した「`curl https://example.com/x` は通る」と食い違う。

**決定**: `cmdpos_args`（`REPLY_ARGS`）の引数列を**先頭から走査**し、`-o` / `--output` / `--output-dir`（`wget` は `-O`）を見つけたら**その次の語**を出力先とする（`--output=<path>` の等号形は前方一致）。`curl -O` / `--remote-name` と `wget` の既定は出力先の語を取らず、**URL の basename を作業ツリー基準のカレントに作る**ものとして扱う。**`://` を含む語は URL とみなし出力先として扱わない**。DDR `i0009-57`。

**結論**: `i0009-39` の線引き（ライブラリは整形まで / 意味論は呼び手）は守られた。`cmdpos_operands` が悪いのではなく、当てる先を間違えていた（`rm` のように位置引数だけが意味を持つコマンド向けの関数）。0022 の申し送りも訂正した。

### 4. 横断で決めた規則を個別の要件・仕様まで降ろす（B7・B8） ◎良

`i0009-41` の決定と矛盾する記述が別の文書に残っていた。

| 文書 | 残っていた記述 |
|---|---|
| `00_requirement/skills/10-task-investigation-exec.md:97` | 「リポジトリ外への問い合わせを行わない（**この禁止は機構では強制されず** … スキルの自制による）」 |
| `10_spec/skills/10-task-investigation-exec.md:19` | 同じ禁止（強制の有無に触れない） |
| `10_spec/skills/20-common-step-shell-script.md:126` | `scope_classify` の分類一覧に **`web` が無い** |

2 巡目のレビューは「1 巡目 38 件のうち閉じきれなかった 7 件が**すべて同じ型**（横断では閉じたが個別で閉じていない）」と報告している。`i0009-41` はその 7 件を直すためのチケットで作られた決定なのに、**同じ型を新たに作っていた**。

**決定**: 3 文書を是正したうえで、**規約として**「横断文書で決めた規則は、DDR の『影響』に降ろす先を列挙し切る」と定めた。列挙の対象は 4 種類 — (1) 個別のフック・スキルの仕様書、(2) 対応する要件書、(3) 同じ事実を再掲している表・一覧、(4) その規則を根拠にしている既存の DDR。**再掲する表には「正は横断文書の §X」と書く**（要約は残してよいが正の所在を明示する）。DDR `i0009-58`。

**結論**: 個別の是正だけを続けても再発するので、型に対して手を打った。ただし**手順であって機械で確かめられない**のが弱点。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 更新した要件定義書 | 2 本（`10-task-investigation-exec`・`自己改善ワークフロー機構` の制約条件） |
| 更新した仕様書 | 5 本（`フック共通仕様`（§2・§8）・`workflow-guard`・`10-task-investigation-exec`・`20-common-step-shell-script`）+ 全体計画のフェーズ 4c |
| 訂正した DDR | 1 件（`i0009-41`。送信側の未検討と影響の追加） |
| 新規の DDR | 4 件（`i0009-55`〜`58`。**割り当て帯 55〜58 に完全一致**） |
| 訂正した過去の報告 | 1 件（`0022-ai-asset-design` の md と html。`cmdpos_operands` の申し送り） |
| 追加したテスト観点 | 1 件（`WG-T17` 送信側の拒否と、出力先・URL の取り違えの防止） |
| 対応した指摘 | 5 件（A3・A4・A5・B7・B8）。すべて反映済み |
| 塞いだ経路 | 1 つ（worktree での**静かな無効化**）+ 1 つ（`web` の宣言によるリモート書き込み） |
| ヘッドレス実行の帰結 | 変更なし |

### 受け入れ条件との対応

| # | 受け入れ条件（issue #9） | このチケットが満たす分 | テスト ID（種別） |
|---|---|---|---|
| 1 | フック本体 11 本が仕様どおり動きテストが通る | 作業ツリーの決め方が worktree でも成立する形になり、`web` の判定順と出力先の取り出し方が実装できる粒度まで決まった | WG-T17（機械） |
| 3 | 公式リファレンスとの整合が取れている | worktree の Note（`:594-602`）を §2 に反映した | — |
| 5 | `web` の強制が実物の確認に基づいて仕様に書かれている | 0022 で決めた `web` の強制の**穴**（送信側）を塞ぎ、判定順として書き切った | WG-T17（機械） |
| 6 | 決定の経緯が DDR に残っている | `i0009-55`〜`58`（4 件）+ `i0009-41` の訂正 | — |

## 設計への反映（後続へ）

1. **0016 へ**: フェーズ 4c に **worktree の実測**（`git worktree add` して Claude を移し、worktree 側のチケットを `workflow-guard` が見るか）を含める
2. **0016 へ**: `scope.sh` の実装項目に「作業ツリーの解決（`cwd` からの `.claude` の上向き探索）」と「送信側・出力先オプションの照合（`cmdpos_args` の走査）」を立てる
3. **実装フェーズへ**: 上向き探索は `[ -d "$d/.claude" ]` の繰り返し。ルートまで見つからなければ `HOOK_ROOT` に倒す
4. **実装フェーズへ**: `web` の判定順は **送信側 → 出力先 → `web`**。順序を逆にすると `curl -T` が宣言だけで通る
5. **0026 へ**: `i0009-58` の規約に従い、0026 が触る DDR の「影響」も 4 種類を列挙し切る

## 想定と異なった点

| 計画時の見込み | 実際 | どう扱ったか |
|---|---|---|
| A3 は §2 に 1 行足す | **0019 の改定で悪化していた**（旧仕様なら `cwd` で解決していた）ことが分かり、解決の順序まで決める必要があった | `i0009-55` で 2 段の解決順と、スクリプトの置き場・`logs/` / `wip/` の置き場を書き分けた |
| A4 は送信側オプションを列挙するだけ | 「送信側かつ出力先あり」の形があるので、独立した条件ではなく**判定順**として書く必要があった | `i0009-56` で順序つきの 3 段にした |
| A5 は `cmdpos_operands` を `cmdpos_args` に置き換えるだけ | `-O` と `wget` の既定（出力先の語を取らない形）の扱いを決めないと、実装が推測になる | 「URL の basename を作業ツリー基準のカレントに作る」と明記した |
| B7・B8 は 3 文書の是正 | 1 巡目 7 件と 2 巡目 5 件が**すべて同じ型**だと分かり、型への対策が本体だった | `i0009-58` を規約として立てた |

## 残課題

- **worktree の実挙動を試していない**（フック未登録）。4c の実測に依存する
- **`cwd` からの上向き探索がネストした `.claude` で誤らないか**（想定していない構成）
- **送信側オプションの列挙が網羅的か**（`curl` は 200 以上のオプションを持つ。`.curlrc` も見ていない）
- **`i0009-58` の規約は機械で確かめられない**（f4）。3 巡目に同じ型が出ないという保証は無い
- `logs/` と `wip/` を worktree 側に置く帰結（本流と worktree で進行状態が分かれる）が運用上正しいか
