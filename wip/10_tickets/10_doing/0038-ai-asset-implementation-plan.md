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
completed_at: ""
base_sha: "a1bd3f2"
---

# 0038 AI アセット実装計画・追加: 自己レビュー P-1〜P-23 の反映（計画書 0031 とチケット 0033〜0037 の修正）

## 目的

wip/tmp/review-0031-findings.md の指摘のうち確度 0.5 以上の 20 件（P-1〜P-20）を計画書 wip/20_plans/0031-ai-asset-implementation-plan.md（+ HTML）と未着手チケット 0033〜0037 の目的・DoD・allow に反映し、0.5 未満の P-21（保留に記録）・P-22（HTML の参照更新表）・P-23（統括レポートに DoD × 根拠を写す）も直す。実装には入らない

## DoD

- [ ] P-1・P-2・P-7・P-8・P-20: 0033 の allow.write が commit-push/scripts/** + テンプレート 2 本 + ticket/scripts/tests/**（TICKET-T10 の期待値 CP004 → CP008 の更新）に直り、DoD の push を「完了コミット直後（doing 空）に push.sh」に改め、CP007 4 か所・CP-T04 の -m 値なし assert の CP-T08 への移設が計画とチケットに書かれている（根拠: ）
- [ ] P-5・P-6・P-14・P-15・P-16: 0034 の作業内容が yaml_escape の新設（sed_escape は流用しない）になり、TK004 の終了 2 の 15 か所 + TK001 誤用 1 か所（L126）を TK008 へ、TICKET-T10 に index の assert、判断点に executor（引用符なし・語彙固定でエスケープ対象外）と改行 → 空白が書かれ、参照更新一覧の検索語が行末に依存しない形（期待値: TK004 は終了 1 の 6 件）になっている（根拠: ）
- [ ] P-11・P-12・P-13・P-18: テスト方針表に SS-T04（nop の LOGGER_ROOT / FATAL: 終了 2 / deny の WF009）・TR-T04（timeout 不在 → TR005 終了 2）・FR-T05（計数 PATH で 0 回・list / inline キーの生文字列）の追記が 0035 に割り付けられ、HK-T15 の数が 93 assert + 冒頭コメント（残存 HK-T11 は 21 件）になっている（根拠: ）
- [ ] P-3・P-9・P-10・P-17: 参照更新一覧が実測件数（SP-E 7 行 / 2 ファイル、AC-E01〜03、RV001〜007 2 か所、CP001〜006 1、TK001〜007 1、feature-mr SKILL.md の CP005 / CP006）で書かれ、0036 の allow.write に spec / ai-asset-creator / feature-mr の SKILL.md が入り A9 が 7 本になっている（根拠: ）
- [ ] P-4・P-19・P-23: 0037 の allow.ops が overall-summary の上限の語彙（read, remote-read, remote-write:issue-create, remote-write:mr-edit, remote-write:mr-comment, remote-write:attach, remote-write:push, remote-write:draft-ready, merge-base）から選ばれ、DoD に 10-task-overall-summary 仕様の手順 2（別 issue 起票または「追加の反映なし」）・手順 6（HTML 添付コメントと本文追記）・衝突確認の位置（統括レポートの前）・統括レポートへの DoD × 根拠の転記が入っている（根拠: ）
- [ ] P-21・P-22: 計画書の保留した点に「TICKET-T05 に create のエスケープ往復は仕様に無い（次の設計で仕様側を揃える）」があり、HTML に参照更新一覧の表（修正後の値）が入って check-html OK（根拠: ）

## 作業内容

- wip/tmp/review-0031-findings.md を読み、計画書 md → HTML → チケット 0033〜0037（未着手。frontmatter の allow と本文を直接編集）の順に直す

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
