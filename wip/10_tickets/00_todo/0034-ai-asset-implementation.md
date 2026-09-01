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
started_at: ""
completed_at: ""
base_sha: ""
---

# 0034 AI アセット実装: ticket.sh の TK008・create の YAML エスケープ・complete の見出し重複検査と TICKET-T12（wip/20_plans/0031-ai-asset-implementation-plan.md の S2-2・S3-2）

## 目的

計画 wip/20_plans/0031-ai-asset-implementation-plan.md の S2-2 / S3-2: ticket.sh の TK004 の終了 2 転用 15 か所と TK001 の誤用 1 か所（必須引数の欠落）を TK008（終了 2）に付け替え、yaml_escape を新設して create で frontmatter に入る値（理由 2 つ・allow の要素・predecessors。executor は語彙固定で対象外）を YAML の二重引用符の規則（バックスラッシュと二重引用符のエスケープ、改行は空白）でエスケープし（sed_escape は sed 用なので流用しない）、complete 3 に固定見出しの重複検査を足す。テスト先行で TICKET-T12 を新設し TICKET-T03 / T05 / T10（拒否後に index が空）に追記する。0034 自身の complete を新版で行うのが最初の実機確認

## DoD

- [ ] ticket.sh が仕様 create 1・3 / complete 3 / 識別子表 TK004・TK008 のとおりになっている（TK004 は番号で指定したチケットが期待する置き場に無いときだけ、TK008 は引数・環境の誤りで終了 2）（根拠: ）
- [ ] 機械テスト TICKET-T12（新）が通り、TICKET-T03（見出し重複の列挙）・TICKET-T05（記号入りの理由と glob の往復。& や | が変換されないこと）・TICKET-T10（commit.sh 拒否後に git diff --cached が空）の追記分が通る（実行方法: run-tests.sh --filter 'test_ticket*' --ids）。テスト先行の記録が作業ログにある（根拠: ）
- [ ] run-tests.sh --ids が全件 PASS（既存 14 本 / 55 件 + 追加分）で、結果（本数・ID 数）が作業ログにある（根拠: ）
- [ ] プレースホルダ（{{名前}}・TODO・TBD。assets/*.template.* は対象外）と frontmatter の検査が 0 件で、結果がコマンドと件数で作業ログにある（根拠: ）
- [ ] 参照更新の検索で旧記述が 0 件: ticket.sh の result_ng 004 の全件を数えて終了コード 2 の行が 0 件（TK004 は終了 1 の 6 件だけ残る）、result_ng 001 の必須引数の行が 0 件（TK001 はプレースホルダ残存の 1 件だけ残る）（根拠: ）
- [ ] 変更後の ticket.sh で 0034 自身を complete できた（見出し重複検査を含む。止まった場合は判定の正誤と復旧を作業ログに）（根拠: ）
- [ ] 実装結果レポート wip/30_reports/0033-ai-asset-implementation.md（+ HTML、check-html.sh OK）にこのチケットの節（作成・更新したアセット × 仕様の節 / テスト結果 / 検査結果 / 仕様からの逸脱）がある（根拠: ）

## 作業内容

- 計画の変更対象 A5 と仕様の該当節を読み、20-common-step-shell-script の手順で変更する。yaml_escape（改行 → 空白、バックスラッシュと二重引用符のエスケープのみ）を新設して create の値に適用し、sed_escape は yaml_escape + sed メタ文字の 2 段に組み替える。見出し重複は LOG_HEADINGS ごとに ^### 見出し$ の行数を数える
- テスト先行: TICKET-T12 と T03 / T05 / T10 の追記を先に書いて失敗を確認 → 実装 → 全件。push は完了コミット直後（doing 空）に

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
