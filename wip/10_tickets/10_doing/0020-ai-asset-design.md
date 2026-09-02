---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0019"]
executor: sub-opus
human_review: {required: true, reason: "正史（要件・仕様）の変更（承認④により opus の敵対的自己レビューで代替）"}
adversarial_review: {required: true, reason: "基準どおり（中核の定義に触る）"}
allow:
  write: [".claude/docs/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:17:07+09:00"
completed_at: ""
base_sha: "1050d4b"
---

# 0020 レビュー指摘: 制御方式の穴（MCP・削除・設定破損・WF801 の到達）（R4・R5・R13・R20・R21・R23・S1）

## 目的

決めたつもりで決まっていない条件分岐を埋める。特に PreToolUse の additionalContext が「ツール結果の隣」に届くという公式の記述により、WF801 を PreToolUse Agent に移した根拠（起動前に伝える）が崩れているので、17 行目の登録の可否を決め直す

## DoD

- [ ] PreToolUse の additionalContext が「next to the tool result」に届く（hooks.md:988）事実を踏まえ、WF801 の本線を決め直した。17 行目の登録を維持するか案 (a)（事後通知に一本化・16 行）に戻すかが結論付けられ、要件「サブエージェントが動き出す前に伝える」が達成できる形に直っているか、達成できないなら要件の表現が実態に合わせて直っている（S1）（根拠: ）
- [ ] MCP 経由のリモート書き込み（mcp__ の issue 作成・コメント・MR 編集）を強制するかどうかが決まり、強制するなら workflow-entry と workflow-guard の matcher と tool_class の分類に、強制しないなら §13 意図的な緩和に理由付きで書かれている（R4）（根拠: ）
- [ ] workflow-state-guard が MCP ツールに対して draft 解除以外を許可する分岐を持ち、全 MCP 呼び出しが WF309 に落ちる過剰拒否が解消されている。負のコントロールのテスト観点がある（R5）（根拠: ）
- [ ] scope-limits.json が読めないときの workflow-state-guard の振る舞いが定義され、workflow-guard が用意した WF210 の復旧経路（設定ファイル自身への ask 付き書き込み）が state-guard の deny で潰れないことがテスト観点で固定されている（R13）（根拠: ）
- [ ] wip/10_tickets/10_doing/** と 20_done/** の削除（rm / git rm / mv の元）が塞がれているか、塞がない場合は §13 に理由が書かれている（R23）（根拠: ）
- [ ] WF801 の再掲（subagent-stop-check）に条件が付き、通常経路で同じ不一致が 2 回通知されない。SP-T05 の期待値が合っている（R20）（根拠: ）
- [ ] subagent_type が task-executor 以外（adversarial-reviewer・Explore 等）のときに WF801 が誤発報しないことが制御方式に書かれ、負のケースのテスト観点がある（R21）（根拠: ）
- [ ] 決定の経緯が DDR i0009-26〜32 の範囲に残っている（根拠: ）

## 作業内容

- 指摘の原文は wip/30_reports/0015-ai-asset-design-appendix-A.md を参照する
- 公式の確認は wip/tmp/hooks.md を grep -n で読む（WebFetch を使わない）

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
