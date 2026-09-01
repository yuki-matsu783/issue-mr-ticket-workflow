---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014", "0024"]
executor: main
human_review: {required: true, reason: "中核（提供コマンド・lib）を含む実装。切れ目で 1 回（承認④により opus 自己レビューで代替）"}
adversarial_review: {required: false, reason: "実装の切れ目で 1 回"}
allow:
  write: [".claude/hooks/lib/**", "wip/**"]
  ops: ["read", "build-test", "hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0015 AI アセット実装 S2-2: hooks/lib 5 本（hook-common / cmdpos / scope / push-detect / transcript）

## 目的

フック共通ライブラリ 5 本をフック共通仕様どおりに作り、2/3 のフック本体がそのまま乗れる状態にする。フック本体は作らない・登録しない。

## DoD

- [ ] `hook-common.sh` が §3（deny / ask / notify ヘルパの内側で `redact`）・§4（緊急停止と `disabled` 記録）・§5（`decisions.jsonl` スキーマ・セッション状態の原子的更新）・§10（ヘッドレスで ask → deny）・`hook_jq`（CR 除去）を実装し、HK-T03（lib 部分）・T04・T06・T07・T08・T10 が通る（根拠: ）
- [ ] `cmdpos.sh` が §7 の 1〜8（前処理・分割・ラッパー剥がし・正規化・opaque・PowerShell・縮退・提供コマンド識別）を実装し、HK-T05・HK-T12 が通る（根拠: ）
- [ ] `scope.sh` が §8 の判定順・glob 規則（`*` は `/` を跨がない）・`ops` 分類（`build-test` の `tests/` `test/` 配下 sh を含む）・`d.write` / `d.ops` の絞り込みを実装し、`frontmatter.sh` を読み込み行（deny ポリシー）で source して HK-T11 が通る（根拠: ）
- [ ] `push-detect.sh` が `post-push-compact-prompt` 仕様の push 検知（fork ゼロの前置フィルタ・`tool_response` による成功判定・`@{upstream}` の縮退）を実装し、HK-T13（0024 で §11 に追加）が通る（根拠: ）
- [ ] `transcript.sh` が `post-push-usage-report` 仕様の集計をカーソル付きの 1 関数で実装し、HK-T14（0024 で §11 に追加）が通る（根拠: ）
- [ ] H1（redact を通す前にログへ書く経路が無い）・H2（無視リストは `logs/**`）が満たされている（根拠: ）
- [ ] 全 lib が `bash -n` を通り `run-tests.sh --filter '.claude/hooks/**'` が全通過（根拠: ）
- [ ] プレースホルダ（`{{ }}`・`TODO`・`TBD`。テンプレート `assets/*.template.*` は対象外）と frontmatter の検査が 0 件（根拠: ）
- [ ] 参照更新一覧の検索語で新規アセットに旧名が持ち込まれていない（0 件）（根拠: ）
- [ ] `git diff --stat <base_sha>` が許可範囲内（根拠: ）
- [ ] 実装結果レポート `wip/30_reports/0013-ai-asset-implementation.md` に担当ステップの節（作成・更新したアセットと仕様の節・テスト結果・検査結果・逸脱）を追記した（根拠: ）

## 作業内容

- 順: hook-common → cmdpos → scope → push-detect → transcript。1 本ごとにテストを通してから次へ
- 流用元は調査レポート Q1（付録 A §1〜§3）。移植時に参考固有の記述と参考のログ行を持ち込まない
- フック本体が要るテスト（HK-T01・T09・T03 の登録部分）は書かず、作業ログに 2/3 送りと明記

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
