---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0023"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/skills/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-06T02:31:49+09:00"
completed_at: "2026-09-06T03:36:34+09:00"
base_sha: "748a849"
---

# 0024 S7 提供コマンド b: ticket.sh の TK009・push.sh の項目 5・boundary.sh の切れ目判定

## 目的

チケットの採番と push を本流に一本化し（DDR i0050-05）、切れ目の判定を全作業ツリーで行い last_task を既出の切れ目の補集合で決める（DDR i0050-09・i0050-10）。変更後の自分のコマンドで自分をコミット・完了させる並びを守る。

## DoD

- [x] ticket.sh の create が仕様書 10_spec/skills/20-common-step-ticket.md の TK009 のとおりになっている（作業ツリーでの create は終了 1 でチケットを 1 枚も作らない。本流かどうかの判定は 20-common-step-worktree 仕様のものを共有し、作り直さない）（根拠: `ticket.sh` の `cmd_create` 手順 0（`wt_is_main_root` → `result_ng 009`）。判定の 4 行は `worktree.sh` からのバイト一致コピーで `TICKET-T13` の 2 assert が固定。レポート e35）
- [x] push.sh の push 前チェックに項目 5（本流でのみ push する。スキップ不可）が入っている（仕様書 10_spec/skills/20-common-step-commit-push.md）（根拠: `push.sh` の `ITEM_NAMES[5]` と項目 5 の検査、`SKIP4_REQUESTED` → `FIXED_REQUESTED` の一般化。`CP-T12` PASS。レポート e36）
- [x] boundary.sh の last_task が既出の切れ目の補集合で決まり（DDR i0050-10）、at_boundary がすべての作業ツリーを見る（管理対象の作業ツリーが 0 なら worktree.sh を呼ばない）（根拠: `load_covered` / `scan_tickets` の 4 段と `worktrees_have_doing`（前置きに `has_other_worktrees`）。`BD-T20` / `BD-T21` PASS。レポート e37・e38）
- [x] 機械テスト TICKET-T13 が通る（run-tests.sh --filter '*test_ticket*'）。負のコントロール（同じ引数を本流で実行すれば作られる）を含む（根拠: `passed=139 failures=0`。負のコントロールは「同じ引数を本流で実行すると 0016 が作成される」）
- [x] 機械テスト CP-T12 が通る（run-tests.sh --filter '*test_push*'）。wip/push-check-skip.md に項目 5 を書いても飛ばせない（根拠: `passed=62 failures=0`。記録をコミットしても `項目 5 の指定は無効` になり `skip 項目 5` は出ない。リモートに `wtcp12` が増えないことも assert）
- [x] 機械テスト BD-T20 と BD-T21 が通る（run-tests.sh --filter '*test_boundary*'）。BD-T21 は worktree.sh の呼び出し回数 0 を make_counting_path で確かめる（根拠: `passed=142 failures=0`。`make_counting_path` の記録先と `counted_calls worktree.sh` で 0 回 / 1 回を確認）
- [x] 既存の TICKET-T01〜T12・CP-T01〜T11・BD-T01〜T19 が引き続き通る（回帰）（根拠: 担当 3 本が全 PASS。全件テストも `OK: 28 本 / 243 件`・FAIL 0）
- [x] 変更 → commit.sh で自分をコミット（この 1 回目が検証を兼ねる）→ ticket.sh complete の並びで本チケットを閉じた。start / complete の経路に create の分岐を足していない（根拠: `commit.sh` の `6888a87`。`wt_is_main_root` の呼び出しは `cmd_create` の 1 か所のみ。レポート e39）
- [x] 実装結果レポートに本チケットの節が追記され、completed_at を持たないチケットの last_task の扱い（R59。仕様に記述が無い）が「仕様からの逸脱」ではなく残課題として記録されている（根拠: `wip/30_reports/0018-ai-asset-implementation.md` の e35〜e39 と残課題 R31（= 設計結果の R59）。逸脱の表には入れていない）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S7 と「ロックアウト対策」の S7 行に従う
- ticket.sh が壊れるとチケットを完了させる手段が無くなる。壊れたら git show <base_sha>:<パス> で内容を取り、Write / Edit ツールで書き戻す（git checkout は分類が unknown で WF204 になる）。書き戻し先（.claude/skills/**）は本チケットの allow.write に入っている

## 作業ログ

### 現在地

- 済: すべて完了（実装 → 担当 3 本 → 全件テスト `OK: 28 本 / 243 件` → レポート md / HTML の追記と `check-html.sh` 通過 → `commit.sh` → 完了）

### うまくいったこと

- テスト先行の順で `TICKET-T13`・`CP-T12`・`BD-T20`・`BD-T21` を書き、いずれも実装前に落ちることを確認してから実装した（下の「判断と根拠」に失敗時の出力を要約）
- 「本流かどうかの判定」は `worktree.sh` の 4 行をそのまま `ticket.sh` / `push.sh` へコピーし、3 本のバイト一致を `TICKET-T13` で固定した（DDR `i0009-36` の `__ss_load` と同じやり方）
- 変更後の `commit.sh` / `ticket.sh` で自分をコミット・完了できた（ロックアウト対策の並び）

### うまくいかなかったこと

- `test_ticket.sh` の一時リポジトリは `wip/10_tickets/*/.gitkeep` を持たないため、作業ツリーへチェックアウトすると `10_doing/` が存在せず、作業ツリー側の `start` が置き場の不在で落ちた。本番のリポジトリは `.gitkeep` を追跡しているので、テストの足場を本番に合わせて直した（`ticket.sh` は変えていない）

### 仕様からの逸脱

- **既出集合（`covered`）を現在の MR の切れ目に限った**。仕様「切れ目の判定（正）」は `covered` = `review-history.jsonl` の全行の `boundary.tickets` ∪ `review-state.json` の `boundary.tickets` としか書いていないが、`logs/` は clone に溜まり続ける一方でチケット番号は片付け（draft 解除）のたびに 0001 から振り直されるため、別 issue の切れ目に載った同じ番号でいまの issue のチケットが既出扱いになる。実リポジトリでも `mr: null` の行に `0024,0025,0026` が載っており、絞らないと本チケット自身が `last_task` から落ちた。`logs/mr.json` の `mr` と一致する記録だけを数え、MR が分からないときは全件を数える（拒否側）。負のコントロール込みで `BD-T20` に固定した

### 判断と根拠

- 本流かどうかの判定の共有は、呼び出し元の指示どおり①（同じ 4 行を 3 か所に書き、バイト一致をテストで固定）を採った。②の共有ライブラリ化は `20-common-step-shell-script` 仕様（`.claude/docs/**`）の変更が要り、本チケットの許可範囲の外
- パスの比較は綴りの二重性で壊れる（R25）ので、判定は `[ -d "$1/.git" ]` の存在検査だけにし、前方一致も文字列比較も使わない。案内に出す本流の置き場は `git rev-parse --git-common-dir` から導く（表示専用で判定には使わない）
- `completed_at` を持たないチケットの並べ替えは「空文字＝最も早い」に倒し、同着は連番の昇順で解いた。持ち越し続けて二度と切れ目に入らない事態を避けるため。仕様に記述が無いのでレポートの残課題（R59）に残した
- `at_boundary` の作業ツリー横断判定は、まず `git worktree list --porcelain` の行数で本流以外の登録があるかを見て、無ければ `worktree.sh` を起動しない（`BD-T21` で呼び出し 0 回を固定）
- テスト先行の失敗確認: `TICKET-T13` は作業ツリーでの `create` が `OK`（exit 0）でチケットを 1 枚作った / `CP-T12` は作業ツリーからサブブランチ `wtcp12` を実際に push した / `BD-T20` は `last_task` が `{0013}` のまま持ち越し `0012` が落ちた / `BD-T21` は作業ツリーに作業中 1 枚があるのに `at_boundary` が true になった

### 拒否・確認・迂回の記録

- `python` を作業ログの書き換えに使おうとして `WF204` で拒否された。迂回せず Edit ツールに切り替えた
- `cd` を使ったコマンドが `WF204` で拒否された。以後は絶対パス・リポジトリルート相対で実行した

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec` / `10-task-investigation-exec`（共通手順）: テスト先行・逸脱の記録・完了前の検査の順序が明確で迷わなかった
- `20-common-step-ticket` / `20-common-step-commit-push`: 変更後の自分のコマンドで自分を閉じる並びをそのまま実行できた

### スコープ外で見つけたこと

- 本リポジトリの `logs/review-history.jsonl` には、`0010`（ai-asset-design-plan）と `0016`（ai-asset-implementation-plan）の切れ目の記録が無い。`covered` の補集合で切ると次の切れ目の `last_task` は `{0010}` になり、`0016` と `0018`〜`0024` は持ち越される。仕様どおりの振る舞い（レビュー未通過のチケットを拾う）だが、切れ目が数回続くので呼び出し元に伝える

### AI アセットに反映すべき内容

- `00-workflow-issue-mr-driven` 仕様「切れ目の判定（正）」に、`covered` を現在の MR の記録に限る旨（および `completed_at` 欠落時の並べ替え）を書き足す提案。設計反映フェーズで扱う

### 備考

- 無し
