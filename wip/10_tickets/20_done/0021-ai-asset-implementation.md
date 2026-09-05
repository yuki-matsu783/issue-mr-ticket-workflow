---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019", "0020"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/hooks/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-05T23:17:56+09:00"
completed_at: "2026-09-06T00:17:24+09:00"
base_sha: "e348c12"
---

# 0021 S4 中核 c: 拒否側フック 2 本と A1-6 を閉じる機械テスト

## 目的

workflow-guard の宣言範囲の強制と workflow-state-guard の保護対象の畳み込みを作業ツリーごとに一意にし、受け入れ条件 A1-6（worktree 側のチケットで判定されること）を負のコントロール付きの機械テストで閉じる。

## DoD

- [x] workflow-guard.sh が仕様書 10_spec/hooks/20-PreToolUse/workflow-guard.md の概要（一意性の 2 点）・制御方式 1・2・5・6 のとおりになっている（宣言範囲の強制は「その作業ツリーの作業中チケット 1 枚」で一意に決まり、WF207 は「1 作業ツリーあたり 2 枚」を指す）（根拠: レポート e19。判定に使うチケット（`hook_doing_ticket` = `HOOK_WORKTREE` の 10_doing）と制御方式 5 の根ごとの扱いは S2 で充足済み。S4 で WF207 の文面に `HOOK_WORKTREE` と「1 作業ツリーあたり」を追加し、制御方式 6 の例外を実装。`WG-T08` / `WG-T19` / `WG-T20` / `WG-T21` が PASS）
- [x] workflow-state-guard.sh が仕様書 10_spec/hooks/20-PreToolUse/workflow-state-guard.md「対象パスの畳み込み」・制御方式 2・3 のとおりになっている（作業ツリーをまたぐ絶対パスの保護は無条件）（根拠: レポート e21。**変更 0 行**で仕様どおり = `git diff e348c12 -- .claude/hooks/20-PreToolUse/workflow-state-guard.sh` が空。`SG-T12` / `SG-T13` が PASS し、反転検査で識別力も確認）
- [x] 機械テスト WG-T19 が通る（run-tests.sh --filter '*test_workflow_guard*'）。本流 10_doing/ 0 枚・worktree 1 枚を**テスト自身が assert してから**判定を呼び、worktree 側チケットの宣言で判定される（根拠: レポート e20 / テスト結果の表。`doing_count()` で本流 0・worktree 1 を assert → allow / WF201 / WF202。`passed=217 failures=0`）
- [x] 機械テスト WG-T20（WG-T19 の負のコントロール）が通る。本流 1 枚・worktree 0 枚で cwd=worktree のとき判定に入らない。枚数もテストが assert する（根拠: レポート e20。枚数 1 / 0 を assert し、生出力が空・`$?`=0 を両方 assert。正のコントロール（cwd=本流 で WF201 / WF205）付き）
- [x] 機械テスト WG-T21 と WG-T14 が通る（worktree.sh の置き場を指す引数は WF209 にならず allow / 同じ行の他のパス引数と提供コマンドの引数パスは通常判定）（根拠: レポート e21 前半。**テスト先行で 3 件の FAIL を確認してから実装**。負のコントロール 3 種（名前の位置 / 同じ行の commit.sh / 他の提供コマンド）を含む）
- [x] 機械テスト SG-T12 と SG-T13 が通る（run-tests.sh --filter '*test_workflow_state_guard*'。他の作業ツリーの保護対象への絶対パス書き込みが保護され、集合を読めないときは WF309）（根拠: レポート e21 後半。`passed=109 failures=0`。反転検査で 3 件だけが FAIL することを確認してから戻した）
- [x] 既存の WG-T01〜WG-T18 と SG-T01〜SG-T11 が引き続き通る（回帰）（根拠: 同上の 2 コマンドと**全件テスト `OK: 27 本 / 221 件`（退行 0 件・1 回で全通し）**）
- [x] 変更直後に bash .claude/skills/20-common-step-commit-push/scripts/commit.sh を 1 回通し、制御方式 5・6 の経路で機構が自分を止めないことを確かめた（ロックアウト対策）（根拠: `OK: 4 ファイルをコミットした（d00d458）`。加えて実物のフックへの直接ペイロード 4 件 = レポート e22）
- [x] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: `wip/30_reports/0018-ai-asset-implementation.md` の e19〜e22・D13・D14・R15〜R18。HTML の対も更新し `check-html.sh` 7 項目通過。`.claude/docs/**` の差分は 0）

