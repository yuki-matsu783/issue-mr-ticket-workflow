---
type: ticket
ticket_type: investigation-plan
predecessors: ["0001"]
executor: main
human_review: {required: false, reason: "計画書は調査結果と一緒に見れば足りる（基準どおり）"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read"]
started_at: "2026-09-02T05:23:24+00:00"
completed_at: "2026-09-02T05:27:10+00:00"
base_sha: "3e96f2f"
---

# 0002 チケットボード拡張の調査計画

## 目的

設計の前提を固めるため、チケット Markdown の実形・拡張の実行環境・既存機構との境界について答えるべき問いを列挙し、調査チケットに落とす

## DoD

- [x] 調査計画書 wip/20_plans/ に、問い・調べ方・想定される答えの使い道が書かれている（根拠: wip/20_plans/0002-investigation-plan.md の「調査観点」6 問・「対象と方法」表・「成果物の形」）
- [x] 調査計画書の HTML ビューが check-html.sh を通っている（根拠: OK: 検査 7 項目すべて通過（id 11 件 / リンク 8 件を確認。テンプレート: plan））
- [x] 調査実施チケット（investigation）と次の計画チケット（design-plan）が未着手で作られている（根拠: 0003・0004・0005 が investigation、0006 が design-plan として 00_todo に存在。コミット d90da2b / f510518 / 1368ebb / 69fee9b）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。調査計画書と HTML を作り、調査チケット 3 枚と次の計画チケット 0006 を起票した

### うまくいったこと

- 計画書テンプレートの節と調査計画の OUT ひな形が対応しており、md を先に書いてから HTML に写す順で迷いなく埋められた
- チケットを先に作ってから計画書に番号を書いたので、計画書とチケット番号の食い違いが起きなかった

### うまくいかなかったこと

- check-html.sh が 1 回落ちた。`<title>{{title}}</title>` が head 側にあり、body だけを差し替えた際に置換漏れした。RV001 の指摘で場所が特定できたのですぐ直せた

### 仕様からの逸脱

- 処理フローは「3 計画書 → 4 実施チケット群 → 5 次の計画チケット」の順だが、実際にはチケットを先に作ってから計画書を書いた。計画書に実チケット番号を書くための順序入れ替えで、成果物の内容は同じ
- 実行者を全チケットでメインエージェントにした（基準はサブエージェント）。全体計画書の方針の差分 1 に従う

### 判断と根拠

- 観点を 6 問・3 チケットに絞った。答えが後続の計画に効かない問いは含めない規定に従い、「VS Code の Webview API の詳細」のような設計フェーズで読めば足りる問いは外した
- 0004 にだけ `allow.ops` の `build-test` と `web` を付けた。npm レジストリへの到達可否は実際に走らせないと分からず、他の 2 枚は読むだけで足りるため
- issue #13 の詳細欄が置き場を `tools/vscode-ticket-board/` と書く一方、`scope-limits.json` の `implementation` は `src/**` と `tests/**` を許可し `design` は `docs/**` を許可することに気づいた。設計で困る前に Q5 として調査に載せた

### 拒否・確認・迂回の記録

- 拒否はなし。フックが未登録のため機構によるブロックは発生していない

### 使った AI アセットと効き目

- `20-common-step-report-view`: テンプレートのコピーを埋める手順と check-html.sh が有効に働いた。置換漏れを機械が捕まえた
- `20-common-step-ticket` の ticket.sh: create の引数で先行チケットと許可範囲まで指定でき、frontmatter を手で書く必要がなかった
- 仕様書 `10_spec/skills/10-task-investigation-plan.md`: スキル実体が無くても、計画タスク共通の処理フローと調査計画固有の手順がそのまま手順書として使えた

### スコープ外で見つけたこと

- `scope-limits.json` の `implementation` は `confirm` に `package.json` を挙げており、Node プロジェクトの追加を想定した設計になっている。拡張の追加自体は機構の想定内
- `design` は `docs/**` を許可し `.claude/**` を deny する。アプリ種別の設計文書は `.claude/docs/` ではなくトップレベル `docs/` に置く想定と読める。ただしこのリポジトリにトップレベル `docs/` は無い

### AI アセットに反映すべき内容

- 現時点で 0 件。理由: このチケットで使ったアセット（ticket.sh・report-view・commit.sh）はいずれも仕様どおり動き、直したい点が見つからなかった。上の「スコープ外で見つけたこと」は調査で確定させる対象であり、アセットの不備として確定していない

### 備考

- 計画書の HTML は id 11 件 / リンク 8 件で検査を通過している
