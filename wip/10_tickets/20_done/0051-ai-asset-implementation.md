---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0050"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "提供コマンド 2 本は中核で、壊れると切れ目の判定と片付けが止まる"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/scripts/**", ".claude/skills/10-task-overall-summary/scripts/**", "wip/**", "logs/**"]
  ops: ["read", "remote-read", "build-test", "hook-test"]
started_at: "2026-09-04T17:16:09+09:00"
completed_at: "2026-09-04T17:28:22+09:00"
base_sha: "ec27dbf"
---

# 0051 提供コマンド 2 本の引数・環境の誤りの識別子を分ける（S2・中核）

## 目的

boundary.sh と finalize.sh が終了 2 のときに前提未充足と同じ番号を返している状態を、BD006 / FN004 に分ける

## DoD

- [x] boundary.sh の arg_ng が BD006 を終了コード 2 で返す（00-workflow-issue-mr-driven 仕様 エラー識別子）。前提未充足は BD001 と終了 1 のまま（根拠: `boundary.sh:52` を `result_ng 006 ... 2` に変更。`boundary.sh bogus` が `BD006: 引数・環境の誤り — 不明なサブコマンド: bogus（status / note / request / skip / complete）` で終了 2。前提未充足は BD-T19 の最後のケース（`skip --reason ""`）で `BD001` / 終了 1 を確認）
- [x] finalize.sh の arg_ng が FN004 を終了コード 2 で返す（10-task-overall-summary 仕様 エラー識別子）。前提未充足は FN001 と終了 1 のまま（根拠: `finalize.sh:44` を `result_ng 004 ... 2` に変更。`finalize.sh bogus` が `FN004: 引数・環境の誤り — 不明なサブコマンド: bogus（release）` で終了 2。前提未充足は FN-T18 の最後のケース（未着手チケットを残した `release`）で `FN001` / 終了 1 を確認）
- [x] 機械テスト BD-T19 と FN-T18 が通る（bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_boundary*' と --filter '*test_finalize*'）（根拠: `OK: 1 本 / 19 件`（`passed=112 failures=0`）と `OK: 1 本 / 18 件`（`passed=69 failures=0`）。ID 数が 19 / 18 に増えており、新しい ID が実際に走っている）
- [x] 既存の BD-T03 / BD-T09 / BD-T16 / FN-T02 / FN-T10 が期待値を変えずに通る（いずれも終了 1 の前提未充足）（根拠: 上の 2 本に含まれて全通過。テストファイルへの変更は末尾への追記と 2 行目のコメントだけで、既存ケースの期待値は 1 行も編集していない）
- [x] 変更の直後に commit.sh で自分をコミットし、boundary.sh status が JSON を返すことを確かめている（ロックアウト対策。踏む経路と結果を作業ログに書く）（根拠: `96c2b1d` でスクリプト 2 本だけを先にコミットし、続けて `boundary.sh status` が `{"at_boundary":false,"position":"in_task",...}` を終了 0 で返した。作業ログ「判断と根拠」に経路を記載）
- [x] 実装結果レポートに S2 の節が追記されている（根拠: `wip/30_reports/0050-ai-asset-implementation.md` に e3・e4 とサマリ・検証の結果・設計への反映の追記。HTML も同期し `OK: 検査 7 項目すべて通過（id 18 件 / リンク 11 件を確認。テンプレート: report）`。md の `### e` 4 件と HTML の `<h3 id=` 4 件が一致）

## 作業内容

- boundary.sh と finalize.sh の arg_ng を直し、テストを足して実行する

## 作業ログ

### 現在地

- 完了（スクリプト 2 本の変更・テスト 2 件の追加・レポートへの S2 の追記まで済み）

### うまくいったこと

- 変更は `arg_ng` の 1 行ずつ、計 2 か所で足りた。番号を末尾に足す規約に従ったので、既存の識別子・テストの期待値には一切触っていない
- ロックアウト対策の順番（変更 → `commit.sh` で自分をコミット → `boundary.sh status`）がそのまま検証を兼ねた。`status` は `arg_ng` を通らない経路だが、同じスクリプトが壊れていないことを最短で確かめられる
- `test-lib.sh` に `make_restricted_path` があり、依存コマンドの不在を PATH の差し替えで踏ませられた。自前でスタブを書く必要が無かった

### うまくいかなかったこと

- 無し（テストは初回から全通過）

### 仕様からの逸脱

- 無し。むしろ、変更前のコードのコメントに書かれていた逸脱（「仕様の識別子表に専用番号が無いため BD001 / FN001 を終了コード 2 で使う」）が、このチケットで解消された

### 判断と根拠

- ロックアウト対策の経路: `arg_ng` を書き換え → `commit.sh` でスクリプト 2 本だけを先にコミット（`96c2b1d`）→ `boundary.sh status` が JSON を終了 0 で返す → `bogus` サブコマンドで `BD006` / `FN004` と終了 2 を確認、の順に踏んだ。テストを書く前にコミットしたのは、切れ目の判定が止まると自分をコミットする手段が無くなるため。戻す基準点は `ec27dbf`
- 依存コマンドの不在の再現は `make_restricted_path bash git`（`jq` を含めない）で行った。`env PATH=... bash <script>` の形にして、テスト本体の PATH は汚していない
- テストは仕様のテスト観点どおり 1 つの ID に 3 原因を並べ、同じ ID の中で「`-h` は終了 0」「前提未充足は終了 1 のまま」も確かめる形にした。番号を分けた変更が分けるべきでない側を動かしていないことが 1 か所で見える

### 拒否・確認・迂回の記録

- `set -e` を含むコマンドが WF204（分類外）で拒否された。迂回せず Edit ツールでの書き換えに切り替えた
- テストファイルの 2 行目のコメントを `sed -i` で直そうとして WF205（コマンドでの書き換え）で拒否された。Edit ツールでやり直した

### 使った AI アセットと効き目

- `20-common-step-shell-script` の `test-lib.sh`: `make_restricted_path` / `run_cmd` / `assert_exit` がそのまま使えた
- `10-task-ai-asset-implementation-plan` のロックアウト対策の指示: 「変更 → 自分のコマンドでコミット → 検証」の並びが計画どおり機能した

### スコープ外で見つけたこと

- `00-workflow-issue-mr-driven/SKILL.md:20` が仕様の参照範囲を「BD001〜BD005」、`10-task-overall-summary/SKILL.md:20` が「FN001〜FN003」と書いている。新しい番号を含む表記に直す必要があるが、どちらも S3（0052）の許可範囲なのでここでは触っていない。レポートの「設計への反映」に引き取り先付きで記録した

### AI アセットに反映すべき内容

- 無し（このチケット自体がアセットへの反映）

### 備考

- 変更したのは提供コマンド 2 本の `arg_ng` のみ。呼び出し側（`arg_ng` を呼ぶ 20 か所以上）は 1 か所も変えていない
