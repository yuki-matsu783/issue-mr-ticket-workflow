---
type: ticket
ticket_type: feedback-plan
predecessors: ["0022"]
executor: main
human_review: {required: true, reason: "計画の差し戻し（承認④により opus 自己レビューで代替。切れ目の note に追記）"}
adversarial_review: {required: false, reason: "計画書"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-01T16:31:04+09:00"
completed_at: ""
base_sha: "22a44e5"
---

# 0027 フィードバック計画・追加（自己レビュー指摘 1〜12 の反映）

## 目的

0022 の opus 自己レビュー（wip/tmp/review-0022-findings.md、PR #7 の note）の confidence >= 0.5 の 12 件を計画書に反映する: 件数の訂正（51 → 実数）と A9 の二重計上、「26 件すべて docs」の書き分け、B7 と E2 / E3 / E5 の振り分け基準の統一、md と HTML の節構成の一致と OUT ひな形 vs plan テンプレートの候補化、D-1〜D-34 の表記、G4 の 4 本目と関連ドキュメント節、G1 の provided、G10 の罠 3 件、D 表の 2/3 行き 3 件、H 表の 2 軸と観点の語、作業ログの重複見出し（4 枚）の候補化、レビュー指摘の取得手段（gh api --paginate）、0026 の allow.ops と executor の理由

## DoD

- [ ] 計画書 wip/20_plans/0022-feedback-plan.md の候補の総数・区分ごとの件数が grep の実数と一致し、A9 の二重計上が解消され、「この MR」の内訳が docs のみ / docs + アセット本体で書き分けられている（根拠: ）
- [ ] 指摘 3・4・5・7・8・9・10・11・12 の候補（B7 の統一、OUT ひな形 vs plan テンプレート、G4 の 4 本目と関連ドキュメント節、G1 の provided、G10 の罠、D 表 3 件、H 表の 2 軸、重複見出し）が表に追加または修正され、観点の語が 4 語に揃っている（根拠: ）
- [ ] HTML が md と同じ節構成（対象 / 確認した記録の範囲 / 改善候補の一覧 / 合意 / 起票した issue / 後続フェーズの決定 / 検証 / チケット / 保留した点）で、plan テンプレートの必須節も満たし check-html.sh OK（根拠: ）
- [ ] 確認した記録の範囲のレビュー指摘の取得が gh api --paginate（issue コメント / インライン / レビュー）で裏づけられ、逸脱 D-1〜D-34 の表記が 4 箇所とも直っている（根拠: ）
- [ ] 未着手チケット 0026 の allow.ops に remote-read があり、executor main の逸脱理由が計画書のチケット表に書かれている。PR #7 の request コメントの件数が訂正されている（根拠: ）

## 作業内容

- review-0022-findings.md の指摘 1〜12 を順に計画書へ反映し、HTML を md の節構成で作り直す

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
