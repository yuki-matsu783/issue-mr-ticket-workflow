---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0019"]
executor: opus
human_review: {required: false, reason: "全体計画書の方針（差分 3）"}
adversarial_review: {required: true, reason: "全体計画書の方針（差分 3: フェーズごとに 1 回）"}
allow:
  write: [".claude/hooks/**"]
  ops: ["hook-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0020 S3 中核 b: cmdpos.sh の正規化 2 件と scope.sh の分類の穴 6 件

## 目的

フック共通仕様 §7-1 の正規化（算術展開は段を割らない / コマンド置換・プロセス置換の閉じ括弧の後ろの語を実行体にしない）と §8 の「サブコマンド + オプション」の限定適用 6 件を実装し、cd は分類に足さないことを負のコントロールで固定する。全フックが読む共通ライブラリなので、フック本体より先に固める。

## DoD

- [ ] cmdpos.sh が仕様書 フック共通仕様 §7-1 のとおりになっている（$(( )) は段を割らず 1 語の _ に潰す / $( ) と <( ) は中身を実行位置として解析したうえで外側は 1 語に潰し、閉じ括弧の後ろの語を新しい段の実行体にしない）（根拠: ）
- [ ] scope.sh が仕様書 §8 の限定適用 6 件のとおりになっている（1 git worktree は list だけ read / 2 git branch は書き込みオプションで unknown / 3 git symbolic-ref は位置引数 2 つ以上で unknown / 4 git reflog は show・exists だけ read / 5 --output=<file> は write で SC_TARGETS に出力先 / 6 -c と --config-env は設定名を見ず一律 unknown）（根拠: ）
- [ ] cd が分類に足されていない（unknown → WF204 のまま）ことが負のコントロールとして固定されている（根拠: ）
- [ ] R52 の軽微 2 件が直っている（_SC_READ_ONLY_CMDS の column の重複を解消 / _SC_SHELL_KEYWORDS に全要素ループの検査を追加）（根拠: ）
- [ ] 機械テスト HK-T05・HK-T12・HK-T15 が通る（run-tests.sh --filter '*test_cmdpos*' と --filter '*test_scope*'）。HK-T15 は限定適用 6 件を閉じる側と通す側の対で踏む（根拠: ）
- [ ] 機械テスト HK-T02 が通る（run-tests.sh --filter '*config_integrity*'。classify_real が scope_classify を実際に走らせる）（根拠: ）
- [ ] 変更直後に git worktree list・git branch -a・git status --porcelain を 1 回ずつ実行し、read として通ること（通す向きの回帰）を確かめた（根拠: ）
- [ ] 実装結果レポートに本チケットの節が追記され、仕様と食い違った点は仕様を直さず「仕様からの逸脱」に記録されている（根拠: ）

## 作業内容

- cmdpos.sh が壊れると bash で始まるすべての判定が崩れるので、編集は Edit ツールで行い（Bash を介さない）、直後に bash -n .claude/hooks/lib/cmdpos.sh を回す
- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md の S3 と「ロックアウト対策」の S3 行に従う

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
