---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: ["0031"]
executor: main
human_review: {required: false, reason: "自己レビューの反映。反映結果は note で報告する（承認④）"}
adversarial_review: {required: false, reason: "計画書（work-defaults の既定）"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-01T17:56:14+09:00"
completed_at: "2026-09-01T18:03:29+09:00"
base_sha: "a1bd3f2"
---

# 0038 AI アセット実装計画・追加: 自己レビュー P-1〜P-23 の反映（計画書 0031 とチケット 0033〜0037 の修正）

## 目的

wip/tmp/review-0031-findings.md の指摘のうち確度 0.5 以上の 20 件（P-1〜P-20）を計画書 wip/20_plans/0031-ai-asset-implementation-plan.md（+ HTML）と未着手チケット 0033〜0037 の目的・DoD・allow に反映し、0.5 未満の P-21（保留に記録）・P-22（HTML の参照更新表）・P-23（統括レポートに DoD × 根拠を写す）も直す。実装には入らない

## DoD

- [x] P-1・P-2・P-7・P-8・P-20: 0033 の allow.write が commit-push/scripts/** + テンプレート 2 本 + ticket/scripts/tests/**（TICKET-T10 の期待値 CP004 → CP008 の更新）に直り、DoD の push を「完了コミット直後（doing 空）に push.sh」に改め、CP007 4 か所・CP-T04 の -m 値なし assert の CP-T08 への移設が計画とチケットに書かれている（根拠: 0033 の allow.write を commit-push/scripts/** + assets 2 本 + ticket/scripts/tests/** + wip/** に（frontmatter を直接編集）、DoD 3 に CP-T04 の -m 値なし assert の CP-T08 への移設と TICKET-T10 の期待値 CP004 → CP008、DoD 7 を「変更後の commit.sh でコミットできた。push は完了コミット直後（doing 空）」に。計画書は A3（CP007 4 か所 L71/76/77/90）・許可範囲案・テスト方針（CP-T04 の付け替え行、TICKET-T10 の期待値行）・ステップ S2-1 / S3-1・ロックアウト表 0033 行・リスク 2 行を修正。HTML も同じ）
- [x] P-5・P-6・P-14・P-15・P-16: 0034 の作業内容が yaml_escape の新設（sed_escape は流用しない）になり、TK004 の終了 2 の 15 か所 + TK001 誤用 1 か所（L126）を TK008 へ、TICKET-T10 に index の assert、判断点に executor（引用符なし・語彙固定でエスケープ対象外）と改行 → 空白が書かれ、参照更新一覧の検索語が行末に依存しない形（期待値: TK004 は終了 1 の 6 件）になっている（根拠: 0034 の目的・作業内容を yaml_escape の新設（sed_escape は流用しない）、TK004 の終了 2 転用 15 か所 + TK001 誤用 1 か所（L126）、TICKET-T10 の index assert に。計画書の判断点「create の YAML エスケープの対象と実装」に executor（引用符なし・語彙固定で対象外）と改行 → 空白と yaml_escape / sed_escape の 2 段を明記。参照更新一覧の ticket.sh 行を「result_ng 004 の全件を数え終了コード 2 の行」（期待: 終了 2 は 0、全件 6）と TK001 誤用行に書き換え）
- [x] P-11・P-12・P-13・P-18: テスト方針表に SS-T04（nop の LOGGER_ROOT / FATAL: 終了 2 / deny の WF009）・TR-T04（timeout 不在 → TR005 終了 2）・FR-T05（計数 PATH で 0 回・list / inline キーの生文字列）の追記が 0035 に割り付けられ、HK-T15 の数が 93 assert + 冒頭コメント（残存 HK-T11 は 21 件）になっている（根拠: 計画書のテスト方針に SS-T04 / TR-T04 / FR-T05 の追記行（0035）と HK-T15 行の 93 assert + 冒頭コメント（grep -c HK-T11 は 21）を追加。0035 の目的・DoD 2・DoD 5・作業内容に同じ内容。A8 のテストを 9 本に）
- [x] P-3・P-9・P-10・P-17: 参照更新一覧が実測件数（SP-E 7 行 / 2 ファイル、AC-E01〜03、RV001〜007 2 か所、CP001〜006 1、TK001〜007 1、feature-mr SKILL.md の CP005 / CP006）で書かれ、0036 の allow.write に spec / ai-asset-creator / feature-mr の SKILL.md が入り A9 が 7 本になっている（根拠: 参照更新一覧を p38-refs.pl で書き直し（SP-E 7 行 / 2 ファイル、AC-E01〜03 1 件、RV: 4 件、commit.sh の引数誤りの CP001 4 件、CP004 コミット失敗 2 件、push.sh 1 + 4 件、TK004 21 のうち終了 2 が 15、TK001 誤用 1、SKILL.md の旧記述 commit-push 2 / ticket 1 / report-view 2 / feature-mr 1、HK-T11 114 → 21）。A9 を SKILL.md 7 本に、0036 の allow.write に spec / ai-asset-creator / feature-mr の SKILL.md を追加、DoD 3 を期待値どおりの文言に）
- [x] P-4・P-19・P-23: 0037 の allow.ops が overall-summary の上限の語彙（read, remote-read, remote-write:issue-create, remote-write:mr-edit, remote-write:mr-comment, remote-write:attach, remote-write:push, remote-write:draft-ready, merge-base）から選ばれ、DoD に 10-task-overall-summary 仕様の手順 2（別 issue 起票または「追加の反映なし」）・手順 6（HTML 添付コメントと本文追記）・衝突確認の位置（統括レポートの前）・統括レポートへの DoD × 根拠の転記が入っている（根拠: 0037 の allow.ops を overall-summary の上限の語彙 9 種に（scope-limits.json で確認）、目的と DoD を 10-task-overall-summary 仕様の処理フロー 2〜9（別 issue 起票・衝突確認・統括レポート・PR 本文の統括節・HTML 添付・push・承認③・片付け・最終ゲート・draft 解除）に書き直し、統括レポートに DoD × 根拠を写す項目を追加。issue #6 へのコメントは仕様に無いので削除。計画書の判断点・ステップ・チケット表・保留（issue-append が上限に無い件）に反映）
- [x] P-21・P-22: 計画書の保留した点に「TICKET-T05 に create のエスケープ往復は仕様に無い（次の設計で仕様側を揃える）」があり、HTML に参照更新一覧の表（修正後の値）が入って check-html OK（根拠: 計画書の保留した点に TICKET-T05 の create 往復（仕様に無い。次の設計で揃える）を追加。HTML の「方法とステップ」に参照更新一覧の表（修正後の値）を追加し check-html OK（id 11 / リンク 8））

## 作業内容

- wip/tmp/review-0031-findings.md を読み、計画書 md → HTML → チケット 0033〜0037（未着手。frontmatter の allow と本文を直接編集）の順に直す

## 作業ログ

### 現在地

- 済: wip/tmp/review-0031-findings.md（P-1〜P-23）を読む → scope-limits.json の overall-summary の ops 上限と 10-task-overall-summary 仕様の処理フローを確認 → 計画書 md（pairs 17 + 参照更新一覧の書き直し）→ HTML（pairs 13、check-html OK）→ todo のチケット 0033〜0037 の allow・目的・DoD・作業内容を直接編集 → このチケットの記入
- 完了: commit.sh → ticket.sh complete 0038 → push → PR #7 に note → 0033 へ

### うまくいったこと

- レビューが行番号と実測件数を付けていたので、参照更新一覧を「残るもの」で書き直す形に一度で変えられた
- todo のチケットは frontmatter と本文を直接編集して済ませた（取り消して作り直すと連番と cancelled が 5 枚増える）

### うまくいかなかったこと

- 0011 の自己レビュー（R8: 参照更新一覧に実測件数）と同型の指摘（P-17）を再発させた。「要確認」のまま計画を出さない
- 全体まとめの手順を旧ワークフロー SKILL.md（notify-issue）の記憶で書き、10-task-overall-summary 仕様（別 issue 起票・HTML 添付・issue コメントなし）を読まずに起票した
- 0033 の allow.write に ticket のテストを入れ忘れ、commit.sh の変更で全件 PASS が満たせない構成になっていた（テストの依存を先に grep しておく）

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 自己レビューで代替。このチケットはその反映で、結果は note で報告する
- 実行者が main（全体計画の方針）
- todo のチケット 5 枚の frontmatter（allow）と本文を ticket.sh を通さず直接編集した（ticket.sh は状態遷移だけを担い、内容の編集手段を持たない。00_todo/ のチケットは機構が読まない）

### 判断と根拠

- P-1 は CP008 を 0033 に残し ticket のテストを allow に足す（CP008 を 0034 に移すと commit.sh の変更が 2 チケットに割れる）
- P-2 は push を完了コミット直後に（0011 と同じ運用。上限に remote-write:push が無いので宣言では解決しない）
- P-15 は yaml_escape 新設（sed_escape の流用は値を壊す）。P-16 の executor は語彙固定で対象外
- P-19 は仕様の処理フロー 2〜9 に完全に合わせ、issue #6 へのコメントは行わない（Closes #6 で閉じる）
- P-21 / P-22 / P-23 は 0.5 未満だが安いので直した

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10-task-ai-asset-implementation-plan 仕様（参照更新一覧・ロックアウト対策の規定）・10-task-overall-summary 仕様（処理フロー 2〜9）・scope-limits.json（ops の語彙）
- wip/tmp/apply-pairs.pl、p38-refs.pl、p38-tickets.pl

### スコープ外で見つけたこと

- overall-summary の ops 上限に issue-append が無い（仕様に issue コメントが無いので矛盾ではない）→ 3/3 のワークフロースキル改訂で notify-issue の扱いを決める
- 仕様の TICKET-T05 に create の往復が無い → 次の設計

### AI アセットに反映すべき内容

- 10-task-ai-asset-implementation-plan 仕様: 「参照更新一覧は検索語を行末に依存しない形で書き、期待値は『残るもの』で書く」「テストの期待値が変更対象のスクリプトに依存するテストファイルを grep で洗い出し、同じチケットの許可範囲に入れる」を処理フローに → 3/3
- 10-task-overall-summary の全体まとめチケットの型（DoD の型）を仕様に置く → 3/3

### 備考

- pairs: wip/tmp/p38-plan.txt / p38-html.txt、スクリプト: p38-refs.pl / p38-tickets.pl
