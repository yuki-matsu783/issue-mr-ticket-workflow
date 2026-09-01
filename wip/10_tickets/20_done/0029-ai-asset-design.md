---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0028"]
executor: main
human_review: {required: true, reason: "正史（仕様）の変更。承認④により opus 自己レビューで代替（切れ目 1 回）"}
adversarial_review: {required: true, reason: "正史の変更で差分が 1 文書・50 行を超える（切れ目 1 回）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T16:51:56+09:00"
completed_at: "2026-09-01T17:01:17+09:00"
base_sha: "139e41c"
---

# 0029 AI アセット設計: 共通ステップ仕様 5 本（shell-script / commit-push / ticket / report-view / ai-asset-creator）への書き戻し（wip/20_plans/0026-ai-asset-design-plan.md の 0029）

## 目的

計画書 wip/20_plans/0026-ai-asset-design-plan.md「文書一覧と骨子」の共通ステップ仕様 5 本を更新する: shell-script（読み込み行の FATAL 行・HOOK_DENY_ID・nop の LOGGER_ROOT、fm_get の戻り、TR004 / TR005 は終了 2、test-lib の make_counting_path / counted_calls と hook_payload の session_id、テスト観点の規約節: 語彙表の全要素・負のケースの正の期待値・計数）、commit-push（CP001 の条件・CP007・push.sh の識別子の整理・スキップ記録の形と HEAD の版・ステージ後の除外の当て直し）、ticket（create のオプション名・next の返却・cancel の記録・TK008・T10 文言・判定語・根拠欄なし・固定見出しの重複・index 復元・YAML エスケープ）、report-view（data-template・計画書の節構成と種類ごとの固有節・RV008）、ai-asset-creator（skill.template の冒頭段落・SKILL.md の frontmatter）。DDR i0006-10（提供コマンドの自己強制）・11（計画書テンプレートの必須節）を作る

## DoD

- [x] 担当の要件定義書・仕様書が 20-common-step-requirement / -spec のテンプレートと固定節構成に沿って更新され、履歴（以前は〜）を書かず現在の正史だけになっている（20-common-step-shell-script / -commit-push / -ticket / -report-view / -ai-asset-creator）（根拠: 5 本の仕様を固定節構成のまま更新（pairs で shell-script 10 / commit-push 10 / ticket 12 / report-view 7 / ai-asset-creator 2 か所、miss 0）。「以前は〜」の履歴は書かず、変更は現在形の記述のみ。要件書は変更なし（外部的な振る舞いは変わらない。ticket 要件への見出し重複の追加要否は 0030 で判断と結果報告に記載））
- [x] 受け入れ条件 5（提供コマンド 4 本とテスト）・6（シェルスクリプトの規約）が各仕様のテスト観点に落ちている: CP-T03 / CP-T06 / TICKET-T03 / TICKET-T05 / RV-T02 に 0025 で固定した観点、CP007 / RV008 / TK008 と重複見出しのテスト観点、SS-T / TR-T の計数と語彙の観点が書かれている（根拠: CP-T03（ディレクトリ・symlink・.gitignore 混在）/ CP-T06（HEAD の版だけ）/ TICKET-T03（根拠欄なし・見出し重複）/ TICKET-T05（cancel の記号）/ RV-T02（シングルクォート）に 0025 の観点を追記。新規 CP-T08（CP007 / CP008）・TICKET-T12（TK008）・RV-T07（RV008）。SS-T04（LOGGER_ROOT・FATAL・HOOK_DENY_ID）・FR-T05（0 回・生文字列）・TR-T04（TR004 / 005 終了 2）に計数と語彙の観点）
- [x] テスト観点の規約節（G10）の置き場が 20-common-step-spec の固定節構成と整合している（テスト観点の中か Script 処理のサブ節か。判断を DDR または作業ログに）（根拠: shell-script 仕様の Script 処理に「テストの書き方（規約）」サブ節を「テスト観点」の直前に新設（6 項目）。20-common-step-spec の固定節構成はスキルの Script 処理を「テスト観点含む」としサブ節の追加を制限しないので整合する。判断は作業ログ「判断と根拠」と結果報告 0028「決定と根拠 0029」に記録）
- [x] 横断文書（自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary）と用語が食い違っていない（変更なしならその確認を根拠に書く）（根拠: 自己改善ワークフロー機構.md・rules/ルール体系.md・90_glossary は今回の変更語彙（識別子・test-lib の関数名・計画書の節名）を持たず変更なし（grep で CP007 / RV008 / TK008 / make_counting_path / data-template が 0 件）。用語「自己強制」は DDR i0006-10 の本文では使わず「保証」で書いたので用語辞書への追加は不要と判断）
- [x] 決定の経緯と却下案が担当の DDR に残り、DDR から仕様を参照している（仕様から DDR を参照しない）（i0006-10・11）（根拠: 20_ddr/i0006-10（提供コマンドの保証は HEAD の版で担保）・11（計画書の必須 6 節と固有節）を i0006-06 と同じ形で作成し「影響」から仕様の節を参照。仕様 5 本に DDR 番号の参照は無い（grep i0006-1 で 0 件））
- [x] ヘッドレス実行の帰結（止まる / 既定で進む）が変更ごとに仕様に書かれている（根拠: push.sh の手順 0（CP007 で止まる）・スキップ記録の HEAD 版（未コミットなら項目 1 で止まる）・complete の見出し重複（止まる）・create の種類不正（TK008 で止まる）を仕様と結果報告「ヘッドレス実行で確認すること」に追記）
- [x] 他チケットの担当文書のうち参照先（台帳の番号・テスト ID・節名）を再読して文言が一致している（0028 の台帳 CP007 / RV008 / TK008・HK-T15）（根拠: 0028 の台帳 §6 を再読し、CP007 は引数・環境の誤りで一致。計画が CP007 に寄せていた git commit 自体の失敗は 1 番号 1 対処（i0006-12）に反するため CP008 を新設し、台帳の行を CP001–008 に改めた（フック共通仕様 §6、1 行）。RV008 / TK008 / HK-T15 は台帳と仕様の文言が一致）

## 作業内容

- 計画書の対応表（A3〜A6・B9・C1・C2・G2・G5・G10〜G12・D-29〜D-32）とレポート 0013 の逸脱表・レビュー F-1〜F-6・F-15・F-17 の根拠を仕様の文言に写す
- 0028 が確定した台帳の番号を参照し、仕様側の識別子表を合わせる

## 作業ログ

### 現在地

- 済: 計画 0026 の 0029 行と逸脱 D-3〜D-19・D-29〜D-32、レビュー F-1〜F-6・F-15・F-17・F-18 を読む → 仕様 5 本を pairs で更新 → 台帳 §6 に CP008 → DDR i0006-10/11 → 結果報告 0028 に 0029 の節を追記（md + HTML、check-html OK）→ このチケットの記入
- 完了: commit.sh → ticket.sh complete 0029 → 0030 へ

### うまくいったこと

- 0028 と同じ手順（pairs → 適用 → grep で参照確認）で 5 文書 41 か所を miss 0 で当てられた
- 決定表を先に書いてから仕様を編集したので、CP008 のような計画からの差分に早く気づけた

### うまくいかなかったこと

- 計画 0026 の CP007 の定義が 2 原因を含んでいたことを 0028（台帳を確定するチケット）で見落とし、0029 で台帳を直すことになった。「参照先の再読」は後続 → 先行の向きだけでなく、先行が台帳を確定する時点で計画の定義を疑うべきだった
- 実装を伴う項目が計画の 7 件から 8 件 + テスト 3 本に増えた（CP008・CP-T08・TICKET-T12・RV-T07・AC-E04）

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 自己レビューで代替（0030 の後に 1 回）
- 実行者が main（全体計画の方針）
- 結果報告は 0028 が作ったファイルに節を追記（実施タスクの共通手順どおり。新規ファイルは作らない）

### 判断と根拠

- CP008 の新設: i0006-12 の「1 番号 1 対処」。git commit 自体の失敗は検査未充足（終了 1）で、引数・環境（終了 2）と分類も違う
- 規約節の置き場: Script 処理のサブ節「テストの書き方（規約）」。固定節構成と両立し、ID の表と散文を分けられる
- push.sh の手順 0 を明示: 識別子表の条件文だけでは「検査の前に何を見るか」が実装依存になる
- スキップ記録は HEAD の版（DDR i0006-10）: 保証がスキップ可能な検査に依存しない形にする
- 計画書の固有節は必須節の後・保留の前（DDR i0006-11）: 共通部分の読み順を崩さない
- 見出し重複の判定は「同じ固定見出しが 2 回以上」: 空の節の検出は正当な「無し」と区別しにくい
- hook_payload --session は仕様に書き実装は 0031: 既定値で後方互換

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10_spec/skills/10-task-ai-asset-design-exec.md の共通手順（レポートへの追記）・20-common-step-spec の固定節構成（規約節の置き場の判断に使えた）
- DDR i0006-06 / i0006-03（必須節の判断の型）・20-common-step-report-view（check-html.sh）
- wip/tmp/apply-pairs.pl

### スコープ外で見つけたこと

- 20-common-step-ticket の要件書に完了検査の条件（見出し重複）を足すかは 0030 で判断
- 0031 の計画チケットの目的文（実装 7 件）は 8 件 + テストに増える。0031 が設計結果報告を読んで数え直す

### AI アセットに反映すべき内容

- 10-task-ai-asset-design-plan 仕様: 「台帳（識別子・テスト ID）を確定するチケットは、計画に書かれた識別子の定義が 1 番号 1 原因になっているかを確認する」を DoD の型に → 3/3

### 備考

- pairs: wip/tmp/p29-{shell,cp,ticket,rv,ac,ledger}.txt、レポート追記: wip/tmp/rep-0029-{md,html}.txt
