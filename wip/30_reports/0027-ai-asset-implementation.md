---
type: report
title: 0027 AI アセット実装結果 — 共通ライブラリ 3 本の改修・config 3 本・読み込み行の一斉置換・block-chmod
description: フック本体を書く前に lib が持つべき 5 関数と副入力の受け渡しを揃え、読み込み行 22 本を雛形にバイト一致させ、T6 の先行確認に使う block-chmod を 1 本だけ実装した結果
tags: [report, ai-asset-implementation, issue-9, hooks, lib]
keywords: [hook-common, scope, cmdpos, rawfile, HOOK_WORKTREE, worktree, hc_lock, redact, SS-T05, block-chmod]
---

# 0027 AI アセット実装結果 — 共通ライブラリ 3 本の改修・config 3 本・読み込み行の一斉置換・block-chmod

## サマリ

実装 2/3 の 1 枚目。**フック本体を 1 本も書く前に、設計が前提にしていた lib の穴を埋めた**。計画（`wip/20_plans/0016-ai-asset-implementation-plan.md`）のステップ 1 に当たる。

設計は「lib は #6 で既に正しい」という前提で書かれていたが、実体には `hook_read_state` / `hc_append_jsonl` / `hc_json_write` / `hc_lock` / `hc_unlock` の 5 関数も、`cmdpos_operands` も、拒否側 4 本が要るイベント固有フィールドも無かった。そのまま本体を書くと、フックが `hook_field` を追加で呼んでホットパスの「jq 最大 2 回」を破る。

確定したのは 4 つ。

1. **副入力は `--rawfile` + `fromjson? // "__broken"` で読み、検証エラーは `error()` ではなくレコードで返す**（DDR i0009-47 の実装）。設定ファイルが壊れていても stdin の解析が巻き添えにならない
2. **`HOOK_ROOT`（スクリプトの置き場）と `HOOK_WORKTREE`（作業ツリー）を分け、上向き探索の候補が本流の worktree であることを確かめる**。確かめない実装は `cd 参考ディレクトリ/agent-workflow` だけでガードが全面バイパスされた
3. **`SS-T05`（読み込み行のバイト一致）を新設**し、実体 22 本を雛形に揃えた。設計（DDR i0009-36）で決めながらテストが存在していなかった
4. **`block-chmod.sh` を 1 本だけ実装**した。⓪ の段階登録（0028）で T6 を測るための最小の 1 本

全件テストは **15 本 / 70 件・FAIL 0**。

**性能のバグを 1 件見つけて直した**: `__hc_redact_to_reply` が 4000 文字の入力で **58 秒**かかっていた。フックはツール呼び出しごとに走るので、このまま登録していたら機構ごと使い物にならなかった。

## レビューしてほしい観点

**◆特に見てほしい（判断に困っている）**

- **f1（△注意）仕様からの逸脱が 3 件出た**（§1 の表・§8 の `SC_TARGETS`・§2 の worktree 判定）。いずれも「実装してみて初めて分かった」もので、0032 の棚卸しへ送るつもりでいる。**実装フェーズは `.claude/docs/**` が deny なので、この巡では直せない**。逸脱を作業ログに書いて先送りする、というやり方でよいか
- **f2（△注意）`_sc_classify_web` の curl オプションの列挙が網羅的か確かめられない**。curl は 200 以上のオプションを持ち、`.curlrc` 経由の指定も見ていない。「送信側を取りこぼすと `remote-write` の統制が迂回される」ので、**列挙で足りるのか、それとも別の判定軸（宣言の無い `curl` は一律拒否など）に変えるべきか**を見てほしい

**◇承認が欲しい（方針は決めた）**

- **f3**: `hc_lock` の陳腐化判定に `stat -c %W`（birth）ではなく `find -mmin` を使ったこと（移植性を取った。実測は「想定と異なった点」に記載）
- **f4**: `SC_TARGETS` を仕様の `SC_TARGETS[]`（配列）ではなく既存実装に合わせて US 区切りのスカラで統一したこと
- **f5**: `SS-T05` の走査範囲を `.claude/hooks/**` と `.claude/skills/*/scripts/**` に限り、`assets/*.template.sh` を範囲外にしたこと

**・細かいレビューは不要（ほぼ確実）**

