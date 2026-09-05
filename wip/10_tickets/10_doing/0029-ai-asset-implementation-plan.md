---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画の差分 3 により人間レビューは行わない"}
adversarial_review: {required: false, reason: "本フェーズの敵対的レビューは上限 1 回に達している"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-05T16:54:25+09:00"
completed_at: ""
base_sha: "ae43bd7"
---

# 0029 実装計画の穴 9 件を塞ぐ（敵対的レビュー）: チケットの宣言不足と復旧手順

## 目的

実装・テスト計画の敵対的レビューで裏取りされた 9 件を、計画書と未着手の実装チケット 10 枚に反映する。着手すると即座に止まる宣言の不足を先に直す。

## DoD

- [x] 指摘 1: 実装チケット 0018 から 0027 の allow.ops に build-test を足した。run-tests.sh が TR006 で止まらないことを根拠で示した（根拠: run-tests.sh 87〜95 行が `need="build-test"` を無条件に置き、hooks を含むときだけ `need="build-test hook-test"` に広げることを実測。10 枚とも `["read", "remote-read", "build-test", "hook-test"]` に統一し、計画書「許可範囲案」の表と一致させた）
- [x] 指摘 2・3: 0023 と 0025 の allow.write を計画書の許可範囲案どおりに直した。他の 8 枚も DoD の作業対象が宣言に収まっているか全件確かめた（根拠: 下の「判断と根拠」の突き合わせ表 10 行。0023 = `[".claude/skills/**", ".claude/evals/**"]`、0025 = `[".claude/skills/**", ".claude/agents/**", ".claude/rules/**", ".claude/evals/**"]`。全件確認で 0018 の `.claude/hooks/config/**` 欠落も見つけて足した。全 10 枚に `wip/**` も足して表と一致させた）
- [x] 指摘 4: ロックアウト対策の復旧手順を、機構に拒否されない形（git show で取り Write で書き戻す）に直した。各チケットの宣言が書き戻し先を含むことを確かめた（根拠: `.claude/hooks/lib/scope.sh` 36 行の `_SC_GIT_READ_SUBCMDS` に `checkout` が無く `show` があることを実測。計画書「ロックアウト対策」に復旧の共通手順の節を新設し、S1〜S10 の 10 行すべてを書き換えて、各行に「どのチケットの allow.write に入っているか」を明記した。0019〜0025 のチケット本文にも同じ 1 行を入れた）
- [x] 指摘 5: S10 と 0027 の成果を実測の記録と判定の提案に限り、発効に要る仕様の改訂はフィードバック計画へ渡すと書いた（根拠: `10_spec/skills/00-workflow-issue-mr-driven.md`「解禁の条件」1 の第 2 択の後半を引用のうえ、計画書の「この計画で何をするか」2・ステップ S10・変更対象 #26・保留 P1 と、0027 の DoD 3 項目・作業内容を書き換えた。`worktree.baseRef` は判定によらず取り除く形にした）
- [x] 指摘 6: 0023 の predecessors に 0021 を足した（根拠: 0023 の DoD「機械テスト WG-T21 が引き続き通る（S4 で入れた置き場引数の例外を S6 の実体で踏み直す）」が 0021 の新設テストに依存する。frontmatter を `["0020", "0021"]` にし、計画書の「方法とステップ」表・「チケット」表・理由 (3) も直した）
- [x] 指摘 7・8・9: 参照更新一覧の現状値・変更対象の割り付け・S1 の確認操作と識別子を実体に合わせて直した（根拠: 7 = `grep -rn 'WF207' --include="*.sh" .claude/` が 6 行（workflow-guard.sh 113・138 / test_workflow_guard.sh 83・239・240・241）であることを実測し、計画書の行 5 と 0026 の DoD を 6 行に直した。8 = 変更対象 #24 の割り付けを S8 から S6 へ（テスト方針の WT-E01〜E03・ステップ S6・0023 の DoD・HTML の S6 節がすべて S6 で、#24 だけが外れていた）。9 = S1 の確認操作②を「`.gitignore` への Edit が WF201 にならず allow（stage 5）で記録される」に置き換え、0018 の DoD と作業内容の WF205 も WF201 に直した）
- [x] md と HTML の対が保たれ check-html.sh を通る（根拠: `bash .claude/skills/20-common-step-report-view/scripts/check-html.sh wip/20_plans/0016-ai-asset-implementation-plan.html` → 「OK: 検査 7 項目すべて通過（id 11 件 / リンク 8 件を確認。テンプレート: plan）」。HTML 側も S10 節・許可範囲の箱・参照更新一覧 行 5・チケット表 2 行・ロックアウト対策の全 10 行と共通手順の箱・保留 P1 と新設 P5 を同じ内容に更新した）

## 作業内容

- MR のコメント（敵対的レビューの指摘 9 件）を読む
- 指摘 1 から 3 のチケットの宣言を先に直す。着手を止める指摘なので最優先
- 宣言の変更が機構に拒否される場合は迂回せず、ticket.sh で作り直すか結果報告に上げる

## 作業ログ

### 現在地

- 指摘 1〜9 の反映を完了。チケット 0018〜0027 の frontmatter（`allow.ops` 10 枚 / `allow.write` 10 枚 / `predecessors` 1 枚）と DoD（0018・0026・0027）、計画書 md と HTML を直し、`check-html.sh` が通った
- 残り: コミットと `ticket.sh complete`

### うまくいったこと

- 未着手チケットの frontmatter は `00_todo/` にあるため `workflow-state-guard` の保護（WF302 は作業中の置き場への新規作成、WF303 は完了の置き場）に当たらず、Edit ツールでそのまま直せた。`ticket.sh cancel` して作り直す必要が無く、番号の付け替えと `predecessors` の全件修正を避けられた
- 指摘の裏取りを 4 件（TR006 の `need`、WF207 のヒット行数、`_SC_GIT_READ_SUBCMDS` に `checkout` が無いこと、解禁の条件 1 の第 2 択の全文）実測してから直したので、直し方を推測で決めずに済んだ
- 直した後に `ticket.sh next` を 1 回通し、10 枚の frontmatter が壊れていないことを確かめられた

### うまくいかなかったこと

- 計画チケットの `allow.ops` は `["read", "remote-read"]` なので `bash` の任意実行ができず、frontmatter パーサ（`fm_list`）を直接呼んで宣言の解釈を確かめられなかった。代わりに `ticket.sh next`（提供コマンド）が 10 枚を読めることで代替した
- `cd <パス> && wc -l ...` が WF204 で拒否された（`cd` も `wc` も分類外）。以後は絶対パスと `sed -n` / `grep` に切り替えた。これは本 issue の S3 が閉じようとしている穴そのもので、`cd` は「分類に足さない」と設計が決めているので開かない

### 仕様からの逸脱

- 無し（本チケットは計画書とチケットだけを触り、`.claude/` 配下には一切書き込んでいない）

### 判断と根拠

- **DoD の作業対象 × `allow.write` の突き合わせ（全 10 枚）**。レビュアーが名指ししたのは 0023・0025 だけだったので、残り 8 枚も機械的に確かめた。訂正前 → 訂正後は次のとおり。
  - 0018: `[".gitignore"]` → `["wip/**", ".claude/hooks/config/**", ".gitignore"]`（DoD が `scope-limits.json` の編集とレポートの新設を求めるのに、どちらも宣言の外だった。**レビュアーが挙げていない 3 件目の write の穴**）
  - 0019〜0022: `[".claude/hooks/**"]` → `["wip/**", ".claude/hooks/**"]`（作業対象は覆えていた。`wip/**` は計画書の表に合わせただけで、`wip/10_tickets|20_plans|30_reports|tmp` は `common.allow` により判定順 (5) で allow になるため実質は無害な追加）
  - 0023: `[".claude/evals/**"]` → `["wip/**", ".claude/skills/**", ".claude/evals/**"]`（指摘 2）
  - 0024: `[".claude/skills/**"]` → `["wip/**", ".claude/skills/**"]`（`ticket.sh` / `push.sh` / `boundary.sh` とその 3 本のテストはすべて `.claude/skills/**` の下にあり覆えていた）
  - 0025: `[".claude/evals/**"]` → `["wip/**", ".claude/skills/**", ".claude/agents/**", ".claude/rules/**", ".claude/evals/**"]`（指摘 3）
  - 0026: `[".claude/**"]` → `["wip/**", ".claude/**"]`
  - 0027: `[".claude/settings.json"]` → `["wip/**", ".claude/settings.json"]`
- **`wip/**` を足すかどうか**。`scope.sh` の判定順 (5) は `common.allow` に当たれば宣言と無関係に allow を返すので、`wip/**` の宣言は機能上は無くても同じである。それでも足したのは、計画書「許可範囲案」の表と起票済みチケットが 1 対 1 で読み比べられる状態を優先したためである（今回の指摘 1〜3 は、まさに表とチケットがずれていたことが原因だった）
- **`executor` と `human_review` は変えていない**。0018 と 0027 は `common.confirm` の 2 か所（`.claude/hooks/config/**`・`.claude/settings.json`）に書き込むため、判定順 (4) で必ず `WF203`（ask）になり、サブエージェント実行者では deny に落ち得る。これは実行者の付け替えで解けるが、本チケットの禁止事項が `executor` の変更を禁じているので、計画書の保留 P5 と各チケットの作業内容に「拒否されたら結果報告に上げ、呼び出し元が代行する」と書いて人間の判断に委ねた
- **0026 の「5 経路」を 4 経路に減らした**（レビュアーの 9 件に無い 10 件目）。DoD が `push.sh` の実行を求めていたが、(a) 実行者は自分の作業中チケットを持つので push 前チェック 項目 2「作業中チケットなし」で必ず `CP005` になり、(b) `remote-write:push` は `types["ai-asset-implementation"].ops` に無いので `scope_op_declared` を通らない。`push.sh` に dry-run は無い（`--help` だけ）。よって `CP-T12` の PASS と項目 5 の実装で代え、実際の push は切れ目で呼び出し元が行うと書き直した
- **新しい実装チケットは 1 枚も増やしていない**。既存 10 枚の宣言・`predecessors`・DoD の訂正だけで 9 件すべてが閉じた

### 拒否・確認・迂回の記録

- `WF204`（`cd ... && wc -l ...`）: 1 回。迂回せず、絶対パスの `cat -n` / `sed -n` に切り替えた
- `WF204`（`bash <絶対パス>/check-html.sh`）: 1 回。提供コマンドの識別はルート相対表記だけなので、`bash .claude/skills/.../check-html.sh` の形に直して通した（本 issue の S3・HK-T12 が固定しようとしている振る舞いを実地で踏んだ）
- チケットの frontmatter・DoD・計画書 md / HTML への書き込みは 1 件も拒否されなかった（`ticket.sh cancel` での作り直しは不要だった）

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-plan`: 差し戻し（同種の追加チケット）のときは「計画書と起票済みの未着手チケットを直す」という共通手順の記述がそのまま効いた
- `20-common-step-report-view` の `check-html.sh`: md を直すたびに HTML の取りこぼしを検出できる形になっており、7 項目で通過を確認できた
- `20-common-step-ticket` の `ticket.sh next`: 10 枚の frontmatter が壊れていないことの確認に流用できた（本来の用途ではないが、提供コマンドで読めることが検証になる）

### スコープ外で見つけたこと

- `run-tests.sh` の TR006 は**作業中チケットの 1 枚目**（`doing[0]`）しか見ない。1 作業ツリー 1 枚の前提が崩れると検査が緩む側に倒れるが、本 issue の S4（WF207 の作業ツリー単位化）と隣接する話なので、実装フェーズの逸脱として拾えるように残す
- `push.sh` に dry-run（前チェックだけ実行して push しない）が無い。実装フェーズや計画フェーズから push 経路の健全性を確かめる手段が無く、今回 0026 の DoD を弱めることになった。別 issue の候補

### AI アセットに反映すべき内容

- `10-task-*-plan` の共通手順に「**計画書の許可範囲案の表を書いたら、起票する（起票済みの）チケットの frontmatter とその場で 1 対 1 で突き合わせる**」を足したい。今回の指摘 1〜3 は、計画書の表は正しいのにチケットへ写されていなかったことが原因である（機械検査があれば全件防げる類の穴）
- `10-task-ai-asset-implementation-plan` の「ロックアウト対策」に「**復旧手順に書いてよい git のサブコマンドは `_SC_GIT_READ_SUBCMDS` にあるものだけ（`show` は可・`checkout` / `restore` / `switch` は不可）**」を明記したい。今回の指摘 4 はこの 1 行があれば起きなかった
- `10-task-*-plan` に「**DoD にコマンドの実行を書くときは、そのチケットの `executor` と `types[t].ops` でそのコマンドが通るかを確かめる**」を足したい（0026 の `push.sh` の件）

### 備考

- 直したファイルは計画書 2 本（md / HTML）と未着手チケット 10 枚。`.claude/` 配下は 1 ファイルも変更していない
