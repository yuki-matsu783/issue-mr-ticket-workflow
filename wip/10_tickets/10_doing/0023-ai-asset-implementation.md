---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0022"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T11:19:20+00:00"
completed_at: ""
base_sha: "d7aa4dc"
---

# 0023 実装: commands.build-test の列挙を増やし、分類を実際に走らせるテストにする

## 目的

クリーンな作業ツリーでアプリのテスト手順が通るようにし、テストが文字列一致でなく分類の振る舞いを固定するようにする

## DoD

- [x] commands.build-test に npm ci / npm run compile と、それぞれの npm --prefix 形が入っている（npm install は入れない）（根拠: `jq -r '.commands["build-test"][]'` が 6 件（`npm ci` / `npm run compile` / `npm test` と、それぞれの `npm --prefix apl/vscode-ticket-board` 形）。`npm install` は含まない。`jq -e .` が成功）
- [x] test_config_integrity.sh のアサーションが scope_classify を実際に呼び、列挙した形が build-test に、列挙に無い npm install が unknown になることを固定している（根拠: `test_config_integrity.sh` に `classify_real`（出荷 JSON を `scope_load` してから `cmdpos_parse` → `scope_classify` を走らせる）を足し、列挙した 5 形が `build-test`、`npm install` と `npm publish` が `unknown` になることを固定した。文字列の突き合わせだけでなく分類の振る舞いを見ている）
- [x] 列挙の検査が配列の完全一致でなく「必要な形が含まれていること」になっている（根拠: `has_build_test_cmd` が `jq index($c) != null` で「含まれていること」だけを見る。配列の完全一致は使っていないので、アプリが増えて形が足されても正当な追加でテストが落ちない）
- [x] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（根拠: 設定変更前 `passed=43 failures=7`（落ちた 7 件はすべて新規アサーション）、変更後 `passed=50 failures=0`。`run-tests.sh --ids` は 14 本すべて PASS。あわせて実物でも確認: `node_modules` と `out` を消してから `npm ci` → `npm run compile` → `npm test` を通し `# pass 47 / # fail 0`）

## 作業内容

- テストを先に書いて落としてから設定を直す

## 作業ログ

### 現在地

- 完了。`scope-limits.json` の `commands.build-test` を 2 件から 6 件にし、`test_config_integrity.sh` のアサーションを分類の実行に置き換えた

### うまくいったこと

- テストを先に書いて落としてから設定を直す順を守れた（43/7 → 50/0）
- 設定の検査だけでなく、**実物で 1 度通した**。`node_modules` と `out` を消してから `npm ci` → `npm run compile` → `npm test` を走らせ、47 件 pass を確認した。README が書いている手順がクリーンな作業ツリーで最後まで通ることを、設定の側と実行の側の両方で確かめられた
- アサーションを `classify_real`（出荷 JSON を読んでから `scope_classify` を実行）にしたことで、`scope.sh` の前方一致ループや `scope_load` の抽出が壊れたときに落ちるようになった。前の版は JSON の文字列を突き合わせるだけで、機構が壊れても緑のままだった
- 負のコントロール（`npm install` と `npm publish` が `unknown`）を置いた。分類が「何でも build-test にする」壊れ方をしたときに気付ける

### うまくいかなかったこと

- 特になし

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **6 件を列挙した**: 0022 で §8 に書いた方針（クリーンな作業ツリーで最後まで走らせられる形を、アプリルートで実行する裸の形とリポジトリルートからの `--prefix` 形の両方で列挙する）のとおり。`npm ci` / `npm run compile` / `npm test` の 3 段 × 2 形
- **`npm install` を列挙しない**: 0022 の判断のとおり。`package-lock.json` を書き換えうるので人間の確認を通す。テストに負のアサーションとして固定したので、後から「便利だから」と足されても落ちる
- **完全一致をやめた**: 前の版は配列全体を `join(" / ")` して突き合わせていた。2 本目のアプリが増えたときに、設定として正当な追加でこのテストが落ちる。落ちる理由も「仕様と食い違う」ではなく「このテストに書いた文字列と違う」でしかない。必要な形が**含まれていること**を見る形に変えた
- **`cmdpos.sh` を読み込みに足した**: `scope_classify` は `cmdpos_parse` が先に走っている前提。`test_scope.sh` が同じ 2 本を読み込んでいるのに倣った

### 拒否・確認・迂回の記録

- なし（`allow.write` の範囲内）

### 使った AI アセットと効き目

- `.claude/docs/10_spec/フック共通仕様.md` §8（0022 で足した列挙方針）: 何を列挙して何を列挙しないかが決まっていたので、実装で迷わなかった
- `.claude/hooks/lib/tests/test_scope.sh` の `classify_all`: 分類を走らせるアサーションの書き方の手本になった

### スコープ外で見つけたこと

- 特になし

### AI アセットに反映すべき内容

- 「設定の中身を固定するテスト」は、値の突き合わせではなく**その値を使う関数を実行する**形で書く、という指針を残したい。今回 2 回とも（許可範囲・コマンド分類）最初は値の突き合わせで書き、後から実行する形に直した。フィードバック計画（フェーズ 5）で拾う

### 備考

- 残りはフェーズ 4 の指摘のうち 0024（README の参照の基準の明示）と、フェーズ 6 に回した 2 件（旧置き場 `src/**` の削除、`docs/10_spec/vscode-ticket-board.md:28` の配置図）
