---
type: ticket
ticket_type: ai-asset-implementation-plan
predecessors: ["0028", "0029", "0030"]
executor: main
human_review: {required: true, reason: "許可範囲とロックアウト対策を実装前に見る（work-defaults の既定。承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "計画書（work-defaults の既定）"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-01T17:33:16+09:00"
completed_at: ""
base_sha: "004b5b2"
---

# 0031 AI アセット実装計画（設計 0028〜0030 で仕様に書いた実装 7 件）

## 目的

設計 0028〜0030 で仕様に書いた実装を伴う変更 7 件 — HK-T15 の ID 付け替え（test_scope.sh）、eval 定義 5 本の SC-E 改名、CP007 / RV008 / TK008 の出力（commit.sh / push.sh / check-html.sh / ticket.sh）、test-lib の hook_payload --session、skill.template.md のガイド、20-common-step-shell-script SKILL.md の make_counting_path、ticket.sh complete の重複見出し検査 — を対象に、固定順・テスト ID の割付・提供コマンドの切り替え境目（既に切り替え済み）・ロックアウト対策（フック未登録のため経路なし）を計画し、実装チケット群と全体まとめチケット（overall-summary）を起こす

## DoD

- [x] AI アセット実装計画書 wip/20_plans/0031-ai-asset-implementation-plan.md（+ HTML、check-html.sh OK）があり、7 件の変更をステップ順（設定・定義 → 中核 → 中核のテスト → スキル・ルール → 参照更新）に置き、テスト ID × ステップ表（HK-T15・SC-E・CP007 / RV008 / TK008 の観点）と許可範囲・ロックアウト対策（フック未登録で経路なし。提供コマンドの変更は自分自身でコミットするので、壊した場合の復旧手順を書く）がある（根拠: wip/20_plans/0031-ai-asset-implementation-plan.md + .html（check-html OK: id 11 / リンク 8、テンプレート plan）。変更対象 A1〜A11、ステップ S1（テンプレート）→ S2/S3（commit-push → ticket → report-view + test-lib + hooks/lib テスト）→ S4（SKILL.md・eval）→ S5（参照更新）の固定順、テスト方針表（CP-T08 / T03 / T06、TICKET-T12 / T03 / T05、RV-T07、HK-T15、HK-T07 / T08 の --session、SC-E01〜03 / AC-E04）、許可範囲案（チケットごとの write と ops）、ロックアウト対策（フック未登録で経路なし。自分で変える提供コマンドごとに最初の操作と git checkout <base_sha> -- <path> の復旧手順）。設計時の 7 件に CP008・create の YAML エスケープ・SKILL.md のエラー表を加えた 9 件 + テスト）
- [x] 実装チケット群が未着手にあり、DoD が実装チケットの型（テスト先行・run-tests.sh --ids 全通過・プレースホルダ / frontmatter 検査・実装結果レポートの節）で書かれている（根拠: 00_todo/0033（テンプレート 2 本 + commit.sh / push.sh + CP-T08。レポート 0033 を作る）、0034（ticket.sh + TICKET-T12）、0035（check-html.sh + test-lib + HK-T15 + RV-T07）、0036（SKILL.md 4 本 + eval 2 本 + 参照更新 + 全件）。DoD は exec 仕様の型（アセットが仕様の節のとおり / 機械テスト ID が通る（実行方法・テスト先行の記録）/ eval ID が定義されている / プレースホルダ・frontmatter の検査 0 件 / 参照更新の検索で旧名 0 件 / 実装結果レポートの節）+ ロックアウト対策の最初の操作。predecessors は 0031 → 0033 → 0034 → 0035 → 0036 の一直線）
- [x] 全体まとめチケット（overall-summary）が 1 枚だけ未着手にあり、predecessors に実装チケット群の番号が入っている（根拠: 00_todo/0037-overall-summary.md（predecessors: 0033, 0034, 0035, 0036）。finalize.sh 未作成のため手作業代替の手順を DoD に 1 項目ずつ（統括レポート / PR 本文 / 承認③と片付け・衝突確認 / 承認⑥と issue コメント / draft 解除）。allow.ops に remote-write:pr / issue）

## 作業内容

- 設計 0028〜0030 の結果（仕様の該当節）と 0011 の実装計画書の形式を読み、同じ節構成で書く

## 作業ログ

### 現在地

- 済: 設計結果報告 0028（0028〜0032）と 0011 の計画書の形式を読む → 実装の現状を確認（result_ng の転用箇所の数、test_scope の assert 数、hook_payload、SKILL.md のエラー表、eval の SP-E）→ 判断点 8 件を決着 → 計画書 md + HTML → チケット 0033〜0037 を起票 → このチケットの記入
- 完了: commit.sh → ticket.sh complete 0031 → push → 計画の切れ目（opus 自己レビュー。人間レビュー要の代替）→ note → 0033 へ

### うまくいったこと

- 設計の結果報告に「0031 へ」の申し送りが残課題としてまとまっていたので、判断点の表がそのまま作れた
- 実装の現状を grep で数えてから書いたので、変更対象の「○か所」が具体的になり、参照更新一覧の検索語と期待件数を先に固定できた

### うまくいかなかったこと

- 計画チケット 0031 の目的文（0026 が書いた「実装 7 件」）は設計中に 9 件 + テストに増えた。計画チケットの目的文は「設計結果報告の残課題を読んで数える」と書く方がよい（0026 の反省として 3/3 へ）
- 前回 0011 の反省（自己レビューで R1〜R17）を踏まえ、今回はロックアウト対策を「最初の操作 + 復旧」の表にしたが、実機で提供コマンドを自分で変える手順は 0033 で初めて試すことになる

### 仕様からの逸脱

- 人間レビュー: 承認④により opus 自己レビューで代替（計画は work-defaults の既定「要」）
- 実行者が main（全体計画の方針）
- 計画書テンプレート（assets/ai-asset-implementation-plan.template.md）が無く、0011 の計画書と plan.template.html の節構成を型にした（E4。3/3）

### 判断と根拠

- G-6（次 の判定）・G-9（command -v git）は実装を変えない: 書き方と代替コマンドで避けられ、緩めると見逃しが増える
- create のエスケープは frontmatter に入る値だけ: frontmatter.sh の読み方（二重引用符の規則）に合わせる。本文は Markdown
- 見出し重複は ^### 見出し$ の行数 ≥ 2: 仕様どおり機械的。完了済みチケットは遡らない
- --session の検証は test_hook_common.sh: test-lib はテスト ID を持たない
- チケットは 4 枚 + 全体まとめ: 提供コマンドごとに「自分で変えて自分で使う」境目が 1 つずつあるので、コマンド単位で分けた（0033 commit-push / 0034 ticket / 0035 report-view + test-lib）。SKILL.md と eval は振る舞いを変えないので 1 枚に
- 全体まとめは手作業代替: finalize.sh は 3/3。承認⑥（issue コメント本文）は承認④の範囲外として停止する

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- 10_spec/skills/10-task-ai-asset-implementation-plan.md（固定順・テスト方針・参照更新一覧・ロックアウト対策の規定と DoD の型）・0011 の計画書（節構成の型）・20-common-step-report-view（plan.template.html の必須節・check-html.sh）・20-common-step-ticket（create × 5）
- rules/work-defaults.md（実装チケットの人間レビュー・敵対的レビューの既定）

### スコープ外で見つけたこと

- 0011 の計画書「保留した点」に残っていた 3 件（build-test と hook-test の重なり / SP- の重複 / プレースホルダ表記）は設計 0028〜0030 で解消済み
- wip/30_reports/0013 の実装結果レポートは今回の実装では追記せず、新しいレポート 0033 を作る（1 実装フェーズ = 1 レポート。統括レポートが両方を要約する）

### AI アセットに反映すべき内容

- 10-task-ai-asset-implementation-plan 仕様: 「提供コマンド自身を変えるステップには、変更後の自分のコマンドで自分をコミット・完了させる最初の操作を書く」を処理フローのロックアウト対策に 1 文 → 3/3
- 10-task-ai-asset-design-plan 仕様: 次の計画チケットの目的文に件数を固定で書かない（設計結果報告の残課題を読んで数える）→ 3/3

### 備考

- 起票スクリプト: wip/tmp/create-0033-0037.sh、HTML 本文: wip/tmp/plan-0031-body.html