- config 3 ファイル（`blocked-commands.txt` / `entry-skills.txt` / `model-aliases.txt`）の中身
- `cmdpos_operands` の実装と 10 ケース
- 読み込み行 22 本の置換そのもの（SS-T05 が機械で固定している）

## 確かめられなかったこと（この結果が言っていないこと）

- **`shellcheck` を通していない**。この環境に未導入（`command -v shellcheck` が空）で、導入はソースコード修正の枠外。代わりに `bash -n` と BC-T01〜T06 の実行で確かめている。DoD の「shellcheck を通り」は**未達のまま残る**
- **フックとして登録した状態での振る舞いは測っていない**。`settings.json` は無改変で、確認はすべて `bash <script> < 入力 JSON` の単体実行。T6（`chmod` が実際に止まるか）は 0028 の ⓪ 登録で測る
- **ホットパス 5 本の jq 回数（HK-T19）は lib 単体の範囲だけ**。対象フック 5 本のうち 4 本は 0030 でしか存在しないので、本体を通した確認は 0030 の DoD
- **`_sc_classify_web` は実際の curl / wget を起動していない**。オプション列の解析だけを 13 ケースで確かめており、curl の実挙動との一致は確かめられていない
- **`__hc_redact_to_reply` の 101ms は Git Bash（Windows）での実測**。Linux での値は測っていない

## 実施条件（読んだ対象）

| 対象 | 内容 |
|---|---|
| 計画 | `wip/20_plans/0016-ai-asset-implementation-plan.md` ステップ 1 |
| 仕様 | `.claude/docs/10_spec/hooks/フック共通.md`（§1 の入力・§2 の作業ツリー・§3 の redact・§7-9 の cmdpos・§8 の分類）、`.claude/docs/10_spec/hooks/20-PreToolUse/block-chmod.md`、`.claude/docs/10_spec/skills/20-common-step-shell-script.md`（読み込み行・SS-T05） |
| DDR | i0009-03（Skill を declare に）・i0009-16（frontmatter.sh の破損）・i0009-35（`\|\| true` を使わない）・i0009-36（読み込み行のバイト一致）・i0009-39（位置引数）・i0009-47（副入力）・i0009-48（パス引数を消す）・i0009-55（作業ツリー）・i0009-60（陳腐化したロック） |
| 実体 | `.claude/hooks/lib/{hook-common,cmdpos,scope}.sh` とそのテスト、`.claude/skills/20-common-step-shell-script/assets/*.template.sh`、読み込み行を持つ .sh 22 本 |

## 実施した内容と結果

### 1. `hook-common.sh` — 副入力・イベント固有フィールド・作業ツリー・記録ヘルパ ◎良

- **副入力**（`limits` / `review` / `merge` / `approvals` / `entry`）を、存在するものだけ `--rawfile <名前> <パス>`、無いものは `--argjson <名前> null` で渡す。jq 内は `fromjson? // "__broken"`。検証エラーは `error()` を投げず `verr` の `__error` レコードで返し、`HC_<名前>_STATE`（`ok` / `missing` / `broken`）と `HC_<名前>_ERROR` に落とす。`--slurpfile` は使っていない
- **1 回目の jq が 23 フィールド**を出す。`prompt` は `split("\n")[0]` で 1 行目だけ、`old_string` / `new_string` / `content` / `edits` は frontmatter の 6 キーに触れたかの真偽 1 個（`HOOK_FM_KEYS_TOUCHED`）に畳む。全文を持ち回らないので、記録・拒否理由に漏れる経路も減る
- **`HOOK_ROOT` と `HOOK_WORKTREE` を分けた**。既定は同じで、cwd が違うときだけ `[[ -d "$d/.claude" ]]` の上向き探索で書き換える（`git` を呼ばない = fork ゼロ）。`hook_doing_ticket` / `hook_record` / `hook_session_dir` / `hook_rel_path` / `hc_lock` / `hc_unlock` がすべて `HOOK_WORKTREE` 基準になった
- **記録ヘルパ 5 関数**を足した。切り詰め（4 KB・末尾に `…`）は `hc_append_jsonl` が持ち、呼び手は関与しない。ロックの 2 秒（待ち）と 60 秒（陳腐化）は `hc_lock` だけが読む定数
- **`tool_class` の `00-workflow-*` 接頭辞判定を除いた**（DDR i0009-03）。`Skill` は `tool_input.skill` の値によらず常に `declare`

### 2. 上向き探索の候補が本流の worktree であることを確かめる △注意

