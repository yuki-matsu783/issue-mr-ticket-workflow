---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0013"]
executor: main
human_review: {required: true, reason: "中核（scope-limits.json）を含む"}
adversarial_review: {required: false, reason: "フェーズ 4 の敵対的レビューは 0017 の完了後にまとめて 1 回実施する"}
allow:
  write: [".claude/hooks/config/scope-limits.json", ".claude/hooks/tests/**"]
  ops: ["read", "build-test", "hook-test", "remote-read"]
started_at: "2026-09-02T11:02:05+00:00"
completed_at: ""
base_sha: "9e68c8b"
---

# 0019 実装: commands.build-test に拡張のテストコマンドを列挙する

## 目的

npm test が判定順の分類で build-test になり、実装チケットから実行できるようにする（0016 の再起票）

## DoD

- [x] scope-limits.json の commands.build-test に npm test と npm --prefix apl/vscode-ticket-board test が入り、jq で構文が通る（根拠: `jq -c '.commands' .claude/hooks/config/scope-limits.json` が `{"build-test":["npm test","npm --prefix apl/vscode-ticket-board test"]}`。`jq -e .` が成功）
- [x] test_config_integrity.sh に commands.build-test の中身を固定するアサーションがあり、変更前に落ちて変更後に通ることを確かめた（根拠: `test_config_integrity.sh:33` に `assert_eq "HK-T02" "npm --prefix apl/vscode-ticket-board test / npm test" "$(tl_jq -r '.commands["build-test"] | sort | join(" / ")' "$JSON")"` を追加。列挙前は `passed=36 failures=1`、列挙後は `passed=37 failures=0`。列挙を空にした複製で join の結果が空文字になることを確かめ、アサーションが中身を見分けることを確認した）
- [x] run-tests.sh --ids が 14 本すべて PASS する（根拠: `run-tests.sh --ids` が 14 本すべて PASS、`FAIL ID:` は空、59 テスト ID）

## 作業内容

- テストを先に書いて落としてから設定を直す

## 作業ログ

### 現在地

- 完了。`scope-limits.json` の `commands.build-test` に 2 件を列挙し、`test_config_integrity.sh` にその中身を固定するアサーションを足した

### うまくいったこと

- アサーションを先に書いて落としてから設定を直す順を守れた（36/1 → 37/0）
- 「落ちること」だけでなく「アサーションが中身を見分けること」も確かめた。列挙を空にした複製に同じ jq を当て、join の結果が空文字になることを見た。これをやらないと、常に真になるアサーションを書いても気付けない

### うまくいかなかったこと

- 最初のアサーションで期待値を `"...test\nnpm test"` と二重引用符で書き、`\n` が改行に解釈されず落ちた。実際の値と見た目が同じなのに FAIL するので原因が分かりにくかった。jq 側で `join(" / ")` して 1 行に潰す形に変え、シェルの引用符の解釈に依存しないようにした
- その途中で `paste -sd' ' - | sed 's|test npm|test / npm|'` という繋ぎ方をした。動くが、値に依存した文字列置換で脆い。`jq` の `sort | join(" / ")` に書き直した
- このチケットは 0016 の再起票。0016 は `allow.ops` に `build-test` が無く `run-tests.sh` が TR006 で止まった。frontmatter を手で直さず、0016 を取り消して計画（`wip/20_plans/0013-implementation-plan.md`）の T1 の行に「`allow.ops` は read, build-test, hook-test, remote-read」を明記してから 0019 として起票し直した

### 仕様からの逸脱

- 実行者: 全体計画のとおりメインエージェント（`10-task-ai-asset-implementation-exec` スキル本体が未整備のため、`.claude/docs/10_spec/skills/` の対応する仕様書に従って主体で実施。issue #10 の範囲）

### 判断と根拠

- **2 件を列挙した**: `npm test`（アプリルートで実行する形）と `npm --prefix apl/vscode-ticket-board test`（リポジトリルートから実行する形）。分類は前方一致なので、どちらの実行のしかたでも `build-test` になる
- **`npm run build` は列挙しなかった**: この拡張の `package.json` に `build` スクリプトは無い（`compile` と `test` のみ）。使わないコマンドを上限に足すと、実際に使えるコマンドの範囲が読みにくくなる。`compile` は `test` が内部で走らせるので単独では要らない
- **アサーションを `test_config_integrity.sh` に置いた**: 出荷される設定の中身の検査は HK-T02 の枠（0015 で `case_real_apl` を移したのと同じ理由）。`test_scope.sh` は `scope.sh` の関数単体の枠なので触っていない

### 拒否・確認・迂回の記録

- `.claude/hooks/config/scope-limits.json` は `common.confirm` に載るので書き込みのたびに確認が出る想定。迂回はしていない
- 0016 の TR006 は迂回せず、チケットを取り消して計画から直した（`20-common-step-shell-script` の「作業中チケットの frontmatter を手で書き換えない」に従った）

### 使った AI アセットと効き目

- `20-common-step-shell-script` の SKILL: TR006 の対処に「計画側に返す。frontmatter を手で書き換えない」と書いてあり、迷わず取り消し → 再起票を選べた
- `run-tests.sh --ids`: 列挙を足した後に既存の分類が狭まっていないことを 1 回で確認できた

### スコープ外で見つけたこと

- `run-tests.sh` は `.claude/hooks/**` のテストしか無い場合でも `allow.ops` に `build-test` を要求する（`hook-test` だけでは足りない）。スキルの説明は「`build-test`（`.claude/hooks/**` のテストを含むなら `hook-test` も）」と書いていて、この必須の関係は読み取れる。ただし計画を書くときに見落としやすい。フィードバック計画（フェーズ 5）で拾う

### AI アセットに反映すべき内容

- 実装計画がチケットを起こすとき、`run-tests.sh` を DoD に含むなら `allow.ops` に `build-test` が要る、という対応を計画スキル側の DoD の型に入れたい。今回はそれが無かったので 1 枚を取り消して起票し直すことになった。フィードバック計画（フェーズ 5）で拾う

### 備考

- 0016 は取り消し済み（`wip/10_tickets/` の取り消し置き場）。このチケットが実質的な T1
