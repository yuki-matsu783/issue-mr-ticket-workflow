---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0014"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 3 の敵対的レビューの指摘対応であり、対応そのものは再レビューしない"}
allow:
  write: [".claude/rules/**", ".claude/evals/**", ".claude/skills/**", ".claude/hooks/config/scope-limits.json", ".claude/hooks/lib/tests/**", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T10:51:28+00:00"
completed_at: ""
base_sha: "6a29f3e"
---

# 0015 実装: 敵対的レビュー（フェーズ3）の指摘のうち本体に当たる 6 件を直す

## 目的

0014 で直した正史に合わせてルール本体・スキル・eval・許可範囲設定・テストを直す

## DoD

- [x] ai-asset-design-docs.md に「issue の受け入れ条件との対応」の規定が入り、design-docs.md と同文になっている（根拠: `.claude/rules/ai-asset-design-docs.md:40` に追加。`design-docs.md:39` と 1 字違わず同文（`diff <(sed -n 40p ai-asset-design-docs.md) <(sed -n 39p design-docs.md)` が空）。要件書 `00_requirement/rules/ai-asset-design-docs.md:70` の受け入れ基準に対応する）
- [x] design-docs.md の要件書の形が ai-asset-design-docs.md と同じ細目（図の 1 行 1 辺・ラベル・外部依存なし / 定型章の項目数と行数の目安）を持つ（根拠: `design-docs.md:35` に図の細目（1 行 1 辺・ラベルは日本語の動作と判定・外部依存なし）、`:37` に定型章の細目（各 5 項目以内・非機能要件 3〜6 行・超えるときの検討）を追加。0014 で足した要件書 71・72 行目に対応し、`ai-asset-design-docs.md:35`・`:38` と同じ内容）
- [x] evals/design-docs.md の 1:1:1・1 アセット の語がアプリの語彙（1 アプリ 1 対象・要件と仕様の同名 1:1）に直っている（根拠: `grep -c '1:1:1\|1 アセット（機能）' .claude/evals/design-docs.md` が 0。keywords・目的・DD-E03・判定基準の 4 か所を「1 アプリ 1 対象・同名 1:1」と `apl/X/docs/00_requirement/X.md` の具体パスに書き直した）
- [x] 20-common-step-spec/SKILL.md の手順の番号が仕様の処理フローと 1:1 で対応し、アプリの「なし」の規定が 10 節すべてに一般化されている（根拠: SKILL の手順が 7 つになり（1 設計文書ルートの決定 / 2 要件の存在確認 / 3 対応表の左列 / 4 節構成に沿って書く / 5 TBD / 6 対応表の右列と検査 / 7 更新）、0014 で直した仕様の処理フロー 7 手順と 1:1。アプリの「なし」の規定は手順 4 の箇条書きとエラー時の対処の両方で 10 節すべてに一般化した）
- [x] scope-limits.json が 0014 で直した §8 の初期値の表と一致し、implementation から apl/<アプリ名>/CLAUDE.md・.gitattributes が無確認で書けない（根拠: `jq -e .` が成功。`implementation.allow` が `apl/*/src/**` `apl/*/test/**` と列挙 5 件（package.json / package-lock.json / tsconfig.json / README.md / .gitignore）になり、`apl/*/*` は 0 件。`common.file_granular` に `apl/*/CLAUDE.md` を追加。判定は `apl/vscode-ticket-board/CLAUDE.md` → `ask WF202 7 apl/vscode-ticket-board/CLAUDE.md`、`.gitattributes` → `ask WF202 7 apl/vscode-ticket-board`（どちらも変更前は `allow - 5`））
- [x] 出荷設定を当てるアサーションが HK-T02 のテストへ移り、common.file_granular の apl/*/package.json・tsconfig.json・README.md を固定するアサーションがある（根拠: `case_real_apl` を `test_scope.sh` から外して `.claude/hooks/tests/test_config_integrity.sh` へ移し、ID を HK-T02 にした（同ファイルは元から実物の JSON を読む HK-T02 の枠）。`test_scope.sh` は 20c857d の内容と完全一致（`diff` が空）。file_granular を狙うアサーション 4 件（design から README.md / package.json / tsconfig.json はファイル単位、other.txt は親ディレクトリ）を追加）
- [x] run-tests.sh --ids が全通過し、変更前に落ちて変更後に通ることを確かめた結果を作業ログに残した（根拠: 設定変更前 `test_config_integrity.sh` は `passed=33 failures=3`、変更後 `passed=36 failures=0`。`run-tests.sh --ids` は 14 本すべて PASS・`FAIL ID:` は空）

## 作業内容

- 0014 の正史を読み、指摘ごとに本体を直す。設定の変更はテストを先に落としてから行う

## 作業ログ

### 現在地

- 完了。`rules/ai-asset-design-docs.md`・`rules/design-docs.md`・`evals/design-docs.md`・`skills/20-common-step-spec/SKILL.md`・`hooks/config/scope-limits.json`・`hooks/lib/tests/test_scope.sh`・`hooks/tests/test_config_integrity.sh` の 7 ファイルを直した

### うまくいったこと

- 出荷設定の検査を `test_config_integrity.sh`（HK-T02）へ移したことで、テスト ID と検査対象が揃った。設定変更前 `passed=33 failures=3` → 変更後 `passed=36 failures=0` で、移した先でも「先に落として後で通す」を確認できた
- `test_scope.sh` は 20c857d の内容へ完全に戻した（`diff` が空）。関数単体のテストと出荷設定のテストが混ざらない状態になった

### うまくいかなかったこと

- `test_scope.sh` から移す範囲を行の位置で切ったため、隣にあった `classify_all()` を巻き込んで消し、`passed=75 failures=171` になった。`git checkout 20c857d -- <path>` で戻して解決した。関数の削除は位置ではなく定義の単位で行うべきだった

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **`apl/*/CLAUDE.md` を file_granular に足した理由**: allow を列挙にすると列挙外は判定順 (7) の ask WF202 に落ちるが、承認単位が親ディレクトリ（アプリルート）だと、承認した瞬間にアプリルート配下（deny 以外）が判定順 (6) で丸ごと通る。ファイル単位にして、リポジトリルートの `CLAUDE.md` が implementation で `ask WF202 7 CLAUDE.md` になるのと同じ形に揃えた
- **`apl/*/.gitattributes` は列挙にも protected にも足さなかった**: リポジトリルートの `.gitattributes` が `apl/` を含む全体に効くので入れ子は使わない。protected に足すと `ai-asset-implementation` が `apl/**` を deny しているため、どの種別からも書けないデッドロックになる。列挙外として `ask WF202` に落ちる形で足りる（人間が判断できる）
- **`package-lock.json` を allow に入れ confirm には入れなかった**: `npm install` が機械的に書き換える生成物で、毎回の確認は移行や依存更新のたびに止まるだけで判断の材料にならない。手で編集すべき `package.json` / `tsconfig.json` は confirm のまま
- **eval のシナリオ本文まで直した**: 0011 では「シナリオは配置と書き分けを見ていて、ルート名が変わっても問うている内容は変わらない」と判断して前提だけ直した。この判断は誤りだった。DD-E03 は「1 アセット（機能）につき」とアセットの語彙で書かれていて、アプリには「アセット」に当たる単位が無く、期待する振る舞い（置き場・ファイル名）を `apl/<アプリ名>/docs/` で判定できない。今回、判定できる具体のパスに書き直した

前のチケットの記録の訂正:

- 0012 の作業ログに「既存 250 件は無傷」と書いたが、`test_scope.sh` の既存のアサーションは 246 件で、250 は「既存 246 + 新規 20 のうち先に通った 4」の合計だった。新規は 21 件ではなく 20 件。既存が無傷だったこと自体は変わらない（今回 20c857d に戻した状態で `passed=246 failures=0`）

### 拒否・確認・迂回の記録

- なし（`allow.write` の範囲内で完結した）

### 使った AI アセットと効き目

- `.claude/hooks/lib/scope.sh`: 判定順の実装をそのまま読み込んで、直す前と後の判定（`allow - 5` → `ask WF202 7 <ファイル>`）を出せた。設定の変更が意図どおりかを推測なしに確かめられた
- `run-tests.sh --ids`: テストを移したときに ID の付け替えが漏れていないかを 1 回で確認できた

### スコープ外で見つけたこと

- `run-tests.sh --ids` が報告する `CP-T08` の重複（`test_commit.sh` と `test_push.sh`）は今回も残っている。この変更の前からあり、issue #20 の受け入れ条件に無いので直していない

### AI アセットに反映すべき内容

- テストの置き場と ID の対応（関数単体は lib のテスト、出荷される設定の中身は `test_config_integrity.sh`）が、どこにも書かれていない。今回この対応を誤って HK-T15 に載せた。フック共通仕様 §11 かテストのスキルに 1 行で書いておくと、次に許可範囲を変える人が迷わない。フィードバック計画（フェーズ 5）で拾う

### 備考

- これでフェーズ 3 の敵対的レビューの指摘 8 件すべての対応が終わった（正史 5 件は 0014、本体 6 件はこのチケット。重なりあり）
