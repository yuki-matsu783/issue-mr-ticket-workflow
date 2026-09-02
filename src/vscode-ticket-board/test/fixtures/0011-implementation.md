---
type: ticket
ticket_type: implementation
predecessors: ["0010"]
executor: main
human_review: {required: false, reason: "全体計画の方針の差分 4 により、人間レビューはワークごとの敵対的レビューに置き換える"}
adversarial_review: {required: true, reason: "振る舞いが変わるため基準どおり要。担い手は差分 4 により汎用サブエージェント"}
allow:
  write: ["src/**", "wip/**"]
  ops: ["read", "build-test"]
started_at: "2026-09-02T06:19:38+00:00"
completed_at: "2026-09-02T06:22:22+00:00"
base_sha: "7d207ae"
---

# 0011 拡張ホスト層の実装と README（extension / board-panel）

## 目的

ticket.sh が実際に書き出すチケットの写し。テンプレートが変わって誤検知が出たら気づけるようにする。

## DoD

- [x] 本文に見出しがある（根拠: 上の H1）

## 作業ログ

### 現在地

- 完了

### 備考

作業ログにシェル片を貼ることがある。フェンスの中の見出しをタイトルに採らないこと。

```sh
# 9999 これは見出しではない
bash .claude/skills/20-common-step-ticket/scripts/ticket.sh complete 0011
```
