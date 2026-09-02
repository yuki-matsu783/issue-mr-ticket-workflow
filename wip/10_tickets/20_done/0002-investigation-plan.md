---
type: ticket
ticket_type: investigation-plan
predecessors: ["0001"]
executor: main
human_review: {required: false, reason: "計画書は調査結果と一緒に見れば足りる"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T09:20:57+00:00"
completed_at: "2026-09-02T09:24:08+00:00"
base_sha: "5ea0dc0"
---

# 0002 調査計画: 置き場依存箇所と #20 の 5 論点の現状

## 目的

apl/ 配下への置き場変更で影響を受ける記述と、issue #20 の 5 論点それぞれの現状を洗い出すための調査の問いを決め、調査実施チケットと次の計画チケットを起こす

## DoD

- [x] 調査計画書が wip/20_plans/ にあり、調査の問いが観点ごとに列挙されている（根拠: wip/20_plans/0002-investigation-plan.md「調査観点」Q1〜Q9）
- [x] 問いが issue #20 の受け入れ条件 1〜11 のどれに効くか対応づけられている（根拠: 同「調査観点」表の右列。条件 1〜6・8〜10 を網羅。条件 7・11 は設計フェーズで決める事項のため調査対象外）
- [x] 調査実施チケットが起票されている（根拠: wip/10_tickets/00_todo/0003-investigation.md）
- [x] 次の計画チケット（ai-asset-design-plan）が起票されている（根拠: wip/10_tickets/00_todo/0004-ai-asset-design-plan.md）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。調査計画書と HTML ビューを作り、チケット 0003 / 0004 を起票した

### うまくいったこと

- HTML ビューをテンプレートから生成するスクリプトをスクラッチパッドに用意した。以降 11 本の計画書・レポートで使い回せる
- 問いを受け入れ条件に対応づけたので、調査の網羅性を条件側から検算できる

### うまくいかなかったこと

- 10-task-investigation-plan のスキル本体が無く、テンプレート `assets/investigation-plan.template.md` も存在しない。仕様書の「OUT ひな形」の節の表から md を起こした

### 仕様からの逸脱

### 判断と根拠

- 調査実施を 1 枚のチケットにまとめた。Q1〜Q9 はいずれも読み取りのみで、Q1 の結果が Q2〜Q9 の対象を絞るなど観点をまたぐ突き合わせが多いため
- 受け入れ条件 7（置き場の定義そのもの）と 11（DDR）を調査対象から外した。どちらも調査で分かることではなく設計で決める事項のため

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

- `20-common-step-report-view` の plan.template.html と check-html.sh: 検査 7 項目を一度で通過した
- `20-common-step-ticket` の ticket.sh: create / start とも問題なし

### スコープ外で見つけたこと

- 計画タスク用の md テンプレート（`assets/*-plan.template.md`）がどのスキルにも無い。HTML テンプレートだけが存在する。10-task-* スキル本体の作成時（issue #10）に揃える必要がある

### AI アセットに反映すべき内容

- 計画タスク用の md テンプレートが無い件は本 issue の範囲外。フィードバック計画で別 issue の要否を判断する（現時点で本 issue に反映すべき内容は 0 件）

### 備考