**0025 で入れた worktree 対策が、そのままだと新しい穴になっていた**。`cd` だけで cwd は動く。このリポジトリには `参考ディレクトリ/agent-workflow/.claude` と `参考ディレクトリ/MR-driven-workflow/.claude` が実在し、どちらも**空の** `wip/10_tickets/10_doing/` を持つ。確かめずに上向き探索の結果を採ると、`cd 参考ディレクトリ/agent-workflow` するだけで `hook_doing_ticket` が 0 枚を返し、`workflow-guard` が全面バイパスされる。

判定は fork ゼロで済む 2 経路にした。

- (a) 候補直下の `.git` がファイルで、その `gitdir:` が `$HOOK_ROOT/.git/worktrees/` を指す
- (b) `$HOOK_ROOT/.git/worktrees/*/gitdir` が候補の `.git` を指す

実測（`wip/tmp/probe_wt.sh`）で、`参考ディレクトリ/agent-workflow`・`参考ディレクトリ/MR-driven-workflow`・存在しないパス のいずれも本流に解決することを確認した。テストは `case_worktree`（HK-T18）として固定した。

**この型が通算 5 回目**: 穴を塞ぐ決定が別の穴を開ける。

### 3. `scope.sh` — パス引数を消し、`web` の 3 段判定を足す ◎良

- `scope_load` / `scope_load_approvals` からパス引数が消え、`HC_LIMITS` / `HC_APPROVALS` から詰め替えるだけになった（DDR i0009-48）。`scope_load_ticket` は 0 / 1 / 2 の 3 状態（2 は frontmatter.sh の破損だけ）
- `fm_*` の呼び出しから `|| true` が消え `|| rc=$?` になり、`local` と代入が 2 行に分かれた（DDR i0009-35）
- **`web` の 3 段判定**（DDR i0009-56/57）: (1) 送信側 → `remote-write:upload`（宣言によらず deny WF206）、(2) 出力先を持つ形 → `write` + `SC_TARGETS`（WF205 の判定へ）、(3) 残りが `web`。出力先は `cmdpos_args` の走査で取り、`://` を含む語を URL として除く

### 4. `cmdpos.sh` — `cmdpos_operands` ◎良

`CP_ARGS[i]` から `-` 始まりの語と `--` 以降を除いた位置引数を `REPLY_OPERANDS` に展開する。git はサブコマンド 1 語も落とす。解釈は呼び手が行う（§7-9・DDR i0009-39）。

### 5. 読み込み行の一斉置換と `SS-T05` の新設 ◎良

雛形（`script.template.sh` / `test.template.sh`）の `__ss_load` を仕様どおりに作り直し（`FM_AVAILABLE=1/0` を設定、`fm_*` スタブは戻り値 2、`git rev-parse` は 3 段目に残す）、実体 22 本を揃えた。

**`SS-T05` は DDR i0009-36 で決めながら実装されていなかった**。走査範囲は仕様どおり `.claude/hooks/**` と `.claude/skills/*/scripts/**`。検出力も確かめた（1 本だけわざとずらすと `FAIL SS-T05: 雛形と一致しない読み込み行 1 件 / 走査 22 件` で落ち、戻すと PASS）。

### 6. `block-chmod.sh` と config 3 ファイル ◎良

- `.claude/hooks/config/blocked-commands.txt`（`chmod` 1 行）・`entry-skills.txt`・`model-aliases.txt` を新設。3 ファイルとも `settings.json` 無改変の状態で作った（⓪ の登録より前）
- `block-chmod.sh` は制御方式 1〜6 をこの順で持つ。**高速前置判定**（外部プロセスなし）で一覧の語を含まないコマンドを即許可し、含むときだけ `cmdpos.sh` を使う。BC-T05 は「`cmdpos.sh` を壊しても `ls -la` は通る」ことで、読み込み前に判定していることを確かめている
- 一覧をコードに埋めていない（BC-T04 が一覧の増減で判定が変わることを確かめる）

### 7. `__hc_redact_to_reply` の性能バグ △注意

4000 文字の入力で **58 秒**。規則ごとに計測すると正規表現の 4 規則は各 70ms 程度で、真犯人は規則 5 の `pre="${s%%"$m"*}"` だった（`$m` が 4000 文字のリテラルパターンのとき、bash のパターン照合が壊滅的に遅くなる。単体で **58442ms**）。位置ベースの O(n) ループに書き直して **101ms** になった。

