---
type: ticket
ticket_type: feedback-plan
predecessors: ["0027", "0028", "0029", "0030", "0031"]
executor: main
human_review: {required: true, reason: "基準どおり（後続フェーズの要否は人間の判断）"}
adversarial_review: {required: false, reason: "基準どおり（棚卸しと要否の判断で、正史の変更を伴わない）"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0032 実測結果と仕様からの逸脱の棚卸し、フェーズ 6 の要否

## 目的

フェーズ 4 の実測（4c）と実装で判明した仕様との食い違いを棚卸しし、後続フェーズ（仕様への書き戻しと DDR）の要否と範囲を決める

## DoD

- [ ] 0027〜0031 の作業ログ「仕様からの逸脱」と「AI アセットに反映すべき内容」を集約した棚卸し表があり、各行に「どの文書のどこを直すか」「DDR にするか」が書かれている（根拠: ）
- [ ] フェーズ 4c の実測 10 項目（T2・T3・T4・T5・T7・T9 と tool_response.status・agent_type・worktree・実行時間）それぞれについて、共通仕様 §12 の該当行を消せるか残すかが決まっている。T5 まで含めて §12 を空にできるかを判定した（根拠: ）
- [ ] 受け入れ条件 3・5・6 が求める書き戻しの範囲が確定し、フェーズ 6 のチケット（ai-asset-design 系）を起こすか省略するかが決まっている。省略する場合は理由が書かれている（根拠: ）
- [ ] 実装フェーズで DDR にできなかった決定（実装フェーズは .claude/docs/** に書けない）が列挙され、DDR の番号帯（i0009-63 以降）が割り当てられている。少なくとも次の 6 件が入っている: SC_TARGETS の形（仕様 §8 の `[]` を外す）と SC_CLASS の値集合（`write` / `opaque` を §8 の表に足す）／§2 の作業ツリー解決に「候補が HOOK_ROOT の worktree であることを確かめる」を足す／.claude/rules/markdown-docs.md と ai-asset-authoring.md の 1:1:1 の整備（フェーズ 6 または #10）／4c プローブが必要だったこと（decisions.jsonl の 10 キー固定と、systemMessage の到達を業務条件から切り離して測れないこと）／**§1 の表の review-state / merge-state を jq の 2 回目（`hook_read_state`）へ移す**／**DDR 候補「bash のパターン照合はパターンが長いと壊滅的に遅い」**（`${s%%"$m"*}` が 4000 字で 58 秒。0027 の実測）（根拠: ）
- [ ] 次のチケット（フェーズ 6 の ai-asset-design、または省略ならフェーズ 7 の overall-summary）を 1 枚起こし、predecessors に 0027〜0031 を入れた（根拠: ）
- [ ] 計画書 wip/20_plans/0032-feedback-plan.md と HTML ビューを作り、check-html.sh が OK を返した（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 6 に従う
- 全体計画の「#10（3/3）への申し送り」5 件が、フェーズ 7 の issue コメントで引き継がれる前提を確かめる（このフェーズでは扱わない）
- フェーズ 7 を通す手は第 1 案（WORKFLOW_STATE_GUARD_ENFORCE=0 の新セッション）を既定として確定済み。フェーズ 7 の直前に人間と最終確認する旨を計画書に書く

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
