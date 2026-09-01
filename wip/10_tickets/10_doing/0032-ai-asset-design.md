---
type: ticket
ticket_type: ai-asset-design
predecessors: ["0030"]
executor: main
human_review: {required: false, reason: "切れ目の敵対的レビューの反映。反映結果は note で報告する（承認④）"}
adversarial_review: {required: false, reason: "レビュー指摘の反映のみ（差分は文言の修正）"}
allow:
  write: [".claude/docs/**", "wip/**"]
  ops: ["read"]
started_at: "2026-09-01T17:27:55+09:00"
completed_at: ""
base_sha: "211fd9d"
---

# 0032 AI アセット設計・追加: 敵対的レビュー G-1〜G-21 の反映（設計 0028〜0030 の切れ目）

## 目的

wip/tmp/review-design2-findings.md の指摘のうち確度 0.5 以上の 15 件（G-1〜G-15）を仕様・DDR・結果報告に反映し、0.5 未満のうち修正が 1 行で済むもの（G-16・G-17・G-20）も直す。実装を変える判断（G-6 判定語・G-7 create の YAML エスケープ・G-9 command -v）は 0031 への申し送りに追加する

## DoD

- [ ] G-1: フック共通仕様 §7-9 の CP_ARGS / CP_WRITE_TARGETS の区切りバイトが実装（0x1E）と一致している（根拠: ）
- [ ] G-2: report-view 仕様の Script 処理冒頭・OUT ひな形・RV-T07 が「導出元テンプレート不在は RV006・終了 1、RV008 は引数・ファイル不正のみ」で矛盾なく揃い、実装 check-html.sh と一致している（根拠: ）
- [ ] G-3・G-4・G-17: DDR i0006-07 / 09 / 12 の影響・背景の誤り（12-PreToolUse のパス、WF203 の対象、CP001 / CP006 の意味）が直っている（根拠: ）
- [ ] G-5・G-6・G-9・G-16: shell-script 仕様の fm_get の戻り、ticket 仕様の現在地の判定語、フック共通仕様 §8 の read の例示と変数名、build-test / hook-test の実行体（bash と sh）が実装どおりになっている（実装を変える案は 0031 への申し送りとして結果報告に書く）（根拠: ）
- [ ] G-8: フック共通仕様 §7-3 / §7-5 の語彙表（透過ラッパー・不透明な実行系の 2 系統・書き込み先コマンド）が cmdpos.sh の配列と全要素一致している（比較の根拠を作業ログに）（根拠: ）
- [ ] G-10・G-14・G-15: commit-push 仕様の CP003 の 2 条件と CP001 の終了コード、ticket 仕様の TK008 に commit.sh 不在が書かれている（根拠: ）
- [ ] G-7・G-11・G-12・G-13・G-21・G-20: 結果報告 0028 の要約（実装を変える件数と内訳に create の YAML エスケープを追加）・入力範囲（F-1〜F-25）・残課題（bash-script ルールとの二重管理、frontmatter キー名の正の移管）が直り、HTML にも同じ変更が反映され check-html OK。ticket 仕様のテスト観点表の行順が ID 順（根拠: ）

## 作業内容

- wip/tmp/review-design2-findings.md を読み、指摘ごとに実装（cmdpos.sh / scope.sh / frontmatter.sh / ticket.sh / commit.sh / check-html.sh）を再確認してから仕様の文言を直す
- 0.5 未満の G-18・G-19 は残課題に記載のみ（判断は変えない）

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
