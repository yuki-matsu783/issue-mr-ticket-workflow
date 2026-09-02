---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0032"]
executor: main
human_review: {required: true, reason: "中核（テスト）を含む"}
adversarial_review: {required: false, reason: "フェーズ 6 の敵対的レビューの指摘対応"}
allow:
  write: [".claude/rules/**", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T11:45:35+00:00"
completed_at: ""
base_sha: "a598e7e"
---

# 0033 実装: ルール本体に DDR の状態の語彙を反映し、テストの deny の網羅を戻す

## 目的

0032 の正史をルール本体に落とし、アサーションの入れ替えで失われた deny の固定を回復する

## DoD

- [x] 両ルール本体の DDR の記述が 0032 の許容値と一致し、2 本で文言が揃っている（根拠: 両ルール本体の「マージ済みの DDR は…」の行から旧語彙（`置き換え済み / 廃止` の 2 値）を外して `status` に寄せ、その下に置き換えの関係の項目を足した。`grep -n '置き換え済み / 廃止' .claude/rules/*.md` が 0 件。足した項目は 2 本で 1 字違わず同文（`diff` が空）で、0032 で要件書に書いた定義（3 値・対のキー・値はパスだけ・`superseded_scope`）と一致）
- [x] test_config_integrity.sh が計画・調査 7 type すべてについて apl/** の deny を固定している（根拠: `test_config_integrity.sh` の deny のアサーションを 7 type すべてを回すループにした。各 type について `apl/*/src/**`・`apl/*/docs/**`・`apl/*/package.json` が `deny WF201 3`、`.claude/rules/x.md` が `deny WF201 2` の 4 件、計 28 件。置き換え前は 4 type にしか当たっておらず、`implementation-plan` / `design-feedback-plan` / `ai-asset-implementation-plan` は無防備だった）
- [x] 変更前に落ちて変更後に通ることを確かめ、run-tests.sh --ids が 14 本すべて PASS する（根拠: 変更前 `passed=50 failures=0`、アサーション追加後 `passed=76 failures=0`。網羅が効くことを確かめるため、`implementation-plan` の deny から `apl/**` を外した複製を作って当てたところ `passed=73 failures=3` で落ちた。元に戻して `passed=76 failures=0`。`run-tests.sh --ids` は 14 本すべて PASS）

## 作業内容

- テストを先に書いて落としてから直す

## 作業ログ

### 現在地

- 完了。ルール本体 2 本に DDR の置き換えの規定を足し、テストの deny の網羅を 4 type から 7 type に戻した

### うまくいったこと

- 「緩めたら落ちるか」を実際に確かめた。`implementation-plan` の deny から `apl/**` を外した複製を作って当て、3 件落ちることを見てから元に戻した。アサーションを足しただけでは「本当に守っているか」は分からない
- 個別のアサーションではなくループにした。type が増えたときに書き忘れが起きない。7 type × 4 パス = 28 件が 6 行で書ける

### うまくいかなかったこと

- 0031 で旧置き場のアサーションを入れ替えたとき、消したアサーションが `implementation-plan` の type deny を踏んでいたことに気付かなかった。新しく足した deny のアサーションは 3 type にしか当たっておらず、残り 4 type の deny を誰も見ていない状態になっていた。「消した側と残った側の両方を固定する」と 0031 の作業ログに書いておきながら、残った側の網羅を数えていなかった

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **ループにした**: 7 type それぞれに 4 行書くと 28 行になり、読みにくいうえに 1 type 書き忘れても気付けない。ループなら type の一覧が 1 か所にあり、`scope-limits.json` の type と突き合わせられる
- **`.claude/rules/x.md` を `deny WF201 2` で見る**: `.claude/**` は type の deny と `common.protected` の両方にある。判定順 (2) が先なので段階は 2。段階まで固定しておくと、`common.protected` から `.claude/**` が消えたときにも落ちる
- **3 つのパスを見る**: `apl/*/src/**`（ソース）・`apl/*/docs/**`（設計文書）・`apl/*/package.json`（アプリルート直下）。deny は `apl/**` の 1 パターンだが、実際に守りたいのはこの 3 種類。パターンが分割されたときにも守られていることを見る

### 拒否・確認・迂回の記録

- なし（`allow.write` の範囲内）

### 使った AI アセットと効き目

- 0032 で書いた要件書の定義: ルール本体に写すだけで済んだ。2 本の文言が揃うことも `diff` で確かめられた

### スコープ外で見つけたこと

- 特になし

### AI アセットに反映すべき内容

- アサーションを消して別のものに入れ替えるときは、消した側が守っていた性質を書き出してから入れ替える。今回はそれをやらずに 1 つ落とした。フィードバック計画の B1（テストの構成）に合流させて別 issue で扱う

### 備考

- 次は 0034（仕様書 6 行と DDR）→ 0035（render.ts）