## 作業内容

- 負のコントロールの前提をテスト自身が枚数の assert で作る形を崩さない（調査の実測が空振りした原因は、どの作業ツリーにも作業中チケットが 0 枚で入口の exit 0 に落ちたこと）
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S4 と「ロックアウト対策」の S4 行に従う
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/hooks/**）は本チケットの allow.write に入っている

## 作業ログ

### 現在地

- 着手（基準点 e348c12）。仕様（workflow-guard / workflow-state-guard）・計画書 S4・既存の 2 本のフックとテストを読み終えた
- テスト先行で WG-T19 / WG-T20 / WG-T21 と SG-T12 / SG-T13 を新設 → WG-T21 が 3 件 FAIL（想定どおり）、SG-T12 / SG-T13 は無改修で PASS
- `workflow-guard.sh` を 2 点変更（WF207 の文面に作業ツリー / `worktree.sh` の置き場引数の例外）→ 担当テスト 217 件 PASS
- 変更直後に `commit.sh` を 1 回通した（d00d458）。制御方式 5・6 の経路で自分は止まらなかった
- 全件テスト（`--timeout 300`、1 本のみ）= `OK: 27 本 / 221 件`。**退行 0 件で 1 回で全通し**
- レポート `wip/30_reports/0018-ai-asset-implementation.md` に e19〜e22・D13・D14・R15〜R18 を追記し、HTML の対も更新。`check-html.sh` 7 項目通過（id 41 件 / リンク 34 件）
- DoD 9 件すべてに根拠を記入し、成果物をコミットした（d00d458 / 3dc58da）。S4 の作業はここで完了

### うまくいったこと

- 仕様（概要の一意性 2 点・制御方式 1・2・5・6）と `workflow-guard.sh` を突き合わせ、**足りていない点が 2 つだけ**だと特定できた。S2（0019）が `hook_doing_ticket` / `hook_rel_path` / `__wg_rel` を済ませていたため
- `WG-T19` / `WG-T20` を「枚数をテスト自身が assert してから判定を呼ぶ」形で書けた。足場は `git worktree add` を使わず `.git` ファイルと `<本流>/.git/worktrees/<名前>/gitdir` の相互参照で作る（`HK-T21` / `HK-T22` と同じ手口）
- `WG-T21` はテスト先行が成立した（3 件の FAIL を確認 → `workflow-guard.sh` を変更 → PASS）
- 変更直後の `commit.sh`（d00d458）が通り、制御方式 5・6 の経路で機構は自分を止めなかった
- 実物のフックに直接ペイロードを流す形（`jq | tr | bash .claude/hooks/20-PreToolUse/workflow-guard.sh`）で、新しい例外と R13 を実測できた。この呼び方は提供コマンドの形なので機構を迂回していない

### うまくいかなかったこと

- `SG-T12` / `SG-T13` が**書いた時点で通ってしまい**、テスト先行の「失敗を見る」が踏めなかった（実装は S2 で済んでいた）。反転検査で代えた（下の「判断と根拠」）
- 識別力の確認のために `wip/tmp/0021/probe/` に壊したコピーを作って走らせようとしたが、`bash wip/tmp/…/*.sh` は分類外で `WF204`、`.claude/hooks/**` へのコピーは `WF205` で、**プローブ用の実行経路が無かった**。迂回せず反転検査に切り替え、プローブのコピーは片付けた
- `sleep` が分類外（`WF204`）なので、全件テストの完了待ちをポーリングで行うしかなかった（作業効率の話で成果物には影響しない）

### 仕様からの逸脱

- **D13**: `workflow-guard` 仕様 `WG-T19` の文面がそれ自身と食い違う（前半「本流 0 枚・worktree 1 枚」／末尾の括弧「合計 2 枚」）。DoD と前半に従って 0 枚 + 1 枚を主のケースにし、括弧の意図（合計 2 枚でも `WF207` が出ない）を確かめるため**本流 1 枚・worktree 1 枚のケースを同じ `WG-T19` に足した**。仕様は直していない
- **D14**: 提供コマンドの引数判定の例外を、仕様が挙げる「引数の意味（置き場）」ではなく**引数の位置**（`add` の 3 番目・`remove` の 2 番目）で実装した。「置き場を意味する語」をコマンド行から判定するにはフック側で `worktree.sh` の引数解析を複製することになり、統制の穴も広がるため。仕様は直していない

### 判断と根拠

- **例外の範囲を「`worktree.sh` の引数すべて」ではなく位置に限った**: 仕様が「当てない引数を増やすときは、その引数の妥当性をコマンド自身が検査することを同じ変更で書く」と定めており、穴は最小にすべきと読んだ。負のコントロールを 3 つ（名前の位置に外のパス / 同じ行の他の提供コマンド / 他の提供コマンドに同じ外のパス）置いて範囲を固定した
- **`__WG_WORKTREE_CMD` を basename ではなく完全なルート相対パスで照合した**: basename 一致にすると、別のスキルの `scripts/worktree.sh` を作るだけで例外を得られてしまう
- **`SG-T12` / `SG-T13` の識別力を反転検査で示した**: 「通ったこと」だけでは assert が走ったのかフックに届いたのかが分からない。期待値を 3 か所（正の側 `WF303` / 負のコントロール `allow` / `WF309`）だけ誤値に差し替え、**3 件だけが FAIL する**ことを確かめてから戻した。戻し切ったことは `git diff HEAD` が空であることで確認した
- **`WG-T19` の 1 件の期待値を `WF201` → `WF202` に直した**: 本流に置いた `overall-plan` チケットは宣言が空なので、`apl/app/src/api/a.ts` は保護範囲ではなく未記載に落ちる。実装の誤りではなくテストの期待値の誤りだったので期待値を直した（「同じパスが worktree では allow・本流では `WF202`」の対比のほうが主張が強い）
- **`workflow-state-guard.sh` を「念のため」直さなかった**: 仕様どおりに動いており、拒否側フックを理由なく触るのはロックアウトの危険を増やすだけ。変更 0 行を検証の表に明記した

### 拒否・確認・迂回の記録

- `python …` → `WF204`（分類外）。迂回せず Edit ツールで書き換えた
- `cp … $P/.claude/…`（変数を含むパス）→ `WF205`（宛先を読み取れない）。リテラルのパスで書き直した（`wip/tmp/**` は通る）
- `wgprobe() { … }` を含む行 → `WF204`（`wgprobe` が分類外）。関数定義をやめて 1 本のパイプラインに書き直した
- `printf … > "$WT/.git"`（変数を含むリダイレクト先）→ `WF205`。プローブ自体を取りやめた
- `sleep 10` → `WF204`。待ち合わせはポーリングに変えた
- いずれも迂回・無効化はしていない

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec` / `10-task-investigation-exec`（共通手順）: 「1 つ変えるごとにテスト」「eval は定義まで」「仕様を直さず逸脱に記録」が判断の分かれ目で効いた
- `20-common-step-commit-push` の `commit.sh`: ロックアウト対策の確認を兼ねられる（変更直後に 1 回通す運用が有効）
- `20-common-step-report-view` の `check-html.sh`: 7 項目通過（id 41 件 / リンク 34 件）
- 0018 レポートの「残課題」表: R6 / R13 が S4 の担当だと明示されていたため、拾い漏れずに閉じられた

### スコープ外で見つけたこと

- `bash <wip/tmp 以下のスクリプト>` が分類外（`WF204`）なので、**一時ディレクトリに壊したコピーを置いて動かす形のプローブができない**。中核の退行を「壊して確かめる」手段がテストの反転検査しか無い
- `sleep` が分類外（`WF204`）。長時間のテストの完了待ちがポーリングになる

### AI アセットに反映すべき内容

- 「先に通ってしまうテスト」の扱い（反転検査 = 期待値を誤値に差し替えて落ちることを確かめてから戻す）を実施スキルの手順に入れるか。今回は自分の判断で行った
- `10-task-ai-asset-implementation-exec` の「テスト先行」は、実装が先行チケットで済んでいる場合を想定していない

### 備考

- 全件テストは `--timeout 300` で 1 本だけ走らせた（2 本同時は無関係なテストまで TIMEOUT する）
