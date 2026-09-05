---
type: ticket
ticket_type: ai-asset-implementation
predecessors: []
executor: opus
human_review: {required: false, reason: "全体計画の差分 3 により人間レビューは行わない"}
adversarial_review: {required: false, reason: "実装フェーズの敵対的レビューは上限 1 回に達している"}
allow:
  write: ["wip/**", ".claude/hooks/**", ".claude/skills/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-06T06:18:22+09:00"
completed_at: ""
base_sha: "df90f04"
---

# 0030 実装の穴 7 件を塞ぐ（敵対的レビュー）: 畳み込みの最長一致・分類の残り穴・切れ目の既出判定

## 目的

実装フェーズの敵対的レビューで裏取りされた 7 件を実装に反映する。最重要は、入れ子の作業ツリーが保護から外れることと、相互参照を確かめられないときに本流へ倒れて統制が素通りすること。

## DoD

- [x] 指摘 1: hook_rel_path の畳み込みを最長一致に直し、リポジトリ配下の作業ツリーが自ツリーとして判定されることを機械テストで固定した（根拠: レポート e55。`hook-common.sh` の `hook_rel_path` を最長一致に。`HK-T22` に `<root>/sub-wt` と `<root>/.claude/worktrees/nw` の足場と 8 assert、`SG-T12` に 7 assert。実装前 FAIL 5 → `test_hook_common.sh` `passed=252 failures=0` / `test_workflow_state_guard.sh` `passed=116 failures=0`）
- [x] 指摘 2: 相互参照を確かめられないときに本流へ倒さず判定できない扱いにし、拒否側フックが止めることを負のコントロール込みで固定した（根拠: レポート e56。`__hc_is_worktree_of` を 3 値化し `HOOK_WORKTREE_STATE=unknown`、`workflow-guard` に `WF209` を追加。`WG-T20` に「相互参照を壊すと `WF209`・読み取りは allow・戻せば allow」の 5 assert。実装前 FAIL 2 → `test_workflow_guard.sh` `passed=222 failures=0`。**`HK-T22` の既存の期待値 1 件を差し替え**、理由を e56 に記録）
- [x] 指摘 3: git branch の位置引数によるブランチ作成が unknown になることを機械テストで固定した（根拠: レポート e57。`scope.sh` の限定適用 2 に位置引数の検査と `_SC_GIT_BRANCH_VALUE_OPTS`。`HK-T15` に 13 対（作成形 5 = unknown / 一覧形 8 = read）。実装前 FAIL 5 → `test_scope.sh` `passed=412 failures=0`）
- [x] 指摘 4: 切れ目の既出判定にブランチ名を併記し、MR が分からないときは全件ではなく 0 件に倒した。MR 不在から出現への遷移を機械テストで固定した（根拠: レポート e58。`write_review` に `branch`、`load_covered` を「mr 一致 または 両方 null かつ branch 一致」に。`BD-T20` に 4 ケース（null 行 → mr.json 出現・別ブランチ・mr.json 不在）。実装前 FAIL 3 → `test_boundary.sh` `passed=147 failures=0`）
- [x] 指摘 5: 実装結果レポートの e52 と e53 を、観測が未コミットの場合に限ることと隔離の置き場がリポジトリ配下である点を含む形に直した（根拠: レポート e61 の C24〜C26。e52・e53・e54 の末尾に「【0030 の訂正】」の引用ブロックを 3 つ追加し、e54 に項目 7（置き場がリポジトリ配下）を足した。**過去の節の本文の差分は 0 行**）
- [x] 指摘 6: 合流の記録の上限判定をバイト長に直した（根拠: レポート e59。`worktree.sh` に `bytelen`（`LC_ALL=C`）を置き `record_merge` の判定を差し替え。`WT-T06` に UTF-8 ロケール + `core.quotePath=false` で日本語のパス 40 本の衝突を作るケース。実装前は文字数 2569 / バイト数 5289 で切り詰めが起きず → 実装後は 4 KB 未満で末尾が `…`。**残課題 R28 を閉じた**）
- [x] 指摘 7: worktree.sh の置き場の照合を git 目線の綴りに揃えた（根拠: レポート e60。`native_path` を新設し `canon_worktree_path` の非存在パスの枝と `cmd_add` の `dest` に適用。`WT-T02` に相対パスの (d')。実装前は `WT007` に落ちていた → 実装後は `WT002`。`test_worktree.sh` `passed=169 failures=0`）
- [x] 全件テストが FAIL 0 で通り、md と HTML の対が保たれ check-html.sh を通る（根拠: レポート「検証の結果」0030 分。`run-tests.sh --ids --timeout 300` = `OK: 28 本 / 243 件`・FAIL 0・重複 ID なし。`check-html.sh` 7 項目 OK）

## 作業内容

- MR のコメント（敵対的レビューの指摘 7 件）を読む
- 指摘 1 と 2 を先に直す。統制が素通りする経路なので最優先
- 指摘 5 はレポートの訂正であり、実装の変更を伴わない

## 作業ログ

### 現在地

- 指摘 7 件すべて反映済み。全件テスト `OK: 28 本 / 243 件`（FAIL 0・重複 ID なし・所要 27 分 13 秒）、`check-html.sh` 7 項目 OK。レポート md / HTML の追記も完了。あとはコミットして完了するだけ

### 実施したこと（順に）

1. 指摘 1: `hook_rel_path` を最長一致に（`HK-T22` / `SG-T12` 先行 5 件 FAIL → PASS。`SG-T12` は反転検査）
2. 指摘 2: `__hc_is_worktree_of` を 3 値化し `HOOK_WORKTREE_STATE=unknown`、`workflow-guard` に `WF209`（`HK-T22` 2 件・`WG-T20` 2 件 FAIL → PASS）
3. 指摘 3: `scope.sh` の `git branch` 位置引数（`HK-T15` 5 件 FAIL → PASS）
4. 指摘 4: `boundary.sh` の `covered` と `branch` 記録（`BD-T20` 3 件 FAIL → PASS）
5. 指摘 6・7: `worktree.sh` の `bytelen` / `native_path`（`WT-T02` / `WT-T06` 3 件 FAIL → PASS）
6. 指摘 5: レポート e52・e53・e54 に訂正の引用ブロック（本文は書き換えず）

### うまくいったこと

- **テスト先行が 6 件中 6 件で成立した**。指摘 1・2・3・4・6・7 はいずれも実装前に FAIL（合計 22 件）を確認してから直した。後から書いた `SG-T12` の 5 件だけが「書いた時点で通る」形だったので、`hook_rel_path` の最長一致を一時的に最初の一致へ戻す**反転検査**で識別力を測り、戻し切りを確認した
- **指摘 1 と 2 を先に直したのが正解だった**。指摘 2 の修正（`HOOK_WORKTREE_STATE=unknown`）は `HK-T22` の既存の期待値と衝突したが、指摘 1 のテストを先に足していたおかげで「どの assert がどちらの指摘に対応するか」を切り分けられた
- **中核を 1 つずつ変えて毎回テストを回した**（`hook-common.sh` → テスト → `scope.sh` → テスト → `workflow-guard.sh` → テスト）。ロックアウトは 1 度も起きず、変更のたびに `Edit`・テスト実行・`commit.sh` が通ることを確かめた

### うまくいかなかったこと

- **指摘 6 の不具合が最初は再現しなかった**。この環境は C ロケールで `${#x}` がバイト数を返し、git も既定で非 ASCII を 8 進エスケープするため、日本語のパスを 40 本並べても文字数とバイト数が一致してしまった（`DIAG bytes=3996 chars=3996`）。テストを `env LC_ALL=C.UTF-8` で走らせ、`git config core.quotePath false` を足して初めて食い違い（2569 / 5289）を作れた
- **ロケールの確認に使おうとした `wip/tmp/locale-check.sh` を実行できなかった**（`bash wip/tmp/*.sh` が `WF204`。R51 の再現）。迂回せず、テスト本体に一時的な `printf` を足して確認し、確認後に消した

### 仕様からの逸脱

- **D27**: 畳み込みの候補を §2 の「順」ではなく**最長一致**で選んだ（そうしないと §2 自身の「1〜3 のどれかに畳めたパスはそのツリーとして判定に掛ける」が根の配下の作業ツリーで成り立たない）
- **D28**: 集合を読めないとき、自ツリー・共有ルートで畳めたパスは「判定できない」に倒さない（全部を deny にすると `.git/worktrees` が壊れた環境で機構自身が止まって復旧できない）
- **D29**: `git branch` の「値を取るオプション」を 9 件の**列挙**で持った（仕様は位置引数にも値を取るオプションにも触れていない）
- **D30**: 切れ目の記録に `branch` を足した（`logs/review-state.json` のスキーマに無い。`merge-state.json` が既に持つ形に揃えた）

### 判断と根拠

- **`HK-T22` の既存の期待値を 1 件変えた**。「相互参照を辿れないので本流に倒れる」はフック共通仕様 §2 の「判定できないときの倒し方」（拒否側は許可側に倒さない）と矛盾しており、**テストが誤った振る舞いを固定していた**側だと判断した。変えた理由をレポート e56 と「見てほしい点」に明記した
- **`workflow-guard` の deny を「作業中チケットを数える前」に置いた**。数えた後だと本流 0 枚で `exit 0` してしまい、指摘 2 の穴（静かな無効化）がそのまま残る。読み取り・起動・宣言は通す形にして、ロックアウトの幅を最小にした
- **集合が読めないときの倒し方**（D28）は、統制の厳密さよりロックアウトの回避を採った。厳密側（全部 unknown）に倒すと `.git/worktrees` が壊れた瞬間に全操作が deny になり、フックを直す操作すらできなくなる
- **`abs_path` に `/c/` → `C:/` の変換を入れる案を採らなかった**（指摘 7）。この環境の一時リポジトリは `/tmp/tmp.XXXX`（MSYS のマウント）で、ドライブレターの規則では解けない。存在する最深の祖先を辿る `native_path` にした
- **`git branch` の値を取るオプションを列挙にした**。git のオプション一覧を機械的に取る手段（`--git-completion-helper`）は環境依存が大きいので採らず、漏れが安全側（`read` → `unknown`）に落ちることを確かめて列挙で閉じた。残課題 R52-b に上げた
- **指摘 5 の訂正は 0009 / 0011 の形に倣った**。過去の節の本文を 1 文字も変えず、節の末尾に `> **【0030 の訂正】…**` の引用ブロックを足し、訂正の一覧を e61 の表（C24〜C26）に集約した

### 拒否・確認・迂回の記録

- `cd` を含むコマンド（`cd <repo> && grep …`）が **`WF204`** で拒否された。迂回せず、リポジトリルート相対のパスで `grep` し直した
- `bash -c '…'` が **`WF209`**（文字列をコードとして受け取る実行系）で拒否された。迂回せず、確認内容をテスト本体の一時的な `printf` に置き換えた
- `bash wip/tmp/locale-check.sh` が **`WF204`** で拒否された（R51）。迂回せず、ファイルを削除した
- **機構の無効化・強制解除は 1 度も行っていない**。`WORKFLOW_ENTRY_ENFORCE` / `WORKFLOW_ENFORCE` に触れていない

### 使った AI アセットと効き目

- `10-task-ai-asset-implementation-exec` / `10-task-investigation-exec`（共通手順の正）: 「中核は 1 つ変えるごとにテスト」「テスト先行、通ってしまうときは反転検査」「仕様は直さず逸脱に記録」がそのまま手順として機能した
- `20-common-step-ticket` / `20-common-step-commit-push`: `ticket.sh start` / `commit.sh` はいずれも 1 回で通った
- **効き目が薄かった点**: 実施スキルは「レポートは 1 タスク 1 つ」と定めるが、**1500 行を超えたレポートに追記するときの手順**（どの表に行を足すか、共通部をどこまで更新するか）は書かれていない。今回は「表に載せきれない対象を本文で足さない」の原則から、各表に 0030 の行を足す形にした

### スコープ外で見つけたこと

- **`load_covered` の対象に `review-state.json` も含まれる**ため、`branch` を記録し始める前に書かれた `review-state.json`（`branch` キーが無い）は、`mr` が `null` だと既出に数えられなくなる。実害は「その切れ目のチケットがもう一度レビュー対象に入る」で安全側だが、本 issue の `logs/review-history.jsonl` の 2 行目（`"mr":null`）が該当する可能性がある（次の切れ目で `last_task` が膨らむかもしれない）
- **`test_boundary.sh` の `BD-T20` の足場は `logs/review-state.json` を残したまま次のケースへ進む**。今回は影響が無かったが、ケース間の独立性は保証されていない

### AI アセットに反映すべき内容

- **実施スキルに「巨大なレポートへの追記手順」を足す**（どの表に行を足すか、件数タイル・frontmatter をどう積むか）。1500 行を超えると「表の行を足し忘れる」事故が起きやすい
- **`10-task-ai-asset-implementation-exec` に「既存テストの期待値を変えるときの手順」を足す**。今回は「その期待値が固定していた振る舞いが仕様に反すること」を根拠にして変え、理由をレポートと見てほしい点に書いたが、スキルにはこの手順が無い

### 備考

- 実測用に残っている `.claude/worktrees/agent-a0194b10452b44141` には**一切触っていない**（テストの足場は一時リポジトリで作った）
