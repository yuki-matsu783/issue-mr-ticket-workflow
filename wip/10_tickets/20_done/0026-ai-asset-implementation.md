---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0018", "0019", "0020", "0021", "0022", "0023", "0024", "0025"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-06T04:34:23+09:00"
completed_at: "2026-09-06T05:27:26+09:00"
base_sha: "cbd6fb5"
---

# 0026 S9 参照更新と全体検査

## 目的

計画書の参照更新一覧 7 行を検索して消し込み、プレースホルダ・frontmatter・全機械テストの回帰を通し、本 issue の残り（実装・フィードバック・全体まとめ）が回せることを確かめる。

## DoD

- [x] 参照更新一覧の 7 行それぞれについて、計画書に書かれた検索語を実行し、期待値（残るものの件数と場所）と一致することが根拠付きで示されている（0 件を成功条件にしない）（根拠: レポート e46 の表と、作業ログ「検索の記録（参照更新一覧 7 行）」。7 行すべてで検索語を実行し、5 行は期待値どおりかそれ以上・2 行（#1・#5）は +1 行で、増分の理由を仕様の条文（フック共通仕様 §5 の根の列 / 20-common-step-worktree 仕様 add 6）と `git grep -n … dd9b0a3` の突き合わせで示した）
- [x] 行 1: grep -rn 'HOOK_WORKTREE/logs/' --include="*.sh" .claude/ の結果が logs/hooks/ の 2 行だけになり、grep -rn 'HOOK_SHARED_ROOT/logs/' --include="*.sh" .claude/ が 22 行以上ある（根拠: 後半は **22 行**で充足。前半は **3 行**で、logs/hooks/ の 2 行（`subagent-stop-check.sh:211`・`hook-common.sh:746`）に加えて `hook-common.sh:412` の `$HOOK_WORKTREE/logs/sh` が残る。**この 1 行は仕様どおり**（フック共通仕様 §5 の根の列が `logs/sh/` を「ツリー」と定め、`20-common-step-worktree` 仕様 add 6 が「作業ツリーに logs/hooks/ と logs/sh/ の 2 つだけを作る」と書く）。共有ルートへ移すと仕様に反するので直さず、逸脱 D26 と e46 に記録した。**この項目は字句どおりには満たしていない**ので◆に上げた）
- [x] 行 2〜4・7: 20-common-step-worktree / worktree.sh / HOOK_SHARED_ROOT / worktree-merges がアセット側に計画書の期待値どおり現れる（docs 側は除外）（根拠: #2 = 16 ファイル / 41 行（期待値 5 ファイル以上。列挙の 7 つを全部含む）、#3 = 19 ファイル / 69 行（期待値 6 以上。列挙の 6 つを全部含む）、#4 = 33 行 / 5 ファイル（`hook-common.sh` の代入 2 か所 + 参照 22 行 + `test_hook_common.sh` 5 行）、#7 = 5 行 / 4 ファイル（期待値 3 以上）。4 行とも期待値以上。レポート e46 の表）
- [x] 行 5: WF207 のヒットが 6 行のまま（workflow-guard.sh 2 行・test_workflow_guard.sh 4 行。番号の増減が無く）、workflow-guard.sh の hook_deny WF207 の文言に「この作業ツリーで」が入っている（根拠: 文言は充足（`workflow-guard.sh:150` に「この作業ツリーで bash .claude/skills/20-common-step-ticket/scripts/ticket.sh を使い」）。件数は **7 行**で +1。`git grep -n 'WF207' dd9b0a3 -- '.claude/*.sh'` の 6 行は**内容が同じまま全部残っている**（行番号だけ 113→123・138→150・239〜241→279〜281 に移動）。増えた 1 行は 0021 が `WG-T19` に足したコメント `test_workflow_guard.sh:533`「WF207 は出ない（…）」で、**エラー識別子の削除・追加は 0 件**。DoD の本旨（番号が変わらず文言だけが変わる）は満たすが、**件数は字句どおりでない**ので◆に上げた）
- [x] 行 6: TK00[0-9] のアセット側ヒットが 54 行以上で、既存 53 行が減っていない（根拠: **64 行**。計画時 `dd9b0a3` のアセット側 53 行をファイル別に数え、現在の件数と比較した結果、**全ファイルで現在 ≧ 計画時**（減ったファイルは 0 件）。増分 11 の内訳は `ticket.sh` +2・`test_ticket.sh` +2・`20-common-step-ticket/SKILL.md` +3・`task-executor.md` +2・`work-defaults.md` +1・`20-common-step-worktree/SKILL.md` +1 で、`TK009` と `TICKET-T13` の追加分に対応する）
- [x] プレースホルダ（{{ }} / TODO / TBD）の検査が変更した全アセットで 0 件で、frontmatter が種別ごとの必須項目を満たす（根拠: この issue が変更した 35 アセット（`git diff --name-only $(git merge-base main HEAD)..HEAD -- .claude/agents .claude/evals .claude/hooks .claude/rules .claude/skills`）に対して、二重波かっこの残存 **0 件**（`assets/*.template.*` は規約で対象外、`ticket.sh` の置換表は埋める側のコード）、`TODO` / `TBD` の残存 **0 件**（7 行はすべて `$TODO` シェル変数）。frontmatter は **10 / 10 OK**（スキル 5 = 2 キー / エージェント 1 = 4 キー / eval 4 = 5 キー / ルール 1 = 7 キー）。レポート e47 と「検査結果」の表）
- [x] bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids が FAIL 0 件・ID 重複 0 件で、割付表の機械テスト 37 件が PASS の一覧に含まれる（根拠: `run-tests.sh --ids --timeout 300` = **`OK: 28 本 / 243 件`**、28 本すべて PASS、`FAIL ID:` 空、**重複 ID なし**。割付表の 37 件（`HK-T01`・`HK-T05`・`HK-T06`・`HK-T12`・`HK-T15`・`HK-T21`・`HK-T22`・`WG-T14`・`WG-T19`〜`WG-T21`・`SG-T12`・`SG-T13`・`DC-T08`・`DC-T09`・`SA-T10`・`SA-T11`・`SP-T05`・`SP-T08`・`SP-T09`・`SE-T11`・`WT-T01`〜`WT-T12`・`TICKET-T13`・`CP-T12`・`BD-T20`・`BD-T21`）は **37 / 37** が `PASS ID:` の一覧にある。レポート e48 と「テスト結果」の照合表）
- [x] 本 issue の残りが回せることを 4 経路で確かめた（commit.sh / boundary.sh status / ticket.sh next / run-tests.sh）。拒否されたものは識別子と対処を記録する（根拠: **4 / 4 成功・拒否 0 件**。①`ticket.sh next` → `{"current":null,"next":"0026",…}`、`start 0026` → `OK:（基準点 cbd6fb5 / コミット d4d2e93）` ②`boundary.sh status` → JSON（`at_boundary:false` / `position:"in_task"` / `current:"0026"` / `mr:51`。S7 の「管理対象の作業ツリーが 0 なら worktree.sh を呼ばない」経路が通った）③`commit.sh` → 成功（このチケットの成果物）④`run-tests.sh --ids --timeout 300` → `OK: 28 本 / 243 件`。**`WF2xx` / `CP0xx` / `TK0xx` の拒否は 1 件も出ていない**。レポート e49）
- [x] push.sh は実行せず、代わりに CP-T12 の PASS と push 前チェック 項目 5 の実装をもって経路が残っていることを示した（理由: 実行者は作業中チケットを持つので項目 2 で必ず CP005 になり、remote-write:push は ai-asset-implementation の types ops に無いので通らない。実際の push は切れ目で呼び出し元が行う）（根拠: `push.sh` は 1 度も実行していない。`CP-T12` は `test_push.sh`（`passed=62 failures=0`）で **PASS** し、作業ツリーからの `push.sh` が項目 5 未充足の `CP005` になり `wip/push-check-skip.md` に書いても飛ばせずリモートにサブブランチが増えないこと、**負のコントロールとして同じリポジトリの本流では項目 5 が通ること**を固定している。実装は `push.sh:171-179`（`ITEM_NAMES[5]="本流で実行している"`／スキップ記録の読み取りは項目 1〜3 に限り項目 4・5 は `FIXED_REQUESTED` に集めて無視）。`scope-limits.json` の `types["ai-asset-implementation"].ops` に `remote-write:push` が無いことも確認済み。レポート e49）
- [x] 実装結果レポートの逸脱一覧が締められ、md と HTML の対が check-html.sh を通っている（根拠: 逸脱は **D1〜D26 の 26 件**で、S9 分の D26 を足したうえで「S1〜S9 分の逸脱一覧はここで締める」の段落を md と HTML の両方に置いた（26 件すべてに扱い列があり宙に浮いた項目は無い。S10 の分は D27 以降）。`bash .claude/skills/20-common-step-report-view/scripts/check-html.sh wip/30_reports/0018-ai-asset-implementation.html` = **`OK: 検査 7 項目すべて通過（id 69 件 / リンク 62 件を確認。テンプレート: report）`**）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S9 と「参照更新一覧」に従う

