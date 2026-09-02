---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0011"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズの敵対的レビューは 0011〜0012 をまとめて 1 回実施する"}
allow:
  write: [".claude/skills/**", ".claude/hooks/config/scope-limits.json", ".claude/hooks/lib/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T10:28:20+00:00"
completed_at: "2026-09-02T10:34:14+00:00"
base_sha: "e418747"
---

# 0012 実装: 共通ステップスキル 2 本・テンプレートと許可範囲設定

## 目的

20-common-step-requirement / -spec の SKILL.md と要件書テンプレートを仕様どおりに直し、scope-limits.json とそのテストを新しい許可範囲に合わせる

## DoD

- [x] 20-common-step-requirement の SKILL.md が 14 手順・セルフレビュー 14 項目・置き場の一般化を反映している（根拠: `grep -c '^[0-9]*\. \*\*' .claude/skills/20-common-step-requirement/SKILL.md` が 14。手順 1「設計文書ルートの決定」・手順 4「issue の受け入れ条件との対応」を追加し、以降を 2 つずつ繰り下げて仕様書の 14 手順と 1:1。手順 14 が「セルフレビュー項目」14 項目を参照。手順 3 のコピー先と手順 12 の DDR の置き場を `<設計文書ルート>` 相対にした）
- [x] requirements.template.md の概要章に「issue の受け入れ条件との対応」の小節がある（根拠: `assets/requirements.template.md:23` に `### issue の受け入れ条件との対応`。スコープの直後・ユーザーストーリーの前に置き、起点行 + 2 列表 + 全件と「起点の issue なし」の扱いを書いたガイドコメントを持つ）
- [x] 20-common-step-spec の SKILL.md の種別表にアプリの行（10 節固定）とアプリの識別子の採番規則がある（根拠: 手順 3 の表にアプリ行（概要・禁止事項 / 配置 / 起動と入口 / モジュール構成 / データの形 / 処理フロー / 画面・出力の構造 / 不備の識別子とメッセージ / テスト観点 / 要件との対応）とルール行を追加。表の下に「アプリの識別子」（2 文字接頭辞 + 3 桁、そのアプリの仕様書が台帳、機構の台帳に登録しない、`apl/*/docs/10_spec/` を検索）と「画面・出力の構造」を必ず置く規定を追加）
- [x] scope-limits.json がフック共通仕様の初期値と一致し、jq で構文が通る（根拠: `jq -e . .claude/hooks/config/scope-limits.json` が成功。type 15 件すべてに `ops` があり、`src/**` `docs/**` を持つのは計画・調査の 7 type の `deny` だけ。実施タスク（implementation / design / design-feedback）と ai-asset 系は `apl/` ベースに置き換わっている）
- [x] test_scope.sh にアプリルート直下・apl/*/docs/** ・入れ子 .gitignore・旧置き場の deny のアサーションがあり、変更前に落ちて変更後に通ることを確かめた（根拠: `case_real_apl` を追加。出荷される `scope-limits.json` をそのまま読む `resolve_real` で 21 件を検査。config 変更**前**は `passed=250 failures=16` で、落ちた 16 件はすべて新規アサーション。config 変更**後**は `passed=266 failures=0`）
- [x] run-tests.sh --ids が全通過し、結果を作業ログに残した（根拠: 14 本すべて PASS・FAIL ID なし。内訳は作業ログ「うまくいったこと」に記載）

## 作業内容

- DoD の各項目を順に満たす

## 作業ログ

### 現在地

- 完了。`20-common-step-requirement/SKILL.md`・`assets/requirements.template.md`・`20-common-step-spec/SKILL.md`・`.claude/hooks/config/scope-limits.json`・`.claude/hooks/lib/tests/test_scope.sh` の 5 ファイルを更新した

### うまくいったこと

- テストを先に書いて落としてから設定を直す進め方が効いた。config 変更前 `passed=250 failures=16`（落ちたのは新規 21 件のうち 16 件で、既存 250 件は無傷）、変更後 `passed=266 failures=0`。「テストが変更を検出する」ことを確かめられた
- `run-tests.sh --ids` は 14 本すべて PASS、`FAIL ID:` は空。合計 59 テスト ID。内訳は test_cmdpos 237 / test_hook_common 108 / test_push_detect 31 / test_scope 266 / test_transcript 23 / test_config_integrity 8 / test_commit 68 / test_push 44 / test_check_html 51 / test_frontmatter 41 / test_logger 13 / test_run_tests 41 / test_templates 38 / test_ticket 117
- SKILL.md の手順の繰り下げは、番号を降順（12→14, 11→13, …）に処理することで衝突なく置換できた。昇順だと新旧の番号が衝突する

### うまくいかなかったこと

- 最初の置換スクリプトで、新しい手順を挿入してから番号を繰り下げようとして「5.」が 2 か所に一致し `AssertionError` で止まった。順序を「先に繰り下げ → 後から挿入」に変えて解決した

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **テストの当て先を実物の設定にした**: 既存の `test_scope.sh` は一時ディレクトリの雛形 JSON で `scope.sh` の**ロジック**を検査している。今回変えたのは出荷される `scope-limits.json` の**中身**なので、雛形を直しても検出できない。`REAL_CFG` と `resolve_real` を足し、`.claude/hooks/config/scope-limits.json` をそのまま読む `case_real_apl` を独立の case として追加した。既存 case の雛形は触っていない
- **入れ子 `.gitignore` の検査を 2 方向で置いた**: `apl/*/.gitignore` は `common.protected` に入れたので、判定順 (2) で「type の allow に明示があれば通る / 無ければ deny」の分岐が生きる。implementation は `apl/*/*` の明示があるので `allow`（stage 5）、design は明示が無いので `deny WF201`（stage 2）。片方だけだと protected に入れ忘れても気付けない
- **`apl/README.md` の検査を足した**: `apl/*/*` はアプリルート直下だけを指し、`apl/` 直下は指さない（`*` が `/` を跨がない）。意図どおりであることを `ask WF202 7 apl` で固定した
- **旧置き場の扱いを 2 種類に分けて検査した**: 計画・調査（`investigation` / `implementation-plan`）は `deny WF201`（stage 3）、実施タスク（`implementation` / `design-feedback`）は `ask WF202`（stage 7）。後者はフェーズ 4・6 の一度きりの移行を人間の承認で通すための挙動で、フック共通仕様の「旧置き場」の段落どおり
- **`ai-asset-implementation` の allow に `CLAUDE.md` を残した**: フック共通仕様の §8 の抜粋 JSON（設定ファイルの例）には無いが、初期値の表には `CLAUDE.md` がある。表が初期値の正なので表に従った。抜粋 JSON は 3 type だけを載せた説明用の断片
- **`commands.build-test` は空配列のまま**: 初期値の抜粋 JSON は `["npm test", "npm run build"]` だが、これは「プロジェクトが外部のコマンドを足すときに埋める」例。現在このリポジトリに npm のテストは無く、アプリ移行はフェーズ 4 の担当なので、このチケットでは変えていない

### 拒否・確認・迂回の記録

- `.claude/hooks/config/scope-limits.json` は `common.confirm` に載るので、書き込みのたびに WF203 の確認が出る想定。迂回はしていない
- `run-tests.sh` は `allow.ops` に `build-test` / `hook-test` を宣言済み（0009 の計画で TR006 を踏まえて宣言した）ので、追加の宣言なしに実行できた

### 使った AI アセットと効き目

- `.claude/docs/10_spec/フック共通仕様.md` §8 の初期値の表: `scope-limits.json` の 15 type をそのまま書き下せた。表と JSON の突き合わせを `jq` でできる形にしてあるのが効いた
- `.claude/docs/10_spec/skills/20-common-step-requirement.md` / `-spec.md`: SKILL.md は仕様書の処理フローと 1:1 に写すだけで済んだ
- `run-tests.sh --ids`: ID の重複と FAIL を 1 回で出せる。既存テストの回帰が無いことをすぐ確認できた

### スコープ外で見つけたこと

- `run-tests.sh --ids` が `CP-T08` の重複 ID を報告する（`test_commit.sh` と `test_push.sh` の両方が使っている）。今回の変更の前から出ており、issue #20 の受け入れ条件に無いので直していない

### AI アセットに反映すべき内容

- `test_scope.sh` は長く雛形 JSON だけを見ていて、出荷される `scope-limits.json` の中身は `test_config_integrity.sh` が構文と必須キーを見るだけだった。「設定の中身の意図（どの type が何を書けるか）を実物に当てて検査する」場所が無かったので、今回 `case_real_apl` で作った。この位置づけを `20-common-step-shell-script` かフック共通仕様のテスト観点に明記しておくと、次に許可範囲を変える人が同じ場所に足せる。フィードバック計画（フェーズ 5）で拾う

### 備考

- フェーズ 3 の敵対的レビューは 0011 と 0012 をまとめて 1 回、このチケットの完了後に実施する
