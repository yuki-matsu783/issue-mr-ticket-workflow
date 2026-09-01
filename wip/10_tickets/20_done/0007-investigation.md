---
type: ticket
ticket_type: investigation
predecessors: []
executor: main
human_review: {required: true, reason: "調査結果のレビュー指摘への対応（承認④により opus 自己レビューで代替。回数上限に達したため 0007 の切れ目では再実施しない）"}
adversarial_review: {required: false, reason: "上限 1 回を消化済み"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-01T02:29:37Z"
completed_at: "2026-09-01T02:33:19Z"
base_sha: "bb2a527"
---

# 0007 調査実施（追加）— 敵対的自己レビュー F1〜F11 への対応

## 目的

調査結果レポート `wip/30_reports/0003-investigation.md` を、敵対的自己レビュー（PR #7 のコメント参照）の指摘 F1〜F11 に沿って修正・補強し、AI アセット設計計画（0006）と AI アセット実装計画が判断できる状態にする。

## DoD

- [x] F1: レポートが `10-task-investigation-exec` の節構成に従う — 「確かめられなかったこと」節があり、Q1〜Q6 の各小節に結論の性質（良 / 注意 / 問題）とレビューの重み（◆ / ◇ / ・）があり、「想定と異なった点」に作業ログの事実が書かれている（根拠: レポート「確かめられなかったこと」節（6 行）、Q1〜Q6 各節の先頭行「結論の性質 / レビューの重み」、「想定と異なった点」6 項目）
- [x] F2・F8: テスト 32 本の実行と settings.json 変更の試みが、本チケットの作業ログ「仕様からの逸脱」「拒否・確認・迂回の記録」に実コマンド・出力付きで記録され、`dump-hook-input.sh` の顛末が書かれている。調査計画 / exec 仕様 / §8 の矛盾が D20 として D 表に追加されている（根拠: 本チケット作業ログ「仕様からの逸脱」「拒否・確認・迂回の記録」、レポート D 表 D20）
- [x] F3・F6・F9・F10: D16・D14・D19・D9・D7・Q2 の記述が訂正されている（D16 は二重管理を避ける形、D14 は §8 初期値の変更、D19 は採番と提供コマンド識別、D9 / Q2 / D7 は推奨 + 比較軸の形）（根拠: D 表 D16・D14・D19・D9・D7 の見立て列、Q2「答え」1 行目「推奨: …（決定は実装計画）」）
- [x] F4: 入れ子 frontmatter パーサの置き場と共有方法が「実装計画の判断点」として 2 案 × 比較軸（変更量・fork 回数・許可 glob・二重実装の回避）で書かれている（根拠: レポート「実装計画の判断点（調査では決めない）」表 1 行目: (a) hooks/lib / (b) shell-script/scripts × 変更量・fork 回数・許可 glob・二重実装）
- [x] F5: 「受け入れ条件との対応（この調査がカバーした / しなかった条件）」表と、Q6（ルール 4 本・SKILL.md 9 本の土台、テスト ID の無い仕様 5 本、eval の土台）が追記されている（根拠: レポート「受け入れ条件との対応（この調査がカバーした範囲）」表 7 行、「Q6 ルール・スキル本文・eval の土台」節。テスト ID 0 件は grep で実測）
- [x] F7: T5 が transcript の `tool_use` 記録で確認され、`tool_input` のキー一覧が実物どおり（`description` を含む）になり、フック stdin 固有フィールドだけが 2/3 送りになっている（根拠: レポート Q3「実機確認の結果」: `78d6705f-….jsonl` の PowerShell `tool_use` 2 件、キー集合 `command` / `description`（Bash 541 件と同一）。フック stdin 固有フィールドだけ「確かめられなかったこと」へ）
- [x] F11: 付録の食い違い 5 件（A §2-D・§2-G、B §3-5・§3-7・§3-8）が「実装時の申し送り」一覧に載っている（根拠: レポート「実装時の申し送り」表 H1〜H6）

## 作業内容

- レビュー結果（PR #7 の note コメント）を読み、指摘ごとにレポートを修正する
- transcript の `tool_use` 記録と参考実装の rules / skills / evals を読み取りだけで確認する
- 完了（手作業代替）

## 作業ログ

### 現在地

- 完了（未完了の項目なし）

### うまくいったこと

- 敵対的自己レビュー（opus）が根拠の抜き取り検証 15 件と仕様の突き合わせを行い、形式の不備（節構成・視覚語彙）と運用の逸脱（テスト実行・ops 超過）を拾った。人間レビューの代替として機能した
- T5 は transcript の一次情報（機構自身が `transcript.sh` で読む記録）で書き込みゼロで確認できた
### うまくいかなかったこと

- 調査実施 3 枚とも、レポートの節構成（確かめられなかったこと・性質・重み・想定と異なった点）を仕様どおりに書いておらず、追加チケット 1 枚分の手戻りになった。手作業代替でテンプレート実体（report.template.md）が無いことが一因
- 完了済みチケット 0004・0005 の作業ログは直せない（完了済みを戻さない）ため、逸脱の記録はこのチケットに残す
### 仕様からの逸脱

- **チケット 0004（完了済み）の逸脱の記録**: 調査計画は参考テスト「1 本」の実行を計画したが、リサーチエージェントが agent-workflow 6 本 + MR-driven 26 本の計 32 本と WSL 対照実行まで行った。実行コマンド例: `bash 参考ディレクトリ/MR-driven-workflow/.claude/scripts/test/test_command_position.sh` → `passed=117 failures=1`（13.2 s）、`bash 参考ディレクトリ/agent-workflow/.claude/hooks/tests/test-workflow-entry.sh` → `結果: PASS=45 FAIL=0`（28.6 s）、他は付録 C §2 の表。`10-task-investigation-exec` の禁止事項「テストの実行」と §8 初期値 `investigation.ops`（`read, remote-read`）を超えており、0004 の frontmatter `ops` に `build-test` を宣言したのは上限を広げる誤り（宣言は絞る役）。書き込みは一時ディレクトリと `wip/tmp/` のみで、リポジトリへの副作用は無い。仕様間の矛盾として D20 に載せた
- 手作業代替（ticket.sh 未実装）
### 判断と根拠

- 指摘 11 件をすべて 1 枚の追加チケットで処理した（1 指摘 1 項目で 1 チケットにまとめてよい — ワークフロー仕様 手順 4-4）
- 敵対的レビューは上限 1 回に達したため、この切れ目では再実施しない。残る懸念は 0006 の入力として扱う
- 敵対的レビューの F5 にあった「参考実装に eval 資産は無い（`find -ipath \"*eval*\"` が 0 件）」は誤りで、agent-workflow に `evals/evals.json` が 7 本以上ある（`ls 参考ディレクトリ/agent-workflow/.claude/skills/*/evals/` で実測）。F5 の残り（テスト ID 不在 5 本・ルールとスキル本文の土台が未調査）は妥当なので Q6 として追記した
### 拒否・確認・迂回の記録

- **チケット 0005（完了済み）の記録の補完**: `.claude/settings.json` への一時フック登録は (1) Bash `cp .claude/settings.json wip/tmp/settings.json.orig && jq '. + {hooks: …}' … > .claude/settings.json` → 「Permission for this action was denied by the Claude Code auto mode classifier」、(2) Edit ツール（`hooks` キーの追加）→ 同じ拒否。迂回せず中止。確認コマンドと結果: `git status --short` → `.claude/settings.json` を含まない（当時の出力は wip 配下のチケット移動のみ）、`git log --oneline -- .claude/settings.json` → `ffafc2f 初期コミット` のみ。一時フック `wip/tmp/dump-hook-input.sh` は作成して単体動作（stdin を `logs/tmp/` に保存）を確認した後、登録できないと分かった時点で削除した（`logs/tmp/` も削除）
### 使った AI アセットと効き目

- `10_spec/skills/10-task-investigation-exec.md`（OUT ひな形・固有手順）: 最初の 3 枚で読み落としていた。仕様は足りている。手作業代替でテンプレートが無いと節構成が守られにくい → report-view のテンプレート実体を早く作る価値が高い
- 敵対的レビューのプロンプト（観点 6 つ + 出力形式 + confidence）: 足りた。`assets/adversarial-review-prompt.template.md` の土台にできる
### スコープ外で見つけたこと

- なし（レビュー指摘はすべて本チケットで対応）
### AI アセットに反映すべき内容

- D20（調査でのテスト実行の可否: 計画 / exec 仕様 / §8 の整合）と D21（`.claude/**` の一時変更を調査で計画しない）を 0006 で判定する
- レポートの必須節を空にしない運用（D16 の追記）と、付録ファイルの命名規約（`<連番>-<種類>-appendix-<記号>.md`）を report-view 仕様へ
- 敵対的レビューのプロンプト構成（観点・出力形式・confidence・「問題なしと判断した点」の明記）をエージェント仕様のテンプレートに反映
### 備考