## 作業ログ

### 現在地

- **完了**。参照更新一覧 7 行の検索・消し込み（アセットの修正は 0 行）／プレースホルダ・frontmatter の検査／全件テスト `OK: 28 本 / 243 件`（FAIL 0・重複 0）／4 経路の確認（拒否 0 件）／レポート md + HTML への追記（e46〜e50・逸脱 D26・残課題 R42〜R45）と `check-html.sh` 通過まで終えた。この後は `commit.sh` → `ticket.sh complete 0026`。**0027（S10）には着手しない**

### 検索の記録（参照更新一覧 7 行）

| # | 検索語 | 期待値（計画書） | 実測 | 判定 |
|---|---|---|---|---|
| 1 | `grep -rn 'HOOK_WORKTREE/logs/' --include="*.sh" .claude/` | `logs/hooks/` の 2 行だけ | **3 行**（`subagent-stop-check.sh:211` と `hook-common.sh:746` = `logs/hooks/decisions.jsonl`、`hook-common.sh:412` = `logs/sh`） | 実質 OK（+1 行は `__hc_relog` の `logs/sh`。フック共通仕様 §5 の根の列が「`logs/sh/` はツリー」と定めるので**作業ツリー側が正**。計画書の「logger 経由でこの検索に現れない」という前提が S2 の実装で変わった） |
| 1b | `grep -rn 'HOOK_SHARED_ROOT/logs/' --include="*.sh" .claude/` | 22 行以上 | **22 行**（`mr.json` 7・`merge-state.json` 4・`locks` 3・`$__se_sf` 2・`sessions` 4・`usage` 2・`review-state.json` 1・`push-state.json` 1） | OK |
| 2 | `grep -rn '20-common-step-worktree' --include="*.md" --include="*.sh" .claude/skills/ .claude/agents/ .claude/rules/ .claude/evals/` | アセット側 5 ファイル以上（列挙の 7 つを含む） | **16 ファイル / 41 行**。列挙の 7 つ（`20-common-step-worktree/SKILL.md`・`00-workflow-issue-mr-driven/SKILL.md`・`10-task-investigation-exec/SKILL.md`・`20-common-step-ticket/SKILL.md`・`20-common-step-commit-push/SKILL.md`・`agents/task-executor.md`・`evals/20-common-step-worktree.md`）がすべて含まれる | OK |
| 3 | `grep -rn 'worktree\.sh' --include="*.md" --include="*.sh" .claude/`（docs 除外） | アセット側 6 ファイル以上 | **19 ファイル / 69 行**。列挙の 6 つ（実体・テスト・SKILL.md・`boundary.sh`・`00-workflow-issue-mr-driven/SKILL.md`・eval 定義）がすべて含まれる | OK |
| 4 | `grep -rn 'HOOK_SHARED_ROOT' --include="*.sh" .claude/` | `hook-common.sh` の定義 1 か所 + 参照 22 行以上、`test_hook_common.sh` にも現れる | **33 行 / 5 ファイル**。`hook-common.sh` 13（うち代入は 38 行目の固定と 339 行目の貼り直しの 2 か所）・`session-start.sh` 8・`post-push-usage-report.sh` 4・`post-push-compact-prompt.sh` 3・`test_hook_common.sh` 5。`HOOK_SHARED_ROOT/logs/` の参照は 22 行 | OK |
| 5 | `grep -rn 'WF207' --include="*.sh" .claude/` | 6 行のまま（`workflow-guard.sh` 2・`test_workflow_guard.sh` 4）。番号の増減なし。文言に「この作業ツリーで」 | **7 行**（`workflow-guard.sh` 123・150 / `test_workflow_guard.sh` 83・279・280・281・**533**）。計画時（`dd9b0a3`）の 6 行は**内容が同じまま全部残っている**（行番号だけ移動）。+1 は 0021 が `WG-T19` に足したコメント行 533「`WF207` は出ない（…）」。`hook_deny WF207` の文言に「この作業ツリーで」が入っている（150 行目） | 実質 OK（識別子の削除・追加は 0 件。増えたのは負のコントロールのコメント 1 行） |
| 6 | `grep -rn 'TK00[0-9]' --include="*.sh" --include="*.md" .claude/ \| grep -v '^\.claude/docs'` | 54 行以上、既存 53 行は減らない | **64 行**。計画時（`dd9b0a3`）の 53 行はファイル別に見ても 1 件も減っていない（`git grep -n 'TK00[0-9]' dd9b0a3` と現在のファイル別件数を比較。全ファイルで現在 ≧ 計画時）。増分 11 は `ticket.sh` +2・`test_ticket.sh` +2・`20-common-step-ticket/SKILL.md` +3・`task-executor.md` +2・`work-defaults.md` +1・`20-common-step-worktree/SKILL.md` +1 | OK |
| 7 | `grep -rn 'worktree-merges' --include="*.sh" --include="*.md" .claude/`（docs 除外） | アセット側 3 か所以上 | **5 行 / 4 ファイル**（`worktree.sh` 1・`test_worktree.sh` 1・`20-common-step-worktree/SKILL.md` 2・`00-workflow-issue-mr-driven/SKILL.md` 1） | OK |

