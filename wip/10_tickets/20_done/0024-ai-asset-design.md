---
type: ticket
ticket_type: ai-asset-design
predecessors: []
executor: main
human_review: {required: false, reason: "テスト ID 2 件の追加のみ（差分 1 文書・数行）。実装の切れ目で一緒に見る"}
adversarial_review: {required: false, reason: "差分が 1 文書・50 行未満"}
allow:
  write: [".claude/docs/10_spec/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T13:53:09+09:00"
completed_at: "2026-09-01T13:55:08+09:00"
base_sha: "040e228"
---

# 0024 AI アセット設計実施（追加）— hooks/lib の push-detect / transcript にテスト ID を追加

## 目的

実装計画（0011・0023）で見つかった「`push-detect.sh` / `transcript.sh` に lib 単位のテスト ID が無い」を解消する。フック共通仕様 §11（共通のテスト観点）に HK-T13・HK-T14 を追加し、0015 がテスト ID の無いアセット変更にならないようにする。

## DoD

- [x] `10_spec/フック共通仕様.md` §11 に HK-T13（`push-detect.sh`: fork ゼロの前置フィルタで push を含まないコマンドを即座に除外し、`tool_response` の成功判定と `@{upstream}` の縮退経路が `post-push-compact-prompt` 仕様の「push 検知」どおりに動く）と HK-T14（`transcript.sh`: カーソル以降の行だけを 1 回の jq で集計し、カーソルが進み、壊れた行を飛ばす）が追加されている（根拠: §11 の表の HK-T12 の直後に 2 行追加。HK-T13 は compact-prompt 仕様「push 検知」1〜3 の条件（前置フィルタ / 提供コマンドか実行位置の `git push` / 終了コード 0 / HEAD == upstream / `origin/<b>` → 終了コード 0 の縮退 / 前回 sha と同じなら偽）を、HK-T14 は usage-report 仕様 `--accumulate` 2・5（カーソル以降 / 1 回の jq / 4 指標 + tool_use + ターン数 + タイムスタンプ / 二重計上なし / 壊れた行は parse_errors）を lib 単体の観点として書いた）
- [x] §6 の台帳の `HK-T` 行と、`post-push-compact-prompt` / `post-push-usage-report` 仕様の参照が矛盾していない（lib の観点はフック本体の PP-T / UR-T と重複しない）（根拠: §6 の `HK-T | フック共通 | 共通のテスト観点（§11）` は範囲を限定していないため変更不要。HK-T13 / HK-T14 の各行末に「フック本体を通した検知は PP-T01〜03・PP-T08」「蓄積・本文は UR-T01・02・05」と分担を明記し、関数単体（フック本体を経由しない）の観点に限定した。§1 の lib 一覧 2 行に「lib 単体のテスト観点は §11 HK-T13 / T14」を添えた。両フック仕様は変更していない（PP-T / UR-T の行はそのまま））
- [x] プレースホルダ 0 件、履歴的表現なし（根拠: 追加 4 行に `{{`・`TODO`・`TBD`・「以前は」「変更前」「追加した」なし。`git diff` で確認）

## 作業内容

- §11 の表に 2 行追加し、必要なら §1 の lib 一覧の説明に観点の所在を添える

## 作業ログ

### 現在地

- 済: §11 に HK-T13 / HK-T14 を追加、§1 の lib 一覧 2 行に観点の所在を追記
- 済: 検査（プレースホルダ・履歴的表現・差分範囲）
- 完了: `commit.sh` → `ticket.sh complete 0024`

### うまくいったこと

- 両フック仕様の該当節（push 検知 1〜3 / `--accumulate` 2・5）がそのまま lib の入出力になっており、テスト観点を「関数単体」に限定して書き分けるだけで済んだ

### うまくいかなかったこと

- なし

### 仕様からの逸脱

- なし（設計チケット。仕様への追記そのものが成果物）

### 判断と根拠

- HK-T13 に「`git push` が文字列引数の中だけにあるときは偽」（`grep "git push"`）を含めた: PP-T02 がフック本体で同じことを見るが、lib 単体でも前置フィルタと cmdpos の組み合わせで偽になることを固定しないと、0015 の実装が前置フィルタだけで真にしてしまう余地が残るため
- HK-T14 の「ファイル不在・空ファイルは 0 の結果と終了 0」は usage-report 仕様 5（読めない → 何もしない）の lib 側の表れとして含めた。UR-T05 はフック全体の無出力を見る
- §6 の台帳は変更しない: `HK-T` 行は範囲を書いておらず、テスト ID は台帳への登録義務の対象外（§6 冒頭）

### 拒否・確認・迂回の記録

- なし

### 使った AI アセットと効き目

- `20-common-step-ticket`（`ticket.sh start` / `complete`）、`20-common-step-commit-push`（`commit.sh` / `push.sh`）: 状態遷移とコミット
- `wip/tmp/apply-pairs.pl`（使い捨て）: 長い表の行の置換を厳密一致で適用

### スコープ外で見つけたこと

- §11 の HK-T05（cmdpos）・HK-T11（scope）は §1 の lib 一覧から参照されていない。HK-T13 / T14 だけに所在を添えたので、揃えるなら cmdpos / scope の行にも同様の注記を足す（0022 の候補）

### AI アセットに反映すべき内容

- §1 の lib 一覧の全行に「lib 単体のテスト観点は §11 HK-Txx」を揃えて書く（今回は push-detect / transcript の 2 行のみ）→ 0022

### 備考

- 0015 はこのチケットの完了で先行条件を満たす（`next` の順は 0015 → 0021 → 0022）

### うまくいったこと

### うまくいかなかったこと

### 仕様からの逸脱

### 判断と根拠

### 拒否・確認・迂回の記録

### 使った AI アセットと効き目

### スコープ外で見つけたこと

### AI アセットに反映すべき内容

### 備考
