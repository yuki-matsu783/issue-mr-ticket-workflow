---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0025"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "中核の提供コマンドで、ticket.sh の切り出しが壊れると全チケットの状態遷移が止まる"}
allow:
  write: [".claude/skills/10-task-overall-summary/**", ".claude/skills/20-common-step-ticket/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T05:26:29+09:00"
completed_at: "2026-09-04T10:35:30+09:00"
base_sha: "fb8b80a"
---

# 0026 S3 中核: finalize.sh とそのテスト（FN-T01〜09）・完了検査の共有

## 目的

全体まとめの片付けから draft 解除までを 8 段階の 1 コマンドにまとめ、完了検査を ticket.sh と共有して二重実装を避ける

## DoD

- [x] bash .claude/skills/10-task-overall-summary/scripts/finalize.sh release が 8 段階を順に実行し、logs/merge-state.json の state を started → recorded → linked → cleaned → pushed → ready に進める（根拠: `stage_precheck` / `stage_check` / `stage_record` / `stage_link` / `stage_cleanup` / `stage_push` / `stage_ready` と `cmd_release` 末尾の出力。`FN-T01` が 1 回の実行で `ready` に達し draft が解除されることを、`FN-T03` / `FN-T04` が途中の状態（`pushed` / `cleaned`）から続きだけを行うことを確かめる）
- [x] 機械テスト FN-T01〜FN-T09 の 9 件が通る。FN-T08（空の表が linked にならない）と FN-T09（本文書き換えが添付を残す）を含む（根拠: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_finalize*'` → `passed=38 failures=0`。DoD の `--filter finalize` はグロブがパス全体に当たるため `'*test_finalize*'` に読み替えた）
- [x] ticket.sh の完了検査が ticket_check_completion として切り出され、finalize.sh が source して使っている（二重実装が無い）。切り出し後に ticket.sh next が JSON を返すことを確かめている（根拠: `.claude/skills/20-common-step-ticket/scripts/ticket-check.sh` に `ticket_check_completion` / `ticket_section` / `TICKET_LOG_HEADINGS` を置き、`ticket.sh` は読み込み行の直後で source して `cmd_complete` から呼ぶだけにした。`finalize.sh` の `main` が同じファイルを source する。切り出し後の `ticket.sh next` は `{"current":"0026","next":null,"type":"ai-asset-implementation","skill":"10-task-ai-asset-implementation-exec"}` を返した）
- [x] 値の往復の両側が同じチケットに入っている: 切り出す側（ticket.sh）・使う側（finalize.sh）・両者を確かめるテスト（根拠: 同じコミットに `ticket-check.sh`（新規）・`ticket.sh`（呼び出しに置換）・`finalize.sh`（source）・`test_finalize.sh`（新規）・`test_ticket.sh` と `test_boundary.sh` のコピー範囲の修正が入っている。`test_ticket.sh` の TICKET-T01〜T11 は全件テストで PASS）
- [x] 本文のリンク一覧の書き込みが固定マーカー <!-- finalize:linked <sha> --> を残し、再導出が表の有無ではなくマーカーで linked を判定している（根拠: `stage_link` の awk が末尾にマーカーを置き、`rederive_state` はマーカーの有無だけで `linked` / `recorded` を分ける。`FN-T06` がマーカーと固定リンクの実在を、`FN-T08` が「空の表だけでは linked にならない」「マーカーがあれば段階 4 を飛ばす」の両分岐を確かめる）
- [x] CLI が使えない環境の --external（段階 4 と 7 の代行）が実装され、logs/merge-state.json に via: external を残す（根拠: `release --external --pr <M> --body-file <path>` が段階 4 の本文を書き出して止まり、`--linked` で再開する。段階 7 は `--external` のとき `mark_ready` を呼ばず最終ゲートだけを検査する。`FN-T08` が `via` = `external` と、draft が解除されないまま（`true`）であることを確かめる）

## 作業内容

- ticket.sh から完了検査を関数として切り出す
- finalize.sh を書き、テストを --filter で実行する

## 作業ログ

### 現在地

- 完了。`finalize.sh`（8 段階）・`ticket-check.sh`（完了検査の切り出し）・テスト 9 件を作り、全件 PASS を確認した

### うまくいったこと

- **完了検査を関数 1 つに切り出せた**。`ticket.sh` の `cmd_complete` は 25 行が 4 行になり、`finalize.sh` は同じ判定をそのまま使える。判定の文言も 1 か所になった
- **テストでリモートを本物に近づけた**。bare リポジトリを立てて `push.sh` を実際に走らせ、`gh` だけをスタブにした。MR 本文と draft の状態をファイルで持たせたので、段階 4 の本文書き換えと段階 7 の解除を実物と同じ経路で確かめられる
- **`FN-T07` を「書き出した」ではなく「`pre_cleanup_sha` のコミットに含まれる」で書けた**。段階 3 を省いても書き出しだけは通ってしまうので、コミットに載っていることまで見ないと受け入れ条件 B4 を守れない
- 実行時間は 44 秒で、ランナーの既定タイムアウト（120 秒）に対して余裕がある

### うまくいかなかったこと

- `git clean -qfd` で作業領域を戻すと、**空ディレクトリは git が追跡しないので `00_todo/` が消えた**まま戻らず、`FN-T02` の準備が `cp` で失敗した。`mkdir -p` を足して直した
- 最初 `commit.sh` にディレクトリ（`wip`）を渡す形で片付けを書いたが、`commit.sh` はディレクトリを受け取らない（`CP001`）。消す前にファイルの一覧を作って渡す形に直した

### 仕様からの逸脱

- **引数・環境の誤りに専用のエラー識別子が無い**（`boundary.sh` と同じ）。仕様の識別子表は `FN001`〜`FN003` だけで、終了コード 2 に対応する番号を持たない。暫定で **`FN001` を終了コード 2 で使い**、メッセージの先頭に「引数・環境の誤り」と明記した。番号を分けるかはフィードバック計画へ（レポートの残課題 R3 に合流）
- **GitLab 経路は書いたが検証していない**（`glab api` の応答の形）。テストは GitHub 経路だけを通る（レポートの残課題 R4 に合流）

### 判断と根拠

- **切り出し先を `20-common-step-ticket/scripts/ticket-check.sh` にした**。完了検査はチケットの規約そのものなので、持ち主はチケットのスキプ。`finalize.sh` は使う側として source する。共通ライブラリの置き場（`20-common-step-shell-script`）に置かなかったのは、そこはスクリプト作法の道具（logger・frontmatter・test-lib）の置き場で、チケットの規約を置く場所ではないため
- **`ticket_check_completion` に `--skip-worktree` を用意した**。未コミットの検査だけは呼び手の文脈で要否が変わる。今回はどちらの呼び手も既定（検査する）を使っている
- **段階の分岐を `case` のフォールスルーではなく `if` の連鎖にした**。`write_state` が `F_STATE` を進めるので、`if [ "$F_STATE" = "recorded" ]; then stage_link; fi` を並べるだけで「続きから」も「1 回で通す」も同じコードで書ける。`;&` は読み手に段階の飛ばし方が伝わりにくい
- **片付けは `find` の結果を先に配列へ取ってから消した**。消してからパスを集めることはできず、`commit.sh` には削除されたパスを明示して渡す必要がある
- **敵対的レビューは中核 3 枚（0025・0026・0027）をまとめて 1 回にする**。3 枚とも frontmatter は `adversarial_review: required: true` だが、実装計画（0017）は「実装フェーズの敵対的レビュー 2 回は**中核のステップ（0025〜0027）**と総仕上げ（0032）に割り当てる」と書いており、1 枚ずつ実施すると全体計画の上限（1 フェーズ 2 回）を超える。0027 の完了後に 0025 の基準点から 0027 の HEAD までの差分をまとめて 1 回レビューする。この読み替えは切れ目のコメントにも書く

### 拒否・確認・迂回の記録

- **許可範囲の外に 1 ファイル触れた**: `.claude/skills/00-workflow-issue-mr-driven/scripts/tests/test_boundary.sh`。このチケットの `allow.write` は `10-task-overall-summary` と `20-common-step-ticket` だが、`ticket.sh` が `ticket-check.sh` を source するようになったため、`ticket.sh` だけをコピーしていた `test_boundary.sh` が動かなくなる。**変更対象を入力に持つテストは同じチケットで直す**（実施タスクの制約）ので、コピー範囲を `*.sh` に広げる 1 行だけを直した。機構は拒否しなかった。範囲を戻すとテストが赤のまま残るので戻していない
- WF205 / WF204 の拒否は無し

### 使った AI アセットと効き目

- `20-common-step-ticket` 仕様の完了検査の記述: 切り出す単位（DoD・作業ログ・未コミット）が一意に決まった
- `10-task-overall-summary` 仕様の再導出の規定: `linked` の判定に表の有無を使わない理由がそのままテスト（`FN-T08`）になった
- `test-lib.sh` の `make_tmp_repo` / `make_tmp_dir` / `tl_jq`: bare リモートとスタブの後始末を自分で書かずに済んだ

### スコープ外で見つけたこと

- `run-tests.sh` の `--filter` はパス全体のグロブなので、チケットの DoD が書いていた `--filter finalize` / `--filter boundary` では 0 本になる（`TR001`）。2 チケット続けて同じ書き方をしていたので、テンプレートか案内文に `'*test_<名前>*'` の形を残したい

### AI アセットに反映すべき内容

- 提供コマンドの識別子表に「引数・環境の誤り」の番号を必ず 1 つ置く規約にする（`BD` と `FN` の両方で同じ欠落が出た）
- チケットの DoD にテストの実行コマンドを書くときは、`run-tests.sh --filter` のグロブがパス全体に当たることを踏まえた形（`'*test_<名前>*'`）にする。計画タスクの書き方として残す
- 提供コマンドが他の提供コマンドを内部から呼ぶとき（`finalize.sh` → `commit.sh` / `push.sh`）、呼ばれる側の前提（`push.sh` は作業中チケットに `remote-write:push` の宣言を求める）を呼ぶ側のエラーメッセージに書く。今回は `stage_record` の失敗文言に入れた

### 備考

- `finalize.sh` はこの issue の全体まとめで実際に使う（`boundary.sh` と違って保留 P2 の対象外）。使うのは 0032 の後の全体まとめタスク
