---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0017", "0018"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/skills/20-common-step-ai-asset-creator/assets/**", ".claude/skills/20-common-step-shell-script/**", ".claude/skills/20-common-step-ticket/**", ".claude/skills/20-common-step-commit-push/**", ".claude/skills/20-common-step-report-view/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:32:56+09:00"
completed_at: "2026-09-01T13:36:22+09:00"
base_sha: "fa273a4"
---

# 0019 AI アセット実装 S4-1: SKILL.md 4 本（shell-script / ticket / commit-push / report-view）

## 目的

スクリプトを持つ共通ステップスキル 4 本の SKILL.md を仕様の処理フロー・参照ナレッジと 1:1 で書く。規約の再掲はしない。

## DoD

- [x] `20-common-step-ai-asset-creator/assets/skill.template.md` / `eval.template.md` が同仕様 OUT ひな形のとおりで、SKILL.md 4 本はこの雛形から作られている（根拠: `20-common-step-ai-asset-creator/assets/skill.template.md` / `eval.template.md`。4 本の節構成（frontmatter + 目的 / 手順 / 参照 / エラー時の対処）が雛形と同じ）
- [x] 4 本の SKILL.md が frontmatter（name / description に発火条件）と本文（目的 / 手順 / 参照 / エラー時の対処）を持ち、各仕様の「処理フロー」「OUT ひな形」「参照ナレッジ」との対応表が作業ログにある（根拠: 作業ログ「判断と根拠」の対応表、レポート 0019 節のアセット表）
- [x] 提供コマンドの起動はすべてルート相対表記（`bash .claude/skills/.../scripts/x.sh`）で書かれている（共通仕様 §7-8）（根拠: `grep -nE 'bash (\./|/)[^ ]*\.sh|bash [a-z-]+\.sh'` 4 本で 0 件）
- [x] 各 SKILL.md が Read の上限を超えない長さで、規約（bash・logger・frontmatter）を再掲せず参照している（根拠: 4 本とも 48〜61 行・5.3〜6.7 KB。規約は `rules/`・仕様への参照のみ）
- [x] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: `grep -nE '\{\{[A-Z_]+\}\}|TODO|TBD'` 4 本で 0 件、frontmatter に name / description）
- [x] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: 検索語 5 語で `.claude/skills/20-common-step-*` にヒットなし）
- [x] `git diff --stat <base_sha>` が許可範囲内（根拠: 変更は許可範囲の 5 スキル配下と `wip/` のみ）
- [x] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: レポートの 0019 節（アセット表・テスト結果・検査結果・D-19）、0018 の id 件数の誤記を訂正）

## 作業内容

- 順: `skill.template.md` / `eval.template.md` → SKILL.md 4 本。土台は参考実装の対応スキル（Q6）。新仕様の要求差分を仕様から埋める
- 完了は `ticket.sh complete`（境目 B 以降）

## 作業ログ

### 現在地

- 済: 着手（`ticket.sh start 0019`）
- 済: skill.template.md / eval.template.md、SKILL.md 4 本、対応表、レポート追記。完了は `ticket.sh complete 0019`

### うまくいったこと

- 4 本の SKILL.md が書き上がった直後にセッションの利用可能スキル一覧へ現れ、description の発火条件がそのまま機能した

### うまくいかなかったこと

- 0018 の試し埋めの id 件数をチケットに 15 と書いたが実測は 11（レポートで訂正。完了済みチケットは直さない）

### 仕様からの逸脱

- D-19（レポート）

### 判断と根拠

- 対応表（仕様の節 → SKILL.md の節）:
  - shell-script: 処理フロー 1〜6 → 手順 1〜7 / OUT ひな形 → 参照（雛形・ライブラリ）/ Script 処理「読み込み行」→ 手順 2 / 「run-tests.sh」→ 手順 5 とエラー表 / 参照ナレッジ → 参照
  - ticket: Script 処理 create / start / complete / cancel / next → 手順 2 / 3 / 4 / 5 / 1 / OUT ひな形 → 手順 2 と参照 / 呼出条件（再開）→ 手順 6 / エラー識別子 → エラー表 / 参照ナレッジ → 参照
  - commit-push: Script 処理 commit.sh 1〜6 → コミット 1〜5 / push.sh 1〜4 → push 1〜4 / OUT ひな形（除外パターン・スキップ記録）→ 参照と push 2 / エラー識別子 → エラー表
  - report-view: 処理フロー 1〜6 → 手順 1〜6 / OUT ひな形（規約・視覚語彙・付録）→ 手順 1・3 と参照 / Script 処理 → 手順 4 とエラー表 / 参照ナレッジ → 参照
- 手順の中で規約（bash・logger・frontmatter・除外パターンの中身）を再掲せず、置き場と参照だけを書いた

### 拒否・確認・迂回の記録

- 無し

### 使った AI アセットと効き目

- `skill.template.md`（作った直後に 4 本の骨格として使用）。参考実装の `task-ai-asset-creator/SKILL.md`（house style の確認）

### スコープ外で見つけたこと

- 無し

### AI アセットに反映すべき内容

- 無し（この 4 本は仕様どおり。仕様側への申し送りは各実装チケットの D-3〜D-18 に集約済み）

### 備考

- 無し
