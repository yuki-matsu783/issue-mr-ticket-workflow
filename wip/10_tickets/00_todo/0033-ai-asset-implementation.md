---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0031"]
executor: main
human_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。承認④により切れ目で opus 自己レビューに代替"}
adversarial_review: {required: true, reason: "振る舞いが変わる（work-defaults の既定）。切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/assets/**", ".claude/skills/20-common-step-requirement/assets/**", ".claude/skills/20-common-step-commit-push/scripts/**", ".claude/skills/20-common-step-ticket/scripts/tests/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0033 AI アセット実装: テンプレート 2 本と commit.sh / push.sh の識別子（CP007 / CP008）と CP-T08（wip/20_plans/0031-ai-asset-implementation-plan.md の S1・S2-1・S3-1）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S1（skill.template.md の冒頭段落ガイド、requirements.template.md の小節の許容 1 行）と S2-1 / S3-1（commit.sh の CP007 4 か所（-m 値なし・--amend / --no-verify・不明オプション・ルートに移れない）・CP008 2 か所、push.sh の手順 0 で CP007 5 か所、CP005 / CP006 を本来の条件に。テスト先行で CP-T08 を新設し、CP-T04 の -m 値なし assert を CP007: に直して CP-T08 へ移し、CP-T03 / CP-T06 の追記分の ID を揃え、test_ticket.sh の TICKET-T10 が期待する CP004: 3 assert を CP008: に更新する）を実装する。push は完了コミット直後（doing 空）に行う。実装結果レポート wip/30_reports/0033-ai-asset-implementation.md を作る

## DoD

- [ ] skill.template.md が ai-asset-creator 仕様 OUT ひな形のとおり（frontmatter は name / description の 2 項目、冒頭段落は禁止事項の要約とガイドで説明）、requirements.template.md が requirement 仕様 処理フロー 3 のとおり（メインフローの小節の許容がガイドにある）になっている（根拠: ）
- [ ] commit.sh が仕様 commit.sh 2・5 のとおり（-m の値なし・不明オプション・ルートに移れない → CP007 終了 2、git commit 自体の失敗 → CP008 終了 1、CP001 は対象の指定の誤りだけ）、push.sh が仕様 push.sh 0 のとおり（引数・環境の誤り → CP007 終了 2、CP005 は検査未充足だけ、CP006 はリモート拒否だけ）になっている（根拠: ）
- [ ] 機械テスト CP-T08（新）が通り、CP-T04 の -m 値なし assert が CP007: 期待で CP-T08 に移り、CP-T03 / CP-T06 に 0025 で足したケース（ディレクトリ・symlink・実パスの除外 / HEAD の版だけ）の ID が揃い、test_ticket.sh の TICKET-T10 の期待値が CP008: になっている（実行方法: run-tests.sh --ids で全件）。テストは実装より先に書いて失敗を確認した記録が作業ログにある（根拠: ）
- [ ] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: ）
- [ ] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: ）
- [ ] 参照更新の検索で旧記述が 0 件: result_ng 004 "git commit が失敗（commit.sh）、result_ng 005 "引数 と result_ng 006 の環境誤り 4 か所（push.sh）（根拠: ）
- [ ] 変更後の commit.sh で自分の成果物をコミットできた（ロックアウト対策の最初の操作。止まった場合は復旧手順と原因を作業ログに）。push は完了コミット直後（doing 空）に push.sh で行う（作業中は項目 2 で止まるため DoD の対象外）（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: ）

## 作業内容

- 計画の変更対象 A1〜A4 と仕様の該当節を読み、20-common-step-ai-asset-creator → 20-common-step-shell-script の手順で変更する（既存構成に合わせ差分を小さく）
- テスト先行: CP-T08 を test_commit.sh / test_push.sh に足して失敗を確認 → 実装 → CP-T04 の移設と test_ticket.sh の TICKET-T10 の期待値更新 → 全件

## 作業ログ

### 現在地

- 未着手

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
