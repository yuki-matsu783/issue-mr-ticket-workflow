---
type: ticket
ticket_type: implementation-plan
predecessors: ["0012"]
executor: main
human_review: {required: true, reason: "許可範囲と巻き戻しを実装前に見る"}
adversarial_review: {required: false, reason: "基準どおり"}
allow:
  write: ["wip/**"]
  ops: ["read", "remote-read"]
started_at: "2026-09-02T10:56:21+00:00"
completed_at: ""
base_sha: "3a4e7f0"
---

# 0013 実装・テスト計画: 拡張のソースとビルド設定を apl/ へ移す

## 目的

src/vscode-ticket-board/ の apl/vscode-ticket-board/ への移動と参照更新の手順・テスト・巻き戻しを決める

## DoD

- [x] 実装計画書と HTML ビューが wip/20_plans/ にある（根拠: `wip/20_plans/0013-implementation-plan.md`（106 行）と `.html`。`check-html.sh` が「検査 7 項目すべて通過（id 11 件 / リンク 8 件）」）
- [x] 移動するファイルと更新する参照が一覧化されている（根拠: 計画書「移動するファイル」に 18 ファイルを 9 行の表で、「更新する参照」に 7 行の表で一覧化した。実際の件数は `find src/vscode-ticket-board -type f | wc -l` = 18 と一致。内容を直すのは README の 30 行目だけ（1 か所））
- [x] 拡張のテスト（npm test）の実行手順と期待値がある（根拠: 計画書「検証」に V1〜V5 の 5 件を、検査・コマンド・期待値の 3 列で書いた。V3 が `apl/vscode-ticket-board/` での `npm test` で、期待値は「tsc がエラー 0、node --test が全件 pass」。前提（`commands.build-test` への列挙）も同じ節に書いた）
- [x] 実装チケットと次の計画チケット（feedback-plan）が起票されている（根拠: 0016（ai-asset-implementation、`commands.build-test` の列挙）・0017（implementation、移動と検証）・0018（feedback-plan）を起票した。依存は 0013 → 0016 → 0017 → 0018）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。実装計画書と HTML ビューを作り、チケット 0016〜0018 を起票した

### うまくいったこと

- 移動対象を数えてから計画に書いた（18 ファイル）。「一覧化した」と書いて実際と食い違うことを避けられた
- ビルド設定を読んで、移動で内容を直す必要が無いことを先に確かめた。`tsconfig.json` は `tsc -p .`、`package.json` の `main` は `./out/src/extension.js`、テストは `node --test out/test/*.test.js` で、すべてアプリルート相対。アプリルートの位置が変わっても解決先は変わらない
- `npm test` が `commands.build-test` の列挙なしでは WF204 で止まることに、計画の段階で気付けた。実装チケットを起こしてから止まると手戻りになっていた

### うまくいかなかったこと

- 計画書の最初の版で、「移動するファイル」の表が `src/core/*.ts` を「内容の変更あり（各 1 行）」、「更新する参照」の表が同じファイルを「変更なし」と書いていて、2 つの表が食い違っていた。書き終わりに突き合わせて直した

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-implementation-plan` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）
- `commands.build-test` の列挙: 仕様（フック共通仕様 §8）は「調査計画・実装計画が列挙する」と書くが、`scope-limits.json` は `common.confirm` に載り、実装計画の `allow.write` は `wip/**` のみ。計画タスクからは書けないので、ai-asset-implementation チケット（0016）に分けた。計画書の「保留した点」に記録した

### 判断と根拠

- **ソースのヘッダコメントを書き換えない**: 5 ファイルの `仕様: docs/10_spec/vscode-ticket-board.md` は、リポジトリルート相対とも**アプリルート相対**とも読める文字列。フェーズ 6 で設計文書が `apl/vscode-ticket-board/docs/` へ移ると、アプリルート相対として正しくなる。文字列を変えるとかえって二度手間になる
- **フェーズ 4 単独で参照が切れることを許容する**: フェーズ 4（ソース）とフェーズ 6（設計文書）を分けたのは許可範囲の制約（`implementation` は `apl/*/docs/**` を deny）で、DDR `i0020-01` に記録済み。この 1 コミット分の不整合を避けるには両方を 1 タスクでやるしかなく、それは許可範囲の設計を崩す。不整合を許容してフェーズ 6 で解消する側を採った
- **DDR `i0020-01` の本文は直さない**: 影響の節は「ヘッダコメントと README の参照はアプリルート相対に更新する」と書いているが、実際は既に同じ文字列なので更新は 0 か所で満たされる。DDR は決定の記録なので本文を書き換えず、差分は計画書で説明した（`design-docs` の「マージ済み DDR は本文を変更しない」に倣った。この DDR はまだマージ前だが、同じ扱いにした）
- **`git mv` を使う**: `rm` + 新規作成だと `git log --follow` が移動前を辿れず、拡張の由来が失われる。DoD に履歴の確認を入れた
- **移動前に `npm test` の基準を取る**: 移動後に落ちたとき、移動が原因か既存の不具合かを切り分けるため。ロックアウト対策の表に入れた
- **旧置き場の deny をこのフェーズで消さない**: 消すと、まだ移動していない `docs/` を計画・調査タスクが書けてしまう。フェーズ 6 の完了後に回した（スコープ外に明記）

### 拒否・確認・迂回の記録

- なし（`allow.write` の `wip/**` の範囲内で完結した）

### 使った AI アセットと効き目

- `.claude/docs/10_spec/フック共通仕様.md` §8 の「旧置き場」の段落: 移動元の削除が判定順 (7) の ask WF202 に落ちること、承認単位が `src/vscode-ticket-board` になることが書かれていて、ロックアウト対策をそのまま書けた
- `20-common-step-report-view` の `check-html.sh`: HTML ビューの id とリンクの検査が 1 回で済む

### スコープ外で見つけたこと

- `docs/10_spec/vscode-ticket-board.md` の 28 行目に `src/vscode-ticket-board/` が書かれている（配置の節）。設計文書の本文なのでフェーズ 6 の担当。計画書のスコープ外に明記した

### AI アセットに反映すべき内容

- 実装計画が `commands.build-test` を列挙できない（`scope-limits.json` が `common.confirm` で、計画タスクの `allow.write` は `wip/**` のみ）。仕様の「実装計画が列挙する」という記述と機構が食い違っている。計画が列挙を宣言し、実施タスクの側で適用する形か、計画タスクの allow に `commands` だけを部分的に許すかを決めたい。フィードバック計画（フェーズ 5）で拾う

### 備考

- 起票したチケットは 0016（列挙）→ 0017（移動と検証）→ 0018（フェーズ 5 の計画）。フェーズ 4 の敵対的レビューは 0017 の完了後に 1 回
