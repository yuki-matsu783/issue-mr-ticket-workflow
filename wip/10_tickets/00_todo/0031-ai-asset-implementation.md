---
type: ticket
ticket_type: ai-asset-implementation
predecessors: ["0030"]
executor: main
human_review: {required: true, reason: "基準どおり（登録は人間の操作。ロックアウトの復旧経路も人間）"}
adversarial_review: {required: true, reason: "基準どおり（中核の登録。実測の解釈が後続の書き戻しを左右する）"}
allow:
  write: [".claude/hooks/**", ".claude/settings.json"]
  ops: ["read", "remote-read", "hook-test", "build-test"]
started_at: ""
completed_at: ""
base_sha: ""
---

# 0031 段階登録 ①② の 16 行とフェーズ 4c の実測・HK-T01・全件テスト

## 目的

残る 16 行を 2 段で登録し、登録済みの本物のフックの記録でフェーズ 4c の実測を行い、HK-T01 と run-tests.sh --ids の全件を通す

## DoD

- [ ] HK-T01 の期待値として 17 行分の command 文字列の逐語一覧が .claude/hooks/tests/fixtures/settings-hooks.expected.tsv（イベント・matcher・位置・command の 4 列）にあり、引数を取る 2 行（--accumulate）と実体のディレクトリと登録先が一致しない 4 行が正しく入っている（根拠: ）
- [ ] 段階 ①（案内側 12 行: SessionStart 1 / UserPromptSubmit 1 / PreToolUse Skill 1 / PreToolUse Agent 1 / PostToolUse 4 / SubagentStart 1 / SubagentStop 2 / Stop 1）を人間が登録し、AI がコミットした。新しいセッションで軽い操作（Read → Skill 宣言 → Edit → commit.sh）を通し想定外の deny が無いことを確かめた（根拠: ）
- [ ] 段階 ②（拒否側 4 行を fail-closed ラッパー付きで追加し、⓪ の block-chmod にもラッパーを付ける）を人間が登録し、AI がコミットした。1 行ずつ足して各行の後に軽い操作を通した。HK-T09（ラッパー）が通る（根拠: ）
- [ ] T9（systemMessage が PreToolUse でユーザーに実際に表示されるか）を ① の後に実測し、結果を作業ログに書いた。外れた場合は HK-T01 のフィクスチャを 16 行に直し、§1 の書き戻しをフェーズ 6 へ送った（根拠: ）
- [ ] T2（親子の session_id）・T3（claude -p の判別と defer の実在）・T4（SubagentStart と model / agent_id）・T7（tool_response の終了コードのフィールド名）・T8（frontmatter.sh 不在時の案内側の挙動）を実測し、結果を作業ログの表に書いた（T1 は i0009-43 で公式解決済みのため含めない。T6 は 0028 で確認済み）（根拠: ）
- [ ] tool_response.status が既定で async_launched になるか・agent_type の実物・worktree で worktree 側のチケットを見るか・ホットパス 5 本と post-push-usage-report の実行時間を実測し、作業ログに書いた。実行時間から hc_lock の陳腐化 60 秒の妥当性を評価した（根拠: ）
- [ ] HK-T01（17 行のフィクスチャと settings.json の行単位の照合）が通る（根拠: ）
- [ ] run-tests.sh --ids の全件を実行し、結果（通過数・失敗した ID と理由・boundary.sh 依存で実施できない 10 件）を結果報告に記録した。全件はバックグラウンド実行でファイルに出した（根拠: ）
- [ ] 実測で判明した仕様との食い違いを作業ログ「仕様からの逸脱」に列挙し、DDR にすべきものを「AI アセットに反映すべき内容」に書いた（実装フェーズは .claude/docs/** に書けないため）（根拠: ）

## 作業内容

- 計画書 wip/20_plans/0016-ai-asset-implementation-plan.md のステップ 5 に従う
- 登録は人間の操作。AI は貼り付ける JSON と手順を提示し、登録後のコミットだけを行う
- ② でロックアウトした場合、ラッパーは環境変数を見ないのでバックアップからの復元（人間）が唯一の経路。登録前に 4 本とも単体実行と bash -n と shellcheck を通す
- 登録は対話セッションでのみ可能（settings.json は common.confirm でヘッドレスでは WF203 が deny）。T3 の実測は逆に claude -p を 1 回走らせる

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
