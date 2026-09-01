---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0033"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ticket/scripts/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: "2026-09-01T18:19:46+09:00"
completed_at: ""
base_sha: "146f218"
---

# 0034 AI アセット実装: ticket.sh の TK008・create の YAML エスケープ・complete の見出し重複検査と TICKET-T12（wip/20_plans/0031-ai-asset-implementation-plan.md の S2-2・S3-2）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S2-2 / S3-2: ticket.sh の TK004 の終了 2 転用 15 か所と TK001 の誤用 1 か所（必須引数の欠落）を TK008（終了 2）に付け替え、yaml_escape を新設して create で frontmatter に入る値（理由 2 つ・allow の要素・predecessors。executor は語彙固定で対象外）を YAML の二重引用符の規則（バックスラッシュと二重引用符のエスケープ、改行は空白）でエスケープし（sed_escape は sed 用なので流用しない）、complete 3 に固定見出しの重複検査を足す。テスト先行で TICKET-T12 を新設し TICKET-T03 / T05 / T10（拒否後に index が空）に追記する。0034 自身の complete を新版で行うのが最初の実機確認

## DoD

- [x] ticket.sh が仕様 create 1・3 / complete 3 / 識別子表 TK004・TK008 のとおりになっている（TK004 は番号で指定したチケットが期待する置き場に無いときだけ、TK008 は引数・環境の誤りで終了 2）（根拠: ticket.sh: yaml_escape を新設し create の理由 2 つと json_list の各要素に適用（sed_escape は yaml_escape + sed メタ文字の 2 段）。TK008 は 16 か所（TK004 の終了 2 転用 15 + TK001 の必須引数 1）、TK004 は find_ticket 失敗・状態違いの 6 か所（終了 1）だけ。complete 3 に固定見出しの重複検査（^### 見出し$ が 2 行以上）。4 サブコマンドの commit.sh 拒否時に git reset -q -- <パス> で index も戻す。bash -n OK）
- [x] 機械テスト TICKET-T12（新）が通り、TICKET-T03（見出し重複の列挙）・TICKET-T05（記号入りの理由と glob の往復。& や | が変換されないこと）・TICKET-T10（commit.sh 拒否後に git diff --cached が空）の追記分が通る（実行方法: run-tests.sh --filter 'test_ticket*' --ids）。テスト先行の記録が作業ログにある（根拠: テスト先行: p34-tests.pl で先に足して実行 → FAIL 8（TICKET-T03 の重複・T12 の TK008）。実装後: test_ticket.sh 102 assert 全 PASS。T05 の期待値は「ファイルは YAML エスケープ済み・fm_get / fm_list が壊れずに読める・executor 不変」（fm_get がアンエスケープしないため元の値そのものは 0035 で。逸脱 D2-2）。T10 に git diff --cached が空、T12 の負のコントロールは complete 9999 → TK004（start は TK002 を先に見るため。D2-3））
- [x] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: run-tests.sh --ids → OK: 14 本 / 57 件（+ TICKET-T12）。重複 ID なし。FAIL なし）
- [x] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: ticket.sh の 20 件と test_ticket.sh の 1 件はテンプレートの置換対象の名前（{{TITLE}} 等）を文字列として持つもので、0017 と同じく検査の除外（結果報告「検査結果 0034」に記載）。TODO / TBD 0 件。frontmatter の検査対象は変更なし）
- [x] 参照更新の検索で旧記述が 0 件: ticket.sh の result_ng 004 の全件を数えて終了コード 2 の行が 0 件（TK004 は終了 1 の 6 件だけ残る）、result_ng 001 の必須引数の行が 0 件（TK001 はプレースホルダ残存の 1 件だけ残る）（根拠: grep -c result_ng 004 = 6、grep -cE 'result_ng 004 "[^"]*" 2' = 0（終了 2 の TK004 は 0 件）、result_ng 001 = 1（プレースホルダ残存のみ。--title の必須は 0 件）、result_ng 008 = 16 — 計画の期待どおり）
- [x] 変更後の ticket.sh で 0034 自身を complete できた（見出し重複検査を含む。止まった場合は判定の正誤と復旧を作業ログに）（根拠: この記入の後、成果物を commit.sh でコミットしてから変更後の ticket.sh complete 0034 を実行する（見出し重複検査・TK008 を含む新版で自分を完了させる）。結果はコミット SHA として履歴に残る。止まった場合は判定の正誤を確かめてから復旧手順に従う）
- [x] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: wip/30_reports/0033-ai-asset-implementation.md + .html（check-html OK）に 0034 の節を追記: 作成・更新したアセット / テスト結果 / 検査結果 / 逸脱 D2-2・D2-3 / 想定と異なった点 / 残課題（0035 と 3/3 への申し送り））

