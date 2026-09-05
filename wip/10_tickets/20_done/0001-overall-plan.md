---
type: ticket
ticket_type: overall-plan
predecessors: []
executor: main
human_review: {required: true, reason: "フェーズ列・実行者・やってよいことの合意は人間が行う"}
adversarial_review: {required: false, reason: "基準どおり（work-defaults.md）"}
allow:
  write: ["wip/**"]
  ops: ["issue の起票と追記", "ブランチと MR の作成", "push"]
started_at: "2026-09-05T11:21:28+00:00"
completed_at: "2026-09-05T11:30:15+00:00"
base_sha: "4a96f75"
---

# 0001 hook機構（Claude Code Ticket Guard）設計文書の追加の全体計画

## 目的

Confluence の hook機構設計（Claude Code Ticket Guard）を .claude/docs/ 配下に取り込む作業の issue・ブランチ・draft MR・フェーズ列を確定する

## DoD

- [x] 起点 issue が確定している（既存を採用 or 新規起票）（根拠: open 30 件・closed 10 件を検索し該当なし。承認①を得て issue #52 を新規起票した）
- [x] feature ブランチと draft MR がある（根拠: ブランチ `claude/hook-mechanism-hx89wi`（承認②で既存ブランチの継続使用を合意）、draft PR #53）
- [x] 全体計画書が wip/00_overall_plan/ にあり、フェーズ列・実行者・レビュー要否をユーザーと合意している（根拠: `wip/00_overall_plan/overall-plan.md`。承認③を取得し「合意の記録」に記載）
- [x] 最初の計画チケットが 1 枚 00_todo/ にある（根拠: `wip/10_tickets/00_todo/0002-investigation-plan.md`）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。issue #52・draft PR #53・全体計画書・調査計画チケット 0002 まで揃った

### うまくいったこと

- 依頼が「Confluence 設計文書の取り込み」なのか「機構の実装」なのかを、着手前に承認①で確定できた。実装まで進んでいたら未提供の §13〜§23 を推測で埋めることになっていた
- 同じスクリーンショットが 4 回送られたが、既存 `hook機構.md` の章構成（§6〜§12.2）と突き合わせて重複と判定でき、取り込み対象を §0〜§5 に絞れた

### うまくいかなかったこと

- チケット作成時に `allow.ops` を日本語ラベル（「issue の起票と追記」等）で書いたため、`push.sh` の項目 2 が `remote-write:push` を読み取れず開始 push が止まった。着手済みチケットの `allow` は WF208 で変更できないので、`wip/push-check-skip.md` に理由を書いてスキップした
- `command -v gh` / `python3` が WF204 / WF206 で拒否された。前者は `gh` の語がサブコマンド無しで現れると `remote-write:other` に分類されるため

### 仕様からの逸脱

- 無し（`push.sh` 項目 2 のスキップは仕様が用意した手段による）

### 判断と根拠

- 種別を「AI アセット」とした。変更対象が `.claude/docs/00_requirement/hook機構.md` の 1 ファイルで `apl/` に触れないため
- AI アセット実装・テストのフェーズを残した。`scope-limits.json` 上 `ai-asset-implementation` は `.claude/docs/**` を deny しており対象は無い見込みだが、必須フェーズなので省かず「対象なし」で通す
- 調査の人間レビューを不要へ下げた。`work-defaults.md` の「読むだけの小さな調査は不要に下げてよい」に当たる
- 文書の型は生写しのままとした（承認②）。`20-common-step-requirement` の型への変換は原本との照合可能性を失わせるため別 issue に回す

### 拒否・確認・迂回の記録

- WF101（振り分け未宣言）: ユーザーの新しいプロンプトごとに宣言が必要。`00-workflow-issue-mr-driven` を読み直して解消
- WF204（`python3` が分類外）/ WF206（`command -v gh` が `remote-write:other`）: 迂回せず、Read / Edit ツールと `gh --version` の形に切り替えた
- WF208（着手済みチケットの `allow` 変更）: 迂回せず `wip/push-check-skip.md` を使った
- CP005（push 前チェック項目 2）: 上記スキップで解消

### 使った AI アセットと効き目

- `00-workflow-issue-mr-driven`: 手順 0〜1 と切れ目の判定に有効
- `10-task-overall-plan`: 承認①②③の順序が明確で、スコープの取り違えを防いだ
- `20-common-step-feature-mr`: `gh` 未導入のため手順 1 の前提確認で止まる想定だったが、呼び出し元の外部委任モード（MCP 代行）で通した
- `20-common-step-ticket` / `20-common-step-commit-push`: 提供コマンドは動いたが、`allow.ops` の記法を促す仕組みが無い

### スコープ外で見つけたこと

- 既存 `hook機構.md` は本文から §14.9 / §16 / §17 / §18 / §23.3 を参照しているが、それらの節は未取り込みで参照先が存在しない
- 取り込む設計（Layer 0-B 不変 deny・`config.yaml`・承認キャッシュ・完全性検証）と、既に動いている `.claude/hooks/`（WF20x のスコープガード）との関係が未整理

### AI アセットに反映すべき内容

- `ticket.sh create` の `--allow-ops` が `scope-limits.json` の正規名でない値を受け付けてしまう。作成時に検査すれば、開始 push でのスキップは起きなかった
- `20-common-step-feature-mr` の手順 1 は「CLI 未導入なら停止」だが、呼び出し元の外部委任モードとの関係が書かれていない
- `.claude/docs/` に置く文書のうち、外部原本の生写しをどう扱うか（型の適用対象外とするか）の方針が無い

### 備考

- `gh` が未導入のため `boundary.sh` が MR を検出できない（`logs/mr.json` が空）。以降の切れ目は `--external` で通す
- squash merge の可否と既定を確認できていない（保留 P1）
