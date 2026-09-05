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
started_at: "2026-09-06T00:20:20+09:00"
completed_at: "2026-09-06T01:33:29+09:00"
base_sha: "c152f9f"
---

# 0022 S5 中核 d: 案内側フック 4 本と post-push-* の共有ルート参照、A5 を閉じる機械テスト

## 目的

差分の基準点・対象チケットを採る作業ツリー・実行者照合・現在地の 4 つを作業ツリーごとに一意にし、受け入れ条件 A5 を機械テストで閉じる。あわせて post-push-* の進行状態の参照先を共有ルートへ移す。

## DoD

- [x] workflow-diff-check.sh が仕様書 10_spec/hooks/22-PostToolUse/workflow-diff-check.md 制御方式 0・1 のとおりになっている（差分の基準点は作業ツリーごとに一意 / 判定できないときは WF605 で通知）（根拠: 変更 0 行で既に仕様どおり（S2 で実装済み）。`git diff c152f9f -- .claude/hooks/22-PostToolUse/workflow-diff-check.sh` が空。DC-T08 / DC-T09 が PASS。レポート e23）
- [x] subagent-start-check.sh が仕様書 10_spec/hooks/12-SubagentStart/subagent-start-check.md「対象チケットを採る作業ツリー」の表のとおりになっている（代用しない。確定できないときは WF804 で要点を注入しない）（根拠: `__sa_worktree_ok` を新設し WF804 を注入（コミット a1c0e66）。SA-T10 / SA-T11 が PASS。レポート e24）
- [x] subagent-stop-check.sh が仕様書 10_spec/hooks/13-SubagentStop/subagent-stop-check.md 経路の表・制御方式 2 のとおりになっている（実行者照合は呼び出し元の作業ツリーのチケットで行い、確定できないときは WF815）（根拠: `__sp_worktree_ok` を新設し WF815 を出す（コミット 86c3b8a）。SP-T09 が PASS。レポート e25）
- [x] session-start.sh が仕様書 10_spec/hooks/00-SessionStart/session-start.md のとおりになっている（logs/mr.json が読めないとき現在地を断定せず WF705 で不明と根拠付きの推定を出す）（根拠: 制御方式 7（補助 A / B と WF705・推定行・スキルを断定しない案内）を実装し、進行状態を HOOK_SHARED_ROOT から読む（コミット 58be3f6）。SE-T11 の 4 状態が PASS。レポート e26）
- [x] post-push-compact-prompt.sh の logs/push-state.json と post-push-usage-report.sh の logs/usage/ が共有ルート（HOOK_SHARED_ROOT）を指している（フック共通仕様 §5 の根の列）（根拠: 計 5 か所を HOOK_SHARED_ROOT へ（コミット 58be3f6）。`grep -rn 'HOOK_WORKTREE/logs/' --include="*.sh" .claude/` の残りは 3 行（logs/hooks/ 2 行 + logs/sh/ 1 行。いずれも §5 で根はツリー）、`HOOK_SHARED_ROOT/logs/` は 22 行。ただし既存テストは根の違いを区別できない（レポート e27 / R21））
- [x] 機械テスト DC-T08 と DC-T09 が通る（run-tests.sh --filter '*test_workflow_diff_check*'）。DC-T09 は負のコントロールで、枚数をテスト自身が assert する（根拠: `passed=69 failures=0`。`dc_doing_count` で本流 1 枚・worktree 0 枚を assert してから判定を呼ぶ。書いた時点で通ったので反転検査で 3 件だけ FAIL を確認して戻した）
- [x] 機械テスト SA-T10・SA-T11 が通る（run-tests.sh --filter '*test_subagent_start_check*'）（根拠: `passed=86 failures=0`。SA-T11 は実装前に 3 件 FAIL（本流のチケットの要点が注入された）を確認済み）
- [x] 機械テスト SP-T05・SP-T08・SP-T09 が通る（run-tests.sh --filter '*test_subagent_stop_check*'）。SP-T09 が A5 の実行者照合を閉じる（根拠: `passed=82 failures=0`。SP-T09 は実装前に WF815 の 5 件 FAIL を確認済み。SP-T05 に縮退の前提 2 件（settings.json の登録 0 件 / 印の有無）を追記）
- [x] 機械テスト SE-T11 が通る（run-tests.sh --filter '*test_session_start*'）。4 つの状態を同じ作業領域で切り替えて固定する（根拠: `passed=68 failures=0`。実装前に 12 件 FAIL を確認済み。(a) feature + overall-plan 完了 (b) detached HEAD (c) main + 完了なし (d) mr.json 破損 の 4 状態）
- [x] post-push-* の既存テストが通る（run-tests.sh --filter '*test_post_push*'）（根拠: `OK: 2 本 / 15 件`（passed=36 / passed=38、failures=0））
- [x] 変更直後に Write を 1 回行い、logs/hooks/decisions.jsonl に WF605 の誤爆が無いことを確かめた（ロックアウト対策）（根拠: `grep -c '"id":"WF605"' logs/hooks/decisions.jsonl` = 0 件。`grep -c '"hook":"workflow-diff-check"'` = 239 行で PostToolUse は回っている。commit.sh 4 回・Edit / Write もすべて通った。レポート e28）
- [x] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: `wip/30_reports/0018-ai-asset-implementation.md` の e23〜e28 と D15〜D18。HTML の対も更新し `check-html.sh` が「OK: 検査 7 項目すべて通過」。`.claude/docs/**` は 1 文字も変更していない）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S5 と「ロックアウト対策」の S5 行に従う
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/hooks/**）は本チケットの allow.write に入っている

## 作業ログ

### 現在地

- 2026-09-06 着手（基準点 c152f9f）。仕様 4 本（workflow-diff-check / subagent-start-check / subagent-stop-check / session-start）とフック共通仕様 §5 を読み、変更点を洗い出した
- 洗い出した変更: ①workflow-diff-check は制御方式 0・1 が S2 で実装済み（コード変更なし・テストのみ）②subagent-start-check に WF804 を足す ③subagent-stop-check に WF815 を足す ④session-start を共有ルート参照 + 制御方式 7（WF705）に直す ⑤post-push-* の push-state.json / usage/ / mr.json を共有ルートへ
- ①完了（コミット d04f763）: DC-T08 / DC-T09 を新設。実物の作業ツリー（テスト内の `git worktree add`）とネイティブ表記のパスが要った。反転検査で識別力を確認
- ②完了（コミット a1c0e66）: `__sa_worktree_ok` と WF804。SA-T11 は先に 3 件 FAIL を確認。SA-T10 は反転検査
- ③完了（コミット 86c3b8a）: `__sp_worktree_ok` と WF815。SP-T09 は先に 5 件 FAIL を確認。SP-T05 に縮退の前提 2 件を追記。SP-T09 の実行者照合部分は反転検査
- ④⑤完了（コミット 58be3f6）: session-start の制御方式 7 と共有ルート参照、post-push-* 5 か所の共有ルート化。SE-T11 は先に 12 件 FAIL を確認。SE-T03 の前提を default ブランチへ移した
- レポート追記完了（コミット 722323b）: md に e23〜e28・D15〜D18・R19〜R23、HTML の対も更新して `check-html.sh` が「OK: 検査 7 項目すべて通過」
- ロックアウト対策の確認完了: `"id":"WF605"` は 0 件、`workflow-diff-check` の記録は 239 行。commit.sh は 4 回とも成功
- 全件テスト完了: `run-tests.sh --ids --timeout 300` が **`OK: 27 本 / 227 件`**（全 PASS / `FAIL ID:` 空 / 重複 ID なし）。221 → 227 は S5 の新設 6 ID の分。**他のフックの退行 0 件**（1 回で通った）
- 全件テストの結果をレポート md / HTML に反映し、`check-html.sh` を再度通した（OK: 検査 7 項目すべて通過）。あわせて e28 の「239 行あるから回っている」という記述が根拠として弱いことに気づき、正直な書き方（記録は伝えることがあるときだけ残るので回っていることの証拠にならない／根拠は機械テスト側）に直した
- 残り: この作業ログとレポートの最終差分をコミットしてチケットを完了する

### うまくいったこと

- テスト先行が 3 件（SA-T11 = 3 件 FAIL / SP-T09 = 5 件 FAIL / SE-T11 = 12 件 FAIL）で踏めた。とくに SA-T11 の実装前の FAIL は「本流のチケットの要点が注入される」という**代用そのもの**を出力として見せてくれたので、直すべき挙動が具体的に分かった
- 0021 の「枚数をテスト自身が assert してから判定を呼ぶ」形はそのまま 4 本に流用できた。`dc_doing_count` / `sa_doing_count` / `sp_doing_count` は同じ実装
- 書いた時点で通ってしまった 4 件（DC-T08 / DC-T09 / SA-T10 / SP-T09 の前半）は 0021 の反転検査で代えられた。3 回とも「差し替えた件数だけが FAIL」し、戻した後の `git diff HEAD` にテストファイルの差分が無いことも確認できた

### うまくいかなかったこと

- `workflow-diff-check` のテストで、最初は 0021 と同じ疑似の作業ツリー（`.git` ファイルと `gitdir` の相互参照）を作ろうとしたが、このフックは `git status` / `git diff` を実際に走らせるので制御方式 7 で黙って抜けてしまう。実物（`git worktree add`）に切り替えた
- さらにパス表記でもう 1 回落ちた。`hook_payload` の `$PWD`（`/tmp/…`）と `git worktree add` が書くネイティブの絶対パス（`C:/Users/…`）が照合できず、**worktree に居るのに本流のチケットで判定された**（`基準点は 97917c3`）。`pwd -W` でネイティブ表記に揃え、`cwd` を入力 JSON に明示で載せて解決
- `assert_not_contains "WF801"` が WF815 の文面（「実行者照合（WF801）と…」）に当たって落ちた。SP-T07 の WF814 と同じ罠で、識別子ではなく判定の文面で見る形に直した
- SubagentStop が WF815 を `subagent-<agentId>.json` に記録するため、同じ `agentId` の PostToolUse が読み戻して復旧後の対照が壊れた。別の `agentId` で流す形に直した

### 仕様からの逸脱

- D15: `subagent-start-check.sh` に PreToolUse `Agent` の経路（WF801 / WF803 と経路の印）を**残した**。`subagent-start-check` 仕様は「WF802 だけを担う」と書きテスト観点から SA-T02 / SA-T07 / SA-T09 を落としているが、`subagent-stop-check` 仕様の縮退判定はその印の存在を前提にしている。2 つの仕様が食い違うので消さずに残し、記録した（登録は既に無いので死んだ経路）
- D16: WF804 / WF815 は「作業ツリーの集合を読めない」ときにも出す実装にしたため、`cwd` が本流でも通知が出る。仕様は「確定できない」としか書いていないので安全側に倒した
- D17: 実装計画書「参照更新一覧」#1 の期待値（`logs/hooks/` の 2 行だけが残る）は `logs/sh/` を見落としている。実際は 3 行。§5 では `logs/sh/` の根はツリーなので実装が正しい
- D18: 仕様 SA-T11 の「`.git/worktrees/` を退避する」だけでは `hook_worktrees` が「集合が空」として 0 を返し、読めない状態にならない。退避 + 同名ファイルの設置（HK-T22 と同じ作り）で作った
- **`.claude/docs/**` は 1 文字も変更していない**

### 判断と根拠

- **`workflow-diff-check.sh` を変更しなかった**: 仕様 制御方式 0・1 は S2（0019）で実装済みで、判定材料はすべて `$HOOK_WORKTREE` から取っている。無理に手を入れず、テストで固定する側に倒した（0021 の `workflow-state-guard.sh` と同じ扱い）
- **テストの中で `git worktree add` を呼んだ**: 起動プロンプトと機構が禁じているのは**私が Bash で `git worktree add` を実行すること**（作業リポジトリに作業ツリーを作ること）で、テストスクリプトが一時リポジトリに対して呼ぶのは fixture の作成である。作業リポジトリには一切触れていない。ただし 0021 の形（疑似の作業ツリー）から外れる判断なので、レポートの「見てほしい点」に挙げた
- **「集合を読めない」を確定できない側に含めた**: `HOOK_WORKTREE_STATE` だけを見ると集合が読めないケースを取りこぼし、`HOOK_WORKTREE` が本流に倒れたまま**代用**してしまう（実装前の SA-T11 がそれを示した）。仕様は両方を「確定できない」に挙げているので、`hook_worktrees` の戻り値も見る
- **`SE-T03` の前提を default ブランチへ移した**: 新しい制御方式 7 では feature ブランチ + mr.json 不在は WF705 になるのが正しい。期待値は変えず前提だけ動かした
- **`post-push-*` のテストを新設しなかった**: DoD は「既存テストが通ること」までで、作業ツリーの足場を両テストに足すのは S5 の範囲を越えると判断した。テストが根の違いを区別できないことは R21 として残した

### 拒否・確認・迂回の記録

- `cd /c/Users/...` が **WF204** で拒否された（1 回）。ルート相対表記に直して迂回せず進めた
- `sed -i` によるテストファイルのヘッダ書き換えが **WF205** で拒否された（1 回）。Edit ツールに切り替えた
- 機構を無効化する操作・迂回は行っていない。`git checkout` / `git worktree add` / `git switch` を Bash で実行していない

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec` → `10-task-investigation-exec`（共通手順）: 1 枚ずつ着手・レポート積み上げ・完了前の検査の順序がそのまま使えた
- `20-common-step-commit-push` の `commit.sh`: 4 回とも対象を明示したコミットが通り、除外は 0 件
- `20-common-step-report-view` の `check-html.sh`: md と HTML の対を更新した後 1 回で通過（id 47 件 / リンク 40 件）
- 実装計画書 `0016` の「ロックアウト対策」S5 行: 確かめる操作（Write 1 回 + WF605 の誤爆）と復旧手順（`git show` → Write）が具体的で、迷わずに済んだ

### スコープ外で見つけたこと

- `subagent-start-check` 仕様と `subagent-stop-check` 仕様が、PreToolUse `Agent` の経路の存在について食い違っている（D15）。どちらも 0012〜0017 の設計フェーズの成果物なので、設計反映で揃える必要がある
- 実装計画書「参照更新一覧」#1 の期待値が `logs/sh/` を見落としている（D17）。S9（0026）が同じ検索で消し込むので、そのときに期待値を 3 行へ直す必要がある

### AI アセットに反映すべき内容

- **「疑似の作業ツリーで足りるか」はフックが git を呼ぶかで決まる**。`20-common-step-shell-script` か各フックのテストの雛形に、この判断基準（git を呼ぶフックは `git worktree add` で実物を作り、パスをネイティブ表記に揃える）を残せると、S6 以降と将来の作業ツリー関連のテストで同じ 2 段の躓きを避けられる
- **通知の文面が他の識別子に言及するとき、識別子で assert できない**（WF814 / WF815 の 2 例目）。テストの書き方として「識別子ではなく判定の文面で見る」を共通ステップに書いておくとよい

### 備考

- 全件テストは `--timeout 300` で 1 本だけ走らせた（申し送りの「2 本同時に走らせると無関係なテストまで TIMEOUT する」に従った）