`__hc_cap_json_field` の文字単位ループも O(n^2) で、パラメータ展開だけの O(n) に書き直した。

## 検証の結果

| 検証 | 結果 |
|---|---|
| 全件テスト（`run-tests.sh`） | **15 本 / 70 件・FAIL 0** |
| `test_hook_common.sh` | passed=138 failures=0（HK-T02〜T08・T10〜T14・T17〜T20） |
| `test_scope.sh` | passed=258 failures=0（HK-T15 ほか・web の分類 13 ケース） |
| `test_cmdpos.sh` | passed=247 failures=0（CP-T01〜T08・`case_operands` 10 ケース） |
| `test_templates.sh` | passed=39 failures=0（SS-T01〜T05） |
| `test_block_chmod.sh` | passed=29 failures=0（BC-T01〜T06） |
| `bash -n`（新規 2 本） | 0 |
| `shellcheck` | **未実施**（環境に未導入） |
| SS-T05 の検出力 | 1 本ずらすと FAIL、戻すと PASS |
| worktree の解決 | 参考実装 2 本・存在しないパスのいずれも本流に解決 |
| `redact` の性能 | 4000 文字で 58442ms → 101ms |

### 受け入れ条件との対応

| issue #9 の受け入れ条件 | このチケットでの状態 |
|---|---|
| フック本体 11 本を実装する | 1 本（`block-chmod.sh`）。残り 10 本は 0029（案内側 6）・0030（拒否側 4） |
| `settings.json` に登録する | **未着手**（0028 の ⓪ / 0031 の ①②。いずれも人間の操作） |
| TBD T1〜T4 を検証する | 未着手（0031 の 4c で実測） |
| 機械テストが通る | 全件 15 本 / 70 件・FAIL 0（この時点の範囲で） |

## 設計への反映（後続へ）

- **0028 へ**: `blocked-commands.txt` は作ってあるので、⓪ の登録（`block-chmod` 単独・ラッパー無し）だけで T6 を測れる
- **0029 / 0030 へ**: lib の 5 関数・`cmdpos_operands`・23 フィールドは揃った。本体は `hook_field` を追加で呼ばずに書ける
- **0030 へ**: HK-T19（ホットパス 5 本の jq 回数）は本体が揃ってから
- **0032 へ**: 仕様の書き戻し 3 件（§1 の表 / §2 の worktree 判定 / §8 の `SC_TARGETS` と `SC_CLASS`）と、DDR 候補 2 件（worktree の確認 / bash のパターン照合の遅さ）

## 想定と異なった点

- **`stat -c %W`（birth time）が Git Bash で使えた**。`1788323071` と、`%Y`（mtime）と同じ値を返す。それでも `find -mmin` を選んだのは、`%W` が Linux の古い coreutils やファイルシステムでは 0 を返すことがあり移植性が低いため。ロックディレクトリは中身を書かないので mtime = 作成時刻として扱ってよい
- **`make_counting_path` が `PATH` を書き換えない**。`COUNTING_PATH` を設定するだけで、呼び手が `PATH="$COUNTING_PATH:$PATH"; hash -r` する必要がある。HK-T19 が最初 0 回を返した原因
- **`io.open(p, "wb")` は例外の発生前にファイルを truncate する**。`wip/tmp/mkload.py` の UnicodeDecodeError で `.claude/hooks/lib/scope.sh` を 0 バイトにした。`git checkout --` で復旧し、以後の一括編集はすべて一時ファイル + rename で書いている
- **`CP-T08` が `test_commit.sh` と `test_push.sh` の両方にある**。`git show HEAD:` の版でも両方に存在する既存の重複で、このチケットの変更ではない

## 残課題

- **`shellcheck` の未導入**（環境の制約。導入はソースコード修正の枠外）。静的検査が当面かからない
- **`_sc_classify_web` の curl オプション列挙の網羅性**が確かめられない（f2）
- **仕様からの逸脱 3 件**が実体と文書のずれとして残る（0032 で解消）
- **`.claude/rules/markdown-docs.md` と `ai-asset-authoring.md` が存在しない**。要件書が `.claude/docs/**` に無く、実装フェーズは deny なので 1:1:1 を作れない（0032 の棚卸しへ）
- **`check-html.sh` は md と HTML の内容一致を検査しない**（12 回連続の申し送り）。生成のたびに目視している
