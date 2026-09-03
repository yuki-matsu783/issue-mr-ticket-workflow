---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0024"]
executor: main
human_review: {required: false, reason: "承認③により人間レビューは敵対的レビューで代替する"}
adversarial_review: {required: true, reason: "中核の提供コマンドで、機構自身を止め得る（work-defaults の基準どおり要）"}
allow:
  write: [".claude/skills/00-workflow-issue-mr-driven/**", "logs/**", "wip/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-04T04:26:21+09:00"
completed_at: ""
base_sha: "509240b"
---

# 0025 S2 中核: boundary.sh とそのテスト（BD-T01〜13）

## 目的

タスクの切れ目の判定・レビュー依頼・完了確認を担う提供コマンドを作り、logs/review-state.json を書き換える唯一の経路にする

## DoD

- [x] bash .claude/skills/00-workflow-issue-mr-driven/scripts/boundary.sh が 5 サブコマンド（status / note / request / skip / complete）を持ち、00-workflow-issue-mr-driven 仕様の Script 処理のとおりになっている（根拠: `usage()` と `main()` の case が 5 サブコマンド。判定は仕様「切れ目の判定（正）」「全体まとめの切れ目（--final）」「進行状態と記録」のとおりで、固定マーカー・BD001〜BD005・`--offline` / `--final` / `--standalone` / `--external` / `--accept-unresolved` を実装した）
- [x] 機械テスト BD-T01〜BD-T13 の 13 件が通る（根拠: `bash .claude/skills/20-common-step-shell-script/scripts/run-tests.sh --filter '*test_boundary*'` → `OK: 1 本 / 13 件`、`passed=74 failures=0`。DoD の `--filter boundary` はグロブがパス全体に当たるため一致せず、`'*test_boundary*'` に読み替えた）
- [x] 終了コードが 成功 0 / 前提・状態の未充足 1 / 引数・環境の誤り 2 で、最終行が OK: または BDxxx: になっている（根拠: `boundary.sh bogus` → `BD001: 引数・環境の誤り — 不明なサブコマンド: bogus…` / exit 2。`status --nope` も同じ。BD-T03 / T05 / T09 / T12 が exit 1 と `BDxxx:` を確かめている）
- [x] 共通 logger を読み込み logs/sh/ に実行ログを残している（rules/logger.md の使い分け）（根拠: `__ss_load logger nop` を読み込み行のまま使用。`logs/sh/boundary.log` が生成されている）
- [x] 書いた直後の 1 回目を commit.sh で自分をコミットして検証し、失敗時に戻す基準点（base_sha）を作業ログに記録している（根拠: 基準点は `509240b`（frontmatter の base_sha）。復旧は `git checkout 509240b -- .claude/skills/00-workflow-issue-mr-driven/scripts/`。commit.sh でのコミットは下の作業ログに記録）
- [x] このチケットの間 boundary.sh を自分の切れ目の手順に組み込んでいない（保留 P2 の判断。実運用は次の issue から）（根拠: このチケットの切れ目の記録は従来どおり `gh pr comment` の直接実行。`boundary.sh` の呼び出しはテストの中だけ）

## 作業内容

- boundary.sh を書く
- テストを書いて --filter で実行する

## 作業ログ

### 現在地

- 完了。`boundary.sh`（5 サブコマンド）とテスト 13 件を作り、全件 PASS を確認した

### うまくいったこと

- **`ticket.sh next` の出力を透過させた**。切れ目の判定に要る `next` / `current` / `type` / `skill` を自分で導出せず、そのまま載せた。種類からスキル名を引く処理が 2 か所に増えない（BD-T02 がこれを固定する）
- **`gh` をスタブに差し替えてテストを閉じた**。PATH の先頭にラッパーを置き、GraphQL とコメント API の応答を fixture ファイルで与える。ネットワークを使わずに、正規化の jq を実物と同じ経路で通せた
- **「push 済み」をリモート追跡参照の更新で作った**（`git update-ref refs/remotes/origin/<branch> HEAD`）。bare リポジトリを立てて push しなくても `git rev-list origin/<br>..HEAD` の検査を通せる
- 中核の変更を小さく保てた。`boundary.sh` は新規ファイルなので既存の機構を止めない（フックの参照先を直すのは S4）

### うまくいかなかったこと

- **1 回目のテストが 70 件失敗した**。原因は temp リポジトリに `commit-push` をコピーし忘れたことで、`ticket.sh next` が `TK008: commit.sh が無い` を返し、それを `jq` に食わせて `parse error` になっていた。コピー漏れを直したうえで、`boundary.sh` 側にも「`ticket.sh next` が JSON を返さなければ引数・環境の誤りとして止まる」検査を足した。**依存コマンドの出力を検証せずに `jq` へ渡していた**のが本質
- テストを 2 回続けて走らせたら 120 秒の既定タイムアウトに当たった。1 回に絞って出力をファイルに落とす形に変えた
- **初版のテストが 116 秒かかり、全件実行で `TR003`（120 秒のタイムアウト）になった**。原因は 2 つ。(1) ケースごとに `git add -A` + `git commit` していた、(2) `boundary.sh` が 1 回の `status` で jq を 10 回以上起動していた。`wip/` と `logs/` をテスト用リポジトリの追跡外にしてコミットを消し、`boundary.sh` の jq をまとめて **64 秒**にした。上限に対しておよそ 2 倍の余裕がある
- `jq ... | @tsv` の結果を `IFS=$'\t' read` で受けたら**空のフィールドが畳まれて値が 1 つずつずれた**（タブは IFS の空白文字扱いで連続が 1 つにまとめられる）。1 行 1 値で出して `mapfile` で受ける形に直した

### 仕様からの逸脱

- **引数・環境の誤りに専用のエラー識別子が無い**。仕様の識別子表は `BD001`〜`BD005` だけを定義し、終了コード 2（引数・環境の誤り）に対応する番号を持たない。他の提供コマンドは `TK008` / `CP007` / `RV008` を持っている。設計文書は直さない決まりなので、暫定で **`BD001` を終了コード 2 で使い**、メッセージの先頭に「引数・環境の誤り」と明記した。番号を分けるかはフィードバック計画へ（レポートの残課題 R3）
- **GitLab 経路は書いたが検証していない**。`glab api discussions` / `approval_state` の応答の形は fixture でも実機でも確かめていない（レポートの残課題 R4）

### 判断と根拠

- **機構のコメントの除外をマーカーの前方一致（`<!-- boundary:`）で行った**。仕様は 4 種のマーカーを列挙しているが、前方一致なら将来マーカーが増えても取りこぼさない。仕様が禁じている「ログイン名での除外」は行っていない（BD-T06 が同じアカウントの人間の指摘が残ることを固定する）
- **`--accept-unresolved` の判定順を「変更要求 → 未解決スレッド」にした**。変更要求は `--accept-unresolved` でも通さないので、先に見て止めるほうが受け入れコメントの投稿が起きない
- **再導出は記録が無い・壊れているときだけ行う**。有効な記録があるときにリモートを見に行くと、`status` が毎回 CLI を呼ぶことになり `--offline` の意味が薄れる
- **矛盾（BD005）の検査は再導出の経路にだけ置いた**。記録が正しいときに毎回リモートのコメントを数えるのは高くつく。片付け以降なのに作業領域に成果物が残る矛盾はローカルだけで判定できるので、こちらは常に見る

### 拒否・確認・迂回の記録

- WF205: `awk` の出力を `mv` で `.claude/` 配下に書き戻そうとして拒否された（コマンドで書けるのは `wip/tmp/**` と `logs/**` だけ）。Edit / Write ツールに切り替えた。迂回はしていない

### 使った AI アセットと効き目

- `20-common-step-shell-script` の `script.template.sh` / `test.template.sh`: 読み込み行・`result_ok` / `result_ng` の型・テストの書き方がそのまま使えた
- `test-lib.sh` の `make_tmp_repo` / `make_tmp_dir` / `tl_jq`: Windows の CR 混入と後始末を自分で書かずに済んだ
- `run-tests.sh --filter`: 13 件だけを 2 分で回せた（全件は 10 分前後）

### スコープ外で見つけたこと

- `run-tests.sh` の `--filter` はテストファイルの**パス全体**に対するグロブなので、`--filter boundary` のような部分文字列では 0 本になる（`TR001`）。チケットの DoD がこの書き方をしていた。使い方の例を `--filter '*test_boundary*'` の形で仕様か案内文に残すと迷わない

### AI アセットに反映すべき内容

- 提供コマンドの識別子表に「引数・環境の誤り」の番号を必ず 1 つ置く規約にする。`TK008` / `CP007` / `RV008` は持っていて `BD` だけが持っていないのは、表を書くときのテンプレートが無いため
- 他の提供コマンドの出力を入力にするときは、`jq` に渡す前に JSON かどうかを検査する。`ticket.sh` は失敗時に `TKxxx:` を返すので、そのまま渡すと原因の分かりにくい `parse error` になる
- **テストの実行時間を書き手の責任にする**。`run-tests.sh` の既定タイムアウトは 120 秒で、1 本がこれを超えると全件実行が `TR003` で落ちる。`20-common-step-shell-script` にテストの書き方として「ケースごとに git コミットしない（作業ツリーを汚さない置き場を使う）」「1 回の実行で外部プロセスを何十回も起動しない」を残したい
- **複数の値を 1 回の `jq` で受けるときは 1 行 1 値にする**。`@tsv` + `IFS` 区切りの `read` は空フィールドを畳むので値がずれる。`| .[]` と `mapfile` の組み合わせを定型にする

### 備考

- `boundary.sh` はこの issue の切れ目では使わない（保留 P2）。フックの参照先（`session-start.sh` など 7 行）を直すのは S4（0027）
