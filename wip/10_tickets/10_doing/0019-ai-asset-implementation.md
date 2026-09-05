---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0018"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: ["wip/**", ".claude/hooks/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-05T19:40:46+09:00"
completed_at: ""
base_sha: "9059a0f"
---

# 0019 S2 中核 a: hook-common.sh の作業ツリーの三分・集合・畳み込み・共有ルート

## 目的

フック共通仕様 §2 の作業ツリーの三分（HOOK_ROOT / HOOK_WORKTREE / HOOK_SHARED_ROOT）・同一リポジトリの作業ツリーの集合・作業ツリーをまたぐパスの畳み込みと「判定できないときの倒し方」を hook-common.sh に実装し、値の往復になる呼び手 3 本の分岐（WF209 / WF309 / WF605）を同じチケットで揃える。

## DoD

- [x] hook-common.sh が仕様書 フック共通仕様 §2「作業ツリーの三分」のとおりになっている（HOOK_SHARED_ROOT の値は HOOK_ROOT と同一に固定し、環境変数・設定ファイルからの上書きの口を作らない）（根拠: `hook-common.sh` の宣言部と `__hc_resolve_worktree` 冒頭の 2 か所で無条件代入。`HK-T21` が `HOOK_SHARED_ROOT=$TMP_REPO/evil-shared` を置いても `HOOK_ROOT` に戻ることを assert して PASS。レポート e5）
- [x] hook_worktrees が <HOOK_ROOT>/.git/worktrees/*/gitdir から集合を作り、git を呼ばない（glob と組み込みの読み込みだけ。stale な登録も集合に残す）（根拠: `hook_worktrees`（glob + `$(<file)` のみ。`git` の呼び出しなし）。`HK-T22` が集合を読めない場合と集合が空の場合を別々に assert して PASS。レポート e6）
- [x] hook_rel_path が仕様書 §2「作業ツリーをまたぐパスの畳み込み」の 4 段（自ツリー → 共有ルート → 集合のいずれか → 畳めない）で判定し、正規化失敗と集合を読めないときは 4 に倒さず「判定できない」を返す（根拠: `hook_rel_path`（`REPLY_KIND` = worktree / shared / other / outside / unknown、戻り 0 / 1 / 2）。`HK-T22` PASS。レポート e7）
- [x] 呼び手 3 本が「判定できない」の規約どおりに分岐する: workflow-guard は WF209、workflow-state-guard は WF309（いずれも deny 側）、workflow-diff-check は WF605（案内側なので additionalContext）（根拠: `__wg_rel` / `__sg_rel` / `workflow-diff-check` 制御方式 0 と承認の記憶の走査。`test_workflow_guard` 183 / `test_workflow_state_guard` 87 / `test_workflow_diff_check` 48 いずれも failures=0。レポート e9）
- [x] logs/ の置き場が仕様書 §5 の根の列のとおりになっている（判定記録 decisions.jsonl と実行ログ logs/sh/ は作業ツリー側、進行状態・ロック・集計は共有ルート）（根拠: `hook_record` / `__hc_relog` はツリー側、`hook_read_state` / `hc_lock` / `hook_session_dir` は共有ルート。`HK-T21` が 5 か所すべてを assert して PASS。レポート e8）
- [x] 機械テスト HK-T06・HK-T21・HK-T22 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_hook_common*'）（根拠: `PASS / exit 0 / passed=238 failures=0`。`--ids` の PASS ID 一覧に `HK-T06` `HK-T21` `HK-T22` を含む）
- [x] hook-common.sh を読み込む全フックのテストが通る（run-tests.sh --filter '*hooks*'）（根拠: `--filter '*hooks*' --timeout 300 --ids` で `OK: 17 本 / 128 件`、全 17 本 PASS、`FAIL ID:` 空、重複 ID なし。既定 120 秒では `test_workflow_guard.sh` が TIMEOUT する（9/4 時点で 124 秒の既知の遅さ）ためレポート e10 の理由で `--timeout 300` を使った）
- [x] 変更直後に wip/tmp/ への Write を 1 回・Read を 1 回行い、機構が自分を止めないことを確かめた（ロックアウト対策）（根拠: `wip/tmp/0019-lockout-check.txt` への Write と Read が成功。`decisions.jsonl` に `workflow-guard allow / 判定 5 / 種類 ai-asset-implementation` が 1 行、`agent_id` と `cwd` 付き）
- [x] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: `wip/30_reports/0018-ai-asset-implementation.md` の e5〜e11 と D6・D7。HTML も f5〜f11 で同期し `check-html.sh` 7 項目通過。`.claude/docs/**` は 1 文字も変更していない）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S2 に従う
- hook_rel_path は書く側と読む側が往復する値なので、呼び手 3 本の分岐まで同じチケットで閉じる
- 復旧は git checkout を使わない（checkout は _SC_GIT_READ_SUBCMDS に無く unknown → WF204）。git show <base_sha>:<パス> で内容を取り、Write ツールで書き戻す。書き戻し先（.claude/hooks/**）は本チケットの allow.write に入っている

## 作業ログ

### 現在地

- 着手。仕様（フック共通仕様 §2・§5）と現状の `hook-common.sh` を読み終えた。
- `hook-common.sh` の①〜④（`HOOK_SHARED_ROOT` / `hook_worktrees` / `hook_rel_path` の 4 段 / `decisions.jsonl` の `cwd`・`agent_id`）と、`test_hook_common.sh` の HK-T06 追記・HK-T21・HK-T22 を実装済み。`run-tests.sh --filter '*test_hook_common*'` は PASS（passed=235 failures=0）。
- `--filter '*hooks*'` の全通しで `SG-T11`（`rm -rf .` が WF302 → WF309 に化ける）の退行を検出し、`hook_rel_path` の「点だけの相対パス」の扱いを直した。あわせて正規化済みの根をキャッシュする `__hc_roots_n` を入れた（§1 のホットパス）。`test_hook_common` 238 / `test_workflow_state_guard` 87 / `test_workflow_guard` 183 いずれも failures=0。
- 呼び手 3 本の分岐（WF209 / WF309 / WF605）を入れ、`--filter '*hooks*' --timeout 300 --ids` で `OK: 17 本 / 128 件`（全 PASS / FAIL 0 / 重複 ID なし）。
- レポート `wip/30_reports/0018-ai-asset-implementation.md` に e5〜e11 を追記し、HTML も f5〜f11 で同期して `check-html.sh` 7 項目通過。
- **完了**。次は 0020（S3: `scope.sh` / `cmdpos.sh`）だが、本チケットでは着手しない。

### うまくいったこと

- **テスト先行が退行を拾った**。`HK-T21` / `HK-T22` を先に書いて失敗を確認してから実装し、さらに `--filter '*hooks*'` の全通しで既存の `SG-T11` が `rm -rf .` の退行（`WF302` → `WF309`）を落とした。中核 1 本の変更でも、変更したテストだけでなく**全フックのテストを回す**価値が実測で出た。
- **「1 つ変えるごとに確かめる」を守れた**。`hook-common.sh` → 呼び手 3 本の順に分け、各段で `bash -n` と該当テストを回した。呼び手を先に変えていたら、どちらの変更で落ちたのか切り分けられなかった。
- 復旧手順（`git show <base_sha>:<パス>` → Write）は**使わずに済んだ**。

### うまくいかなかったこと

- **中核を壊した状態で 2 回 `Edit` してしまった**（`__hc_roots_n` を呼ぶ側だけ先に入れた）。関数の追加は「定義 → 呼び出し」の順にすべきだった。結果としてフックの内部エラーが 2 回起き、`decisions.jsonl` に `WF209` / `WF309` の deny が 4 行残った。
- `run-tests.sh` の既定 120 秒では `test_workflow_guard.sh` が TIMEOUT し、全通しの 1 回目は 3 本が TIMEOUT・1 本が FAIL という読みにくい結果になった。9/4 の全通しが `--timeout 300` を使っていたことに最初から気付いていれば 1 回で済んだ。

### 仕様からの逸脱

- **D6**: `workflow-diff-check` の `WF605` を、仕様の制御方式 0（停止中の判定より前）ではなく**制御方式 1 の後**に置いた。共通仕様 §3「停止中のフックは判定・注入を行わない」と両立させるため。`workflow-state-guard` 仕様は同じ状況に「0 は 1 の後に評価する」と明記しており、そちらに揃えた。設計文書は直していない。
- **D7**: `hook_read_state` が共通仕様 §1 の 1 回目の jq ではなく 2 回目にある逸脱を維持した。三分の導入で理由が「作業ツリーの解決が cwd の後」から「共有ルートの解決が cwd の後」に変わったので、コメントだけ読み替えた。
- 詳細はレポートの「仕様からの逸脱」表（D6・D7）。

### 判断と根拠

- **`__hc_roots_n`（正規化済みの根のキャッシュ）を入れた**。仕様の要求ではなく、`hook_rel_path` が書き込み対象の数だけ呼ばれるホットパス（§1）だから。一時計測で 1 回 1.5〜2.2 ms と分かったので影響は小さいが、根の正規化を毎回やり直す形は残す理由が無い。代償として「`HOOK_WORKTREE` を `__hc_resolve_worktree` の外で代入するとキャッシュが古くなる」制約が増えたのでコメントに明記した。レポートの ◇判断が欲しい に挙げて人間に委ねる。
- **`workflow-state-guard` の実在検査の根を `REPLY_ROOT` に変えた**。畳み込みの 4 段化を入れた結果、他ツリーの `10_doing/` の**既存**チケットの更新まで `WF302` になる（自ツリーに同名が無いため）。仕様 `SG-T12` が要求する振る舞いを満たすための修正だが、テストは S4 の割り付けなので、範囲を越えていないかをレポートで確認する。
- **呼び手の分岐に専用テストを新設しなかった**。計画書が `SG-T13` を S4、`WF605` を S5 に割り付けており、S2 の「依存するテスト」は既存 3 本が通り続けることだけを求めているため。勝手に S4 / S5 のテスト ID を先取りしない側に倒し、配分の是非はレポートで確認する。
- **全フックの確認に `--timeout 300` を使った**。9/4 の全通しと同じ条件で、`run-tests.sh` が提供する正規の引数。テストを飛ばす操作ではない。
- **`test_workflow_guard.sh` の遅さを S2 の退行と断定しなかった**。同日に変更していないテスト（`test_block_chmod` 等）も 9/4 比で 1.6〜1.8 倍に伸びており、機械の負荷（並行して別の `run-tests` が走っていたことをログで確認）で説明がつくため。

### 拒否・確認・迂回の記録

- `cd` が `WF204` で拒否された（分類外）。迂回せず、以後すべて絶対パスまたはリポジトリルートからの相対パスで実行した。
- `bash <リポジトリルートからの絶対パス>/run-tests.sh` が `WF204`。提供コマンドの照合はリポジトリルート相対の形で行われるため。相対パスに直して実行した（迂回ではなく正しい呼び方に直した）。
- `jobs` が `WF204`。バックグラウンドの進捗確認は `logs/sh/run-tests.log` の読み取りに切り替えた。
- 中核を壊した状態での `Edit` 2 回が `WF209` / `WF309` として `decisions.jsonl` に記録された。**ただしツールは止まらなかった**（レポート e11）。迂回はしていない（そもそも拒否が届いていない）。
- `.claude/docs/**`・`.claude/hooks/config/**`・`.claude/settings.json` には 1 度も触れていない。

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec`（と正の `10-task-investigation-exec`）: 「中核は 1 つ変えるごとにテストと自分の動作で確認」「復旧は基準点への戻し」「逸脱は仕様を直さず記録」が、そのまま今回の進め方になった。効いた。
- `20-common-step-shell-script` の `run-tests.sh`: `--filter` / `--ids` / `--timeout` の 3 つで足りた。`--ids` の重複 ID 検査が、新設した `HK-T21` / `HK-T22` の ID の衝突が無いことをそのまま示してくれた。
- `20-common-step-report-view` の `check-html.sh`: 7 項目通過。f5〜f11 を足した後の id 重複・破断リンクを 1 回で確認できた。
- 実装計画書 `wip/20_plans/0016-ai-asset-implementation-plan.md` の S2 の 5 項目（①〜⑤）が、そのまま DoD とレポートの節割りになった。ロックアウト対策の欄（`git show` → Write）も具体的で、迷わずに済んだ。

### スコープ外で見つけたこと

- **fail-closed の deny が実際の遮断につながらない経路がある**（レポート e11 / R8）。仕様 §3 は打ち切り（timeout）を「フェイルクローズドの原則の唯一の穴」と書いているが、今回の事象は打ち切りではない。原因は特定できていない。
- `test_workflow_guard.sh` が `run-tests.sh` の既定 120 秒に収まらない（9/4 時点で 124 秒）。全通しに `--timeout 300` が要る（R9）。
- この環境に `shellcheck` が入っていない。`20-common-step-shell-script` は `bash -n` と `shellcheck` の 2 つを検査に挙げているが、後者を実施できない（R10）。
- 並行して別セッションの `run-tests` が走ると双方が TIMEOUT する（`logs/sh/run-tests.log` に 2 つの pid が交互に現れる）。

### AI アセットに反映すべき内容

- `20-common-step-shell-script`（または `run-tests.sh` の使い方）に「**全通しは `--timeout 300`**」を書く。既定の 120 秒では `test_workflow_guard.sh` が確実に TIMEOUT し、毎回「退行か遅さか」の切り分けから始めることになる。
- `10-task-ai-asset-implementation-exec` の「中核は小さく」に、**関数を足すときは定義 → 呼び出しの順**という具体を 1 行足す。今回の 2 回の内部エラーはこの順序だけで避けられた。
- `check-html.sh` は通ったが、md と HTML の節の対応（`e*` と `f*` の 1 対 1）は人間の目視に依存している。積み上げ型レポートでは節が増え続けるので、対応の検査を機械化する余地がある。

### 備考

- 基準点 `9059a0f` からの差分は `.claude/hooks/**` 5 ファイル + `wip/**`（チケット 1 枚・レポート md / HTML）で、`allow.write`（`wip/**`, `.claude/hooks/**`）の内側。範囲外の差分・未追跡ファイルは無い。
- `wip/tmp/0019-lockout-check.txt` はロックアウト確認用の一時ファイル（`wip/tmp/` は追跡対象外）。