### 検査の記録（プレースホルダ・frontmatter）

- プレースホルダ（二重波かっこ）: 変更した 35 アセット（`git diff --name-only <merge-base>..HEAD` の非 docs 分）に対して `grep -n '{{…}}'` → `assets/*.template.*`（規約で対象外）と `ticket.sh` の置換表（`content="${content//"{{X}}"/…}"`）を除いて **0 件**
- `TODO` / `TBD`: 同じ 35 ファイルに `grep -nw` → **7 行**すべてが `TODO="$TICKETS/00_todo"` 系のシェル変数（`boundary.sh` 2・`ticket.sh` 5）。プレースホルダの残存は **0 件**
- frontmatter: スキル 5 本 = `name` / `description` の **2 キーちょうど**／`agents/task-executor.md` = `name` / `description` / `tools` / `model` の 4 キー（`isolation` は無し）／eval 4 本 = `type` / `title` / `description` / `tags` / `keywords` の 5 キー（`eval.template.md` どおり）／`rules/work-defaults.md` = `type` / `title` / `description` / `tags` / `keywords` / `category` / `applies_when` の 7 キー（行動ルールの形）。**10 / 10 OK**

### テスト・4 経路の記録

- 全件テスト: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --ids --timeout 300`（**1 本だけ**。並行実行しない）→ **`OK: 28 本 / 243 件`**。28 本すべて `PASS / exit 0 / failures=0`、`FAIL ID:` 空、**重複 ID なし**。所要 **21 分 44 秒**（04:40:12 → 05:01:56）
- 割付表の機械テスト **37 / 37** が `PASS ID:` の一覧に含まれる（`HK-T01`・`HK-T05`・`HK-T06`・`HK-T12`・`HK-T15`・`HK-T21`・`HK-T22`・`WG-T14`・`WG-T19`〜`WG-T21`・`SG-T12`・`SG-T13`・`DC-T08`・`DC-T09`・`SA-T10`・`SA-T11`・`SP-T05`・`SP-T08`・`SP-T09`・`SE-T11`・`WT-T01`〜`WT-T12`・`TICKET-T13`・`CP-T12`・`BD-T20`・`BD-T21`）
- 120 秒を超えたテスト: `test_boundary.sh` 165 秒・`test_finalize.sh` 153 秒・`test_workflow_guard.sh` 140 秒（**`--timeout 300` は今も要る** = R9 は閉じない）
- 4 経路: `ticket.sh next` / `start 0026` OK（着手コミット `d4d2e93`）・`boundary.sh status` OK（JSON）・`commit.sh` OK（`OK: 3 ファイルをコミットした（3d64bff）。除外: なし`）・`run-tests.sh` OK。**拒否 0 件**
- `push.sh` は**実行していない**（DoD の明記どおり。項目 2 で必ず `CP005`・`remote-write:push` が `ops` に無い）。`CP-T12` の PASS と `push.sh:171-179` の項目 5 の実装で代えた
- `check-html.sh`: `OK: 検査 7 項目すべて通過（id 69 件 / リンク 62 件を確認。テンプレート: report）`

### うまくいったこと

- **期待値を「残るもの」で書いた計画書の作りが効いた**。#1 と #5 が期待値と食い違ったとき、0 件を成功条件にしていたら「検索語が間違っていた」のか「実装が違う」のかを切り分けられなかった。件数と場所が書いてあったので、`git grep -n … dd9b0a3` で計画時の値と突き合わせて「**期待値の側が古い**」と特定できた
- **`git grep <sha>` で計画時のスナップショットを取れた**。#5（「6 行のまま」）と #6（「既存 53 行が減らない」）は、現在の件数だけを見ても「減っていないこと」を示せない。計画書を書いたコミット `dd9b0a3` に対して同じ検索を掛け、ファイル別の件数を比較する形で「減っていない」を根拠付きで言えた
- 検査の対象を**リポジトリ全体ではなくこの issue が変えた 35 ファイル**に絞ったこと。全体に掛けると `$TODO` シェル変数のような無関係なヒットが 16 件出て、検査の意味が薄れる
- 全件テストを**並行実行せず 1 本だけ**走らせたこと。前回の記録（2 本同時で無関係なテストが TIMEOUT）を踏まえた

### うまくいかなかったこと

- **全件テストが 21 分 44 秒かかった**（見込みは 10 分前後）。前フェーズの記録（0025 の全通しは 04:15〜04:30 の 15 分）より更に伸びている。バックグラウンドに回して待つ形になり、その間は読み取りだけの軽い作業しかできなかった
- **`.gitignore` を `allow` から外す選択肢が実際には無かった**（R2）。0018 は「S9 で外すか選べる」と書いていたが、外すには `common.confirm` の `scope-limits.json` を触る必要があり、サブエージェント実行者には `WF203` で届かない
- **レポートの md と HTML がずれていた**（0025 の積み残し）。アセット一覧の表が md は 41 行まで・HTML は 44 行まであり、eval 定義 3 ファイル（#42〜#44）の行が md 側に無かった。md を HTML に合わせて 3 行足して揃えた（訂正として「判断と根拠」に記録）。HTML の件数タイル（◎良 30 / △注意 7）とサイドバーの `kind`（「実装（S1〜S7 分）」）も 0025 時点の値で止まっていたので、S9 の値へ更新した

### 仕様からの逸脱

- **D26**（レポートに記録）: 実装計画書「参照更新一覧」 #1 の期待値「`logs/hooks/` の 2 行だけ（`logs/sh/` は logger 経由でこの検索に現れない）」と #5 の期待値「同じ 6 行が残る」が、実体（3 行 / 7 行）と +1 ずつずれる。**仕様との食い違いではなく計画書との差**で、仕様（フック共通仕様 §5 の根の列・`20-common-step-worktree` 仕様 `add` 6）に照らすと実装が正しい。**仕様も実装も直していない**
- S9 で新たに見つけた**仕様**との食い違いは無い（D26 は計画書との差）。設計文書（`.claude/docs/**`）は 1 文字も触っていない

### 判断と根拠

- **#1 の 3 行目（`hook-common.sh:412` の `$HOOK_WORKTREE/logs/sh`）を共有ルートへ移さなかった。** 根拠はフック共通仕様 §5 の根の列（`logs/sh/<name>.log` = **ツリー**）と `20-common-step-worktree` 仕様 `add` 6（作業ツリーに `logs/hooks/` と `logs/sh/` の 2 つだけを作る）。移すと仕様に反する。計画書の除外欄が「logger 経由で現れない」と書いたのは、この関数（`__hc_relog`）が S2 で生まれる前の見立てである
- **#5 の 7 行目（`test_workflow_guard.sh:533` のコメント）を消さなかった。** 0021 が `WG-T19` の負のコントロールの意図を書いたコメントで、消すとテストの意図が読めなくなる。DoD の本旨は「エラー識別子の番号が変わらず文言だけが変わる」ことで、そこは満たしている（`git grep` で計画時の 6 行が内容ごと残っていることを確認済み）
- **アセットを 1 行も変えずにチケットを閉じた。** 参照更新の「消し込み」は S1〜S8 が各ステップの中で済ませており、S9 に残っていたのは数え直しと突き合わせだけだった。無理に変更を作らない
- **R21 と R28 を S9 で閉じなかった。** どちらも計画書が「S9 の全体検査」を引き取り先に挙げているが、必要なのは検査ではなく**テストの新設**で、S9 は新設テストを持たないステップ（計画書「依存するテスト」の割り付けにも S9 の行が無い）。設計反映 → 次の実装フェーズへ回した
- **R2 を「残す」で締めた。** 外す手段が実行者に無い（`common.confirm` の `WF203`）ことと、0018 の判断（`.gitattributes` と同じ扱いにしておくほうが後の AI アセットフェーズが設定変更から始めずに済む）による。呼び出し元の代行が要る旨は◇に上げた
- **レポートの md 側アセット一覧に #42〜#44（eval 定義 3 ファイル）を足した（訂正）。** 0025 が HTML にだけ書いて md に書き漏らしたもので、md が正文である以上そろえないと「md と HTML の対」が形だけになる。`10-task-investigation-exec` の「過去の節は書き換えない」は結論の上書きを禁じるもので、**表の欠落行の補完は「表に行を足す」の原則に従う**と判断した。完了済みチケット 0025 には触っていない

### 拒否・確認・迂回の記録

- **`WF204` 1 件**: `cd /c/Users/taniyama/…` を含む複合コマンドを打とうとして拒否された（`cd はどの分類にも当たらない（既定拒否）`）。迂回せず、`cd` を外して同じ `grep` をリポジトリルート相対で打ち直した。**フックの指示どおりの対処で、機構を無効化していない**
- それ以外の拒否は 0 件。`WF201` / `WF205` / `WF601` / `CP0xx` / `TK0xx` は 1 件も出ていない（`.claude/**` への書き込みが 0 件だったため）
- **迂回は 0 件**。`git checkout` / `git worktree add` / `WORKFLOW_*_ENFORCE=0` は 1 度も使っていない

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec`（+ 正である `10-task-investigation-exec` の共通手順）: 「完了前の検査」の 3 点（プレースホルダ・frontmatter・参照更新）がそのまま S9 の作業項目になっていて迷いが無かった。ただし**「参照更新一覧の検索語で旧名が 0 件」という書き方**は、計画書の「0 件を期待値にしない」と正面から食い違う（下記「AI アセットに反映すべき内容」）
- `20-common-step-ticket` / `20-common-step-commit-push` / `20-common-step-report-view`: いずれも提供コマンドがそのまま通った。`check-html.sh` は 1 回で通過
- `20-common-step-ai-asset-creator`: 「プレースホルダ検査は `assets/*.template.*` を対象外」「参照更新の期待値は残るもので書く」の 2 点が、今回の判断の直接の根拠になった

### スコープ外で見つけたこと

- レポート md と HTML のアセット一覧が 3 行ずれていた（0025 の積み残し）。md 側に足して揃えた
- HTML の件数タイルとサイドバーの `kind` が 0025 時点で更新されていなかった（◎良 30 / △注意 7 / 「S1〜S7 分」）。S9 の値に更新した。**HTML の目次（TOC）も f39 までしか無く、f40〜f45 が欠けていた**ので、f46〜f50 と一緒に足した
- `boundary.sh status` の `last_task.tickets` が `0018`〜`0025` を返した。0024 のレポート R32 は「次の切れ目の `last_task` は `{0010}` になる」と予測していたが、実際には 0018〜0025 のまとまりになっている（`review-history.jsonl` に記録が足されたためと思われる）。**S9 の担当外なので調べていない**が、R32 の見通しが変わっている可能性がある

### AI アセットに反映すべき内容

- **`10-task-ai-asset-implementation-exec` の「完了前の検査」の文言**: 「参照更新一覧の検索語で**旧名が 0 件**（DDR・用語辞書の別名を除く）」と書いてあるが、`20-common-step-ai-asset-creator` 手順 6 と実装計画書は「**期待値は『残るもの』で書く。0 件を期待値にすると、検索式が間違って何もヒットしない場合と区別が付かない**」と定めている。**2 つのスキルが逆のことを言っている**。前者を「参照更新一覧の各行の期待値（残るものの件数と場所）と一致する」に直すべき
- **参照更新一覧の期待値が実装に追い越される問題**（R44）。計画時に書いた件数は、後続ステップが行を足すと古くなる。実装計画スキルに「期待値には後続ステップで増える分の見込みを添える」か「消し込みステップで数え直す前提」を明記したい
- **検査だけのステップの裏付け**（R45）。参照更新一覧を TSV（検索語・除外・期待値の下限/上限）にして `run-tests.sh` に載せれば、消し込みの実行そのものが機械テストになる

### 備考

- レポートは `wip/30_reports/0018-ai-asset-implementation.md` に追記（節 e46〜e50・逸脱 D26・設計への反映 #32/#33・想定と異なった点 5 行・残課題 R42〜R45）。HTML の対も同じ内容で更新し `check-html.sh` を通した
- **0027（S10）には着手していない**（起動プロンプトの指示どおり）