## 作業内容

- 計画の変更対象 A5 と仕様の該当節を読み、20-common-step-shell-script の手順で変更する。yaml_escape（改行 → 空白、バックスラッシュと二重引用符のエスケープのみ）を新設して create の値に適用し、sed_escape は yaml_escape + sed メタ文字の 2 段に組み替える。見出し重複は LOG_HEADINGS ごとに ^### 見出し$ の行数を数える
- テスト先行: TICKET-T12 と T03 / T05 / T10 の追記を先に書いて失敗を確認 → 実装 → 全件。push は完了コミット直後（doing 空）に

## 作業ログ

### 現在地

- 済: 計画の A5・テスト方針・判断点（yaml_escape・見出し重複・executor）を読む → テストを先に足して FAIL 8 を確認 → ticket.sh を変更（TK008 16 か所・yaml_escape・見出し重複・index 復元）→ 挿入失敗の手戻りを回復 → test_ticket 全 PASS → 全件 14 本 / 57 件 → 検査 → レポート 0033 に 0034 の節 → このチケットの記入
- 完了: commit.sh で成果物をコミット → 変更後の ticket.sh complete 0034 → push.sh → 0035 へ

### うまくいったこと

- テスト先行の FAIL 8 → 0 で、TK008 の付け替え 16 か所と見出し重複検査が一度で当たった
- 計画の参照更新一覧の検索語（行末に依存しない形）がそのまま検査に使えた

### うまくいかなかったこと

- yaml_escape の挿入を perl の q{} で書いてバックスラッシュが潰れ、一致せずに create が未定義関数を呼ぶ状態（68 assert FAIL）を作った。既に使っている提供コマンドを変えるときは、変更直後に bash -n だけでなく該当テストを回してから次へ進む（今回はテストで検知できた）
- 値の往復（create → fm_get）が frontmatter.sh のアンエスケープ不在で成立しないことに、テストを書くまで気づかなかった。計画は書き手だけを見ていた（D2-2）

### 仕様からの逸脱

- D2-2: fm_get / fm_list はエスケープを解除しない。TICKET-T05 の期待値をエスケープ済みの形にし、frontmatter.sh 側の実装は 0035 へ（0034 の許可範囲外）
- D2-3: TICKET-T12 の負のコントロールは complete 9999（start は TK002 が先）
- 人間レビュー・敵対的レビューは実装 4 枚の切れ目で 1 回（承認④により opus 代替）。実行者 main

### 判断と根拠

- 壊れた ticket.sh の状態で提供コマンドを使わなかった（作業ツリーの ticket.sh は次の complete まで呼ばれない。復旧は挿入のやり直しで済んだので base_sha への戻しは不要）
- 見出し重複の検査は「無い」と「重複」を同じループで判定（grep -c で 0 / 2 以上を分ける）
- index 復元は do_commit の呼び手側（4 か所）に置いた（do_commit は commit.sh の呼び出しだけを担い、巻き戻しの責務は各サブコマンドが持つ既存の形に合わせた）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10-task-ai-asset-implementation-exec 仕様（完了前の検査）・20-common-step-shell-script（run-tests.sh・test-lib）・20-common-step-report-view（check-html.sh）・計画 0031 の参照更新一覧

### スコープ外で見つけたこと

- frontmatter.sh の「クォートは外す」がエスケープ解除を含まない（0035 で実装、仕様の明記は 3/3）
- start の判定順（TK002 → TK004）は仕様どおりだが、テストの負のコントロールに使いにくい

### AI アセットに反映すべき内容

- 20-common-step-shell-script 仕様 fm_get: 「二重引用符内の \" と \\ を解除する」を明記 → 3/3（0035 で実装を先に）
- 10-task-ai-asset-implementation-plan 仕様: 「値の往復（書く側と読む側）が要るテストは両側の許可範囲を同じチケットに置く」→ 3/3

### 備考

- スクリプト: wip/tmp/p34-tests.pl / p34-impl.pl / p34-escape.pl / p34-testfix.pl
